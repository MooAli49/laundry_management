-- =============================================================================
-- Migration: 20261003000000_fix_order_item_type_uuid_cast.sql
-- Purpose: Fix missing (v_item->>'item_type_id')::UUID explicit cast in
--          sync_create_order_aggregate and sync_update_order_aggregate.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sync_create_order_aggregate(
    p_op_id TEXT, p_order JSONB, p_items JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $function$
DECLARE
    v_cached JSONB;
    v_order_id UUID := (p_order->>'id')::UUID;
    v_customer_id UUID := (p_order->>'customer_id')::UUID;
    v_status TEXT := p_order->>'status';
    v_order_number TEXT := p_order->>'order_number';
    v_expected_pickup_date DATE := (p_order->>'expected_pickup_date')::DATE;
    v_subtotal BIGINT := (p_order->>'subtotal')::BIGINT;
    v_total BIGINT := (p_order->>'total')::BIGINT;
    v_item JSONB;
    v_service_pricing_type TEXT;
    v_item_pricing_type TEXT;
    v_carpet JSONB;
    v_items JSONB := '[]'::JSONB;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN RETURN v_cached; END IF;
    IF v_order_id IS NULL OR v_customer_id IS NULL OR v_order_number IS NULL
       OR v_expected_pickup_date IS NULL OR v_subtotal IS NULL OR v_total IS NULL THEN
        RAISE EXCEPTION 'Order payload is missing required fields' USING ERRCODE = '23502';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = v_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', v_customer_id USING ERRCODE = '23503';
    END IF;
    IF v_status NOT IN ('processing', 'ready', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid order status: %', v_status USING ERRCODE = '23514';
    END IF;
    IF v_subtotal < 0 OR v_total < 0 THEN
        RAISE EXCEPTION 'Monetary amounts cannot be negative' USING ERRCODE = '23514';
    END IF;

    INSERT INTO orders (
        id, order_number, customer_id, customer_name_snapshot, customer_phone_snapshot,
        status, expected_pickup_date, notes, customer_pickup_requested, customer_pickup_fee,
        customer_delivery_requested, customer_delivery_fee, subtotal, discount, tax, total,
        paid_amount, completed_at, cancelled_at, cancellation_reason, server_version,
        created_at, updated_at
    ) VALUES (
        v_order_id, v_order_number, v_customer_id,
        COALESCE(p_order->>'customer_name_snapshot', ''), COALESCE(p_order->>'customer_phone_snapshot', ''),
        v_status, v_expected_pickup_date, p_order->>'notes',
        COALESCE((p_order->>'customer_pickup_requested')::BOOLEAN, false),
        COALESCE((p_order->>'customer_pickup_fee')::BIGINT, 0),
        COALESCE((p_order->>'customer_delivery_requested')::BOOLEAN, false),
        COALESCE((p_order->>'customer_delivery_fee')::BIGINT, 0), v_subtotal,
        COALESCE((p_order->>'discount')::BIGINT, 0), COALESCE((p_order->>'tax')::BIGINT, 0), v_total,
        COALESCE((p_order->>'paid_amount')::BIGINT, 0), (p_order->>'completed_at')::TIMESTAMPTZ,
        (p_order->>'cancelled_at')::TIMESTAMPTZ, p_order->>'cancellation_reason', 1,
        COALESCE((p_order->>'created_at')::TIMESTAMPTZ, now()),
        COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
    );

    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::JSONB)) LOOP
        v_item_pricing_type := v_item->>'pricing_type';
        SELECT pricing_type INTO v_service_pricing_type FROM service_item_types
        WHERE service_id = (v_item->>'service_id')::UUID AND item_type_id = (v_item->>'item_type_id')::UUID;
        IF NOT FOUND OR v_service_pricing_type <> v_item_pricing_type THEN
            RAISE EXCEPTION 'Invalid service/item type pricing configuration' USING ERRCODE = '23514';
        END IF;
        INSERT INTO order_items (
            id, order_id, item_type_id, item_definition_id, service_id,
            item_type_name_snapshot, item_definition_name_snapshot, service_name_snapshot,
            pricing_type, quantity, unit_price, calculated_total, notes, created_at, updated_at
        ) VALUES (
            (v_item->>'id')::UUID, v_order_id, (v_item->>'item_type_id')::UUID,
            NULLIF(v_item->>'item_definition_id', '')::UUID, (v_item->>'service_id')::UUID,
            COALESCE(v_item->>'item_type_name_snapshot', ''), v_item->>'item_definition_name_snapshot',
            COALESCE(v_item->>'service_name_snapshot', ''), v_item_pricing_type,
            (v_item->>'quantity')::DOUBLE PRECISION, (v_item->>'unit_price')::BIGINT,
            (v_item->>'calculated_total')::BIGINT, v_item->>'notes',
            COALESCE((v_item->>'created_at')::TIMESTAMPTZ, now()),
            COALESCE((v_item->>'updated_at')::TIMESTAMPTZ, now())
        );
        v_carpet := v_item->'carpet_data';
        IF v_carpet IS NOT NULL AND v_carpet <> 'null'::JSONB THEN
            INSERT INTO order_item_carpets (
                id, order_item_id, carpet_size_id, length, width, area, created_at, updated_at
            ) VALUES (
                (v_carpet->>'id')::UUID, (v_item->>'id')::UUID,
                NULLIF(v_carpet->>'carpet_size_id', '')::UUID,
                (v_carpet->>'length')::DOUBLE PRECISION, (v_carpet->>'width')::DOUBLE PRECISION,
                (v_carpet->>'area')::DOUBLE PRECISION,
                COALESCE((v_carpet->>'created_at')::TIMESTAMPTZ, now()),
                COALESCE((v_carpet->>'updated_at')::TIMESTAMPTZ, now())
            );
        END IF;
        v_items := v_items || jsonb_build_array(v_item);
    END LOOP;

    v_result := jsonb_build_object('id', v_order_id, 'order_number', v_order_number,
        'status', v_status, 'subtotal', v_subtotal, 'total', v_total,
        'server_version', 1, 'item_count', jsonb_array_length(v_items));
    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create',
        p_order || jsonb_build_object('server_version', 1, 'items', v_items), 1, now());
    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', now(), v_result);
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.sync_update_order_aggregate(
    p_op_id TEXT, p_order_id UUID, p_order JSONB, p_items JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $function$
DECLARE
    v_cached JSONB;
    v_existing orders%ROWTYPE;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_item JSONB;
    v_item_id UUID;
    v_service_pricing_type TEXT;
    v_carpet JSONB;
    v_removed UUID[];
    v_items JSONB;
    v_status TEXT;
    v_updated_at TIMESTAMPTZ;
    v_subtotal BIGINT := (p_order->>'subtotal')::BIGINT;
    v_discount BIGINT := COALESCE((p_order->>'discount')::BIGINT, 0);
    v_tax BIGINT := COALESCE((p_order->>'tax')::BIGINT, 0);
    v_total BIGINT := (p_order->>'total')::BIGINT;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN RETURN v_cached; END IF;
    SELECT * INTO v_existing FROM orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Order % not found', p_order_id USING ERRCODE = 'P0002'; END IF;
    IF v_existing.status IN ('completed', 'cancelled') THEN
        RAISE EXCEPTION 'INVALID_LIFECYCLE_TRANSITION: Cannot update order in status %', v_existing.status USING ERRCODE = '23514';
    END IF;
    IF p_order ? 'base_version' AND (p_order->>'base_version') IS NOT NULL THEN
        v_base_version := (p_order->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version %', v_base_version, v_existing.server_version USING ERRCODE = 'P0004';
        END IF;
    END IF;
    IF p_order ? 'order_number' AND p_order->>'order_number' <> v_existing.order_number THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: order_number is immutable' USING ERRCODE = '23514';
    END IF;
    IF v_subtotal IS NULL OR v_total IS NULL OR v_subtotal < 0 OR v_discount < 0 OR v_tax < 0 OR v_total < 0 THEN
        RAISE EXCEPTION 'Monetary amounts are invalid' USING ERRCODE = '23514';
    END IF;
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order must contain at least one item' USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(array_agg(id), ARRAY[]::UUID[]) INTO v_removed FROM order_items
    WHERE order_id = p_order_id AND id NOT IN (
        SELECT (i->>'id')::UUID FROM jsonb_array_elements(p_items) i
    );
    IF array_length(v_removed, 1) > 0 THEN
        DELETE FROM order_item_carpets WHERE order_item_id = ANY(v_removed);
        DELETE FROM order_items WHERE id = ANY(v_removed);
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        SELECT pricing_type INTO v_service_pricing_type FROM service_item_types
        WHERE service_id = (v_item->>'service_id')::UUID AND item_type_id = (v_item->>'item_type_id')::UUID;
        IF NOT FOUND OR v_service_pricing_type <> v_item->>'pricing_type' THEN
            RAISE EXCEPTION 'Invalid service/item type pricing configuration' USING ERRCODE = '23514';
        END IF;
        INSERT INTO order_items (
            id, order_id, item_type_id, item_definition_id, service_id,
            item_type_name_snapshot, item_definition_name_snapshot, service_name_snapshot,
            pricing_type, quantity, unit_price, calculated_total, notes, created_at, updated_at
        ) VALUES (
            v_item_id, p_order_id, (v_item->>'item_type_id')::UUID, NULLIF(v_item->>'item_definition_id', '')::UUID,
            (v_item->>'service_id')::UUID, COALESCE(v_item->>'item_type_name_snapshot', ''),
            v_item->>'item_definition_name_snapshot', COALESCE(v_item->>'service_name_snapshot', ''),
            v_item->>'pricing_type', (v_item->>'quantity')::DOUBLE PRECISION,
            (v_item->>'unit_price')::BIGINT, (v_item->>'calculated_total')::BIGINT, v_item->>'notes',
            COALESCE((v_item->>'created_at')::TIMESTAMPTZ, now()), now()
        ) ON CONFLICT (id) DO UPDATE SET
            item_definition_id = EXCLUDED.item_definition_id, service_id = EXCLUDED.service_id,
            item_definition_name_snapshot = EXCLUDED.item_definition_name_snapshot,
            service_name_snapshot = EXCLUDED.service_name_snapshot, pricing_type = EXCLUDED.pricing_type,
            quantity = EXCLUDED.quantity, unit_price = EXCLUDED.unit_price,
            calculated_total = EXCLUDED.calculated_total, notes = EXCLUDED.notes, updated_at = EXCLUDED.updated_at;
        v_carpet := v_item->'carpet_data';
        IF v_carpet IS NOT NULL AND v_carpet <> 'null'::JSONB THEN
            INSERT INTO order_item_carpets (id, order_item_id, carpet_size_id, length, width, area, created_at, updated_at)
            VALUES ((v_carpet->>'id')::UUID, v_item_id, NULLIF(v_carpet->>'carpet_size_id', '')::UUID,
                (v_carpet->>'length')::DOUBLE PRECISION, (v_carpet->>'width')::DOUBLE PRECISION,
                (v_carpet->>'area')::DOUBLE PRECISION, COALESCE((v_carpet->>'created_at')::TIMESTAMPTZ, now()), now())
            ON CONFLICT (id) DO UPDATE SET carpet_size_id = EXCLUDED.carpet_size_id,
                length = EXCLUDED.length, width = EXCLUDED.width, area = EXCLUDED.area, updated_at = EXCLUDED.updated_at;
            DELETE FROM order_item_carpets WHERE order_item_id = v_item_id AND id <> (v_carpet->>'id')::UUID;
        ELSE
            DELETE FROM order_item_carpets WHERE order_item_id = v_item_id;
        END IF;
    END LOOP;

    SELECT CASE WHEN COUNT(*) > 0 AND COUNT(*) = COUNT(sr.id) THEN 'ready' ELSE 'processing' END
    INTO v_status FROM order_items oi LEFT JOIN storage_records sr ON sr.order_item_id = oi.id AND sr.is_active
    WHERE oi.order_id = p_order_id;
    v_new_version := v_existing.server_version + 1;
    v_updated_at := COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now());
    UPDATE orders SET status = v_status, expected_pickup_date = (p_order->>'expected_pickup_date')::DATE,
        notes = p_order->>'notes', customer_pickup_requested = COALESCE((p_order->>'customer_pickup_requested')::BOOLEAN, false),
        customer_pickup_fee = COALESCE((p_order->>'customer_pickup_fee')::BIGINT, 0),
        customer_delivery_requested = COALESCE((p_order->>'customer_delivery_requested')::BOOLEAN, false),
        customer_delivery_fee = COALESCE((p_order->>'customer_delivery_fee')::BIGINT, 0), subtotal = v_subtotal,
        discount = v_discount, tax = v_tax, total = v_total, server_version = v_new_version, updated_at = v_updated_at
    WHERE id = p_order_id;

    SELECT jsonb_agg(jsonb_build_object('id', oi.id, 'order_id', oi.order_id, 'item_type_id', oi.item_type_id,
        'item_definition_id', oi.item_definition_id, 'service_id', oi.service_id,
        'item_type_name_snapshot', oi.item_type_name_snapshot, 'item_definition_name_snapshot', oi.item_definition_name_snapshot,
        'service_name_snapshot', oi.service_name_snapshot, 'pricing_type', oi.pricing_type, 'quantity', oi.quantity,
        'unit_price', oi.unit_price, 'calculated_total', oi.calculated_total, 'notes', oi.notes,
        'created_at', oi.created_at, 'updated_at', oi.updated_at, 'carpet_data',
        (SELECT jsonb_build_object('id', c.id, 'order_item_id', c.order_item_id, 'carpet_size_id', c.carpet_size_id,
            'length', c.length, 'width', c.width, 'area', c.area, 'created_at', c.created_at, 'updated_at', c.updated_at)
         FROM order_item_carpets c WHERE c.order_item_id = oi.id)))
    INTO v_items FROM order_items oi WHERE oi.order_id = p_order_id;
    v_result := jsonb_build_object('id', p_order_id, 'status', v_status, 'subtotal', v_subtotal,
        'total', v_total, 'server_version', v_new_version, 'item_count', jsonb_array_length(COALESCE(v_items, '[]'::JSONB)));
    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'edit',
        p_order || jsonb_build_object('id', p_order_id, 'customer_id', v_existing.customer_id,
            'customer_name_snapshot', v_existing.customer_name_snapshot,
            'customer_phone_snapshot', v_existing.customer_phone_snapshot, 'status', v_status,
            'expected_pickup_date', (p_order->>'expected_pickup_date')::DATE, 'subtotal', v_subtotal,
            'discount', v_discount, 'tax', v_tax, 'total', v_total, 'paid_amount', v_existing.paid_amount,
            'server_version', v_new_version, 'created_at', v_existing.created_at, 'updated_at', v_updated_at,
            'items', COALESCE(v_items, '[]'::JSONB)), v_new_version, now());
    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'edit', now(), v_result);
    RETURN v_result;
END;
$function$;
