-- =============================================================================
-- Migration: 20260923000000_sync_update_order_aggregate.sql
-- Description: Edit Processing Order V1 — Phase 2: PostgreSQL RPC
--              sync_update_order_aggregate(p_op_id, p_order_id, p_order, p_items)
--              Atomic aggregate edit with server-side validations, safe deletion guard (P0006),
--              readiness recalculation, and single sync_changes full-aggregate append.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sync_update_order_aggregate(
    p_op_id TEXT,
    p_order_id UUID,
    p_order JSONB,
    p_items JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_cached JSONB;
    v_existing orders%ROWTYPE;
    v_base_version INTEGER;
    v_new_customer_id UUID;
    v_customer_id UUID;
    v_customer_name TEXT;
    v_customer_phone TEXT;
    v_subtotal BIGINT;
    v_discount BIGINT;
    v_tax BIGINT;
    v_total BIGINT;
    v_expected_total BIGINT;
    v_pickup_requested BOOLEAN;
    v_pickup_fee BIGINT;
    v_delivery_requested BOOLEAN;
    v_delivery_fee BIGINT;
    v_item JSONB;
    v_item_id UUID;
    v_item_type_id UUID;
    v_item_type_name TEXT;
    v_item_def_id UUID;
    v_def_name TEXT;
    v_def_item_type_id UUID;
    v_def_snapshot TEXT;
    v_service_id UUID;
    v_service_name TEXT;
    v_service_pricing_type TEXT;
    v_item_pricing_type TEXT;
    v_quantity DOUBLE PRECISION;
    v_unit_price BIGINT;
    v_calc_total BIGINT;
    v_notes TEXT;
    v_existing_item order_items%ROWTYPE;
    v_carpet JSONB;
    v_carpet_id UUID;
    v_carpet_size_id UUID;
    v_carpet_length DOUBLE PRECISION;
    v_carpet_width DOUBLE PRECISION;
    v_carpet_area DOUBLE PRECISION;
    v_removed_ids UUID[];
    v_del_id UUID;
    v_active_stored_count INTEGER;
    v_status TEXT;
    v_new_server_version INTEGER;
    v_updated_at TIMESTAMPTZ;
    v_full_items JSONB;
    v_aggregate_payload JSONB;
    v_result JSONB;
BEGIN
    -- 1. Idempotency Check
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Order Existence & Lock
    SELECT * INTO v_existing FROM orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id USING ERRCODE = 'P0002';
    END IF;

    -- 3. Terminal State Protection
    IF v_existing.status IN ('completed', 'cancelled') THEN
        RAISE EXCEPTION 'INVALID_LIFECYCLE_TRANSITION: Cannot update order in status %: order is in terminal state',
            v_existing.status USING ERRCODE = '23514';
    END IF;

    -- Optional base_version check (omitted in V1 client payload, but honored if supplied)
    IF p_order ? 'base_version' AND (p_order->>'base_version') IS NOT NULL THEN
        v_base_version := (p_order->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for order %',
                v_base_version, v_existing.server_version, p_order_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    -- 4. Order Number Immutability
    IF p_order ? 'order_number' AND p_order->>'order_number' IS NOT NULL AND p_order->>'order_number' <> v_existing.order_number THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: order_number is immutable' USING ERRCODE = '23514';
    END IF;

    -- 5. Customer Change Rules
    v_new_customer_id := COALESCE((p_order->>'customer_id')::UUID, v_existing.customer_id);
    IF v_new_customer_id <> v_existing.customer_id THEN
        IF v_existing.paid_amount > 0 THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Cannot change customer on an order with recorded payments' USING ERRCODE = '23514';
        END IF;
        SELECT name, phone INTO v_customer_name, v_customer_phone
        FROM customers WHERE id = v_new_customer_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Customer % does not exist', v_new_customer_id USING ERRCODE = '23503';
        END IF;
        v_customer_id := v_new_customer_id;
    ELSE
        v_customer_id := v_existing.customer_id;
        v_customer_name := v_existing.customer_name_snapshot;
        v_customer_phone := v_existing.customer_phone_snapshot;
    END IF;

    -- 6. Financial Integrity
    v_subtotal := (p_order->>'subtotal')::BIGINT;
    v_discount := COALESCE((p_order->>'discount')::BIGINT, 0);
    v_tax := COALESCE((p_order->>'tax')::BIGINT, 0);
    v_total := (p_order->>'total')::BIGINT;
    v_pickup_requested := COALESCE((p_order->>'customer_pickup_requested')::BOOLEAN, false);
    v_pickup_fee := CASE WHEN v_pickup_requested THEN COALESCE((p_order->>'customer_pickup_fee')::BIGINT, 0) ELSE 0 END;
    v_delivery_requested := COALESCE((p_order->>'customer_delivery_requested')::BOOLEAN, false);
    v_delivery_fee := CASE WHEN v_delivery_requested THEN COALESCE((p_order->>'customer_delivery_fee')::BIGINT, 0) ELSE 0 END;

    IF v_subtotal < 0 OR v_discount < 0 OR v_tax < 0 OR v_total < 0 OR v_pickup_fee < 0 OR v_delivery_fee < 0 THEN
        RAISE EXCEPTION 'Monetary amounts cannot be negative' USING ERRCODE = '23514';
    END IF;

    IF v_discount > v_subtotal THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Discount cannot exceed subtotal' USING ERRCODE = '23514';
    END IF;

    v_expected_total := v_subtotal - v_discount + v_pickup_fee + v_delivery_fee + v_tax;
    IF v_total <> v_expected_total THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Total % does not match expected calculated total %', v_total, v_expected_total USING ERRCODE = '23514';
    END IF;

    IF v_total < v_existing.paid_amount THEN
        RAISE EXCEPTION 'INSUFFICIENT_ORDER_TOTAL: total % cannot be less than paid_amount %', v_total, v_existing.paid_amount USING ERRCODE = '23514';
    END IF;

    -- 7. Items Array Validation
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order must contain at least one item' USING ERRCODE = '23514';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        v_item_type_id := (v_item->>'item_type_id')::UUID;
        v_service_id := (v_item->>'service_id')::UUID;
        v_item_pricing_type := v_item->>'pricing_type';
        v_quantity := (v_item->>'quantity')::DOUBLE PRECISION;
        v_unit_price := (v_item->>'unit_price')::BIGINT;
        v_calc_total := (v_item->>'calculated_total')::BIGINT;

        -- Order ID ownership check if provided
        IF v_item ? 'order_id' AND (v_item->>'order_id') IS NOT NULL AND (v_item->>'order_id') <> '' THEN
            IF (v_item->>'order_id')::UUID <> p_order_id THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: order item % does not belong to order %', v_item_id, p_order_id USING ERRCODE = '23514';
            END IF;
        END IF;

        -- Strict positive price check (Rule A)
        IF v_unit_price <= 0 THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: unit_price must be greater than zero' USING ERRCODE = '23514';
        END IF;

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: quantity must be greater than zero' USING ERRCODE = '23514';
        END IF;

        IF v_item_pricing_type NOT IN ('per_piece', 'per_square_meter', 'fixed_price') THEN
            RAISE EXCEPTION 'Invalid order item pricing type: %', v_item_pricing_type USING ERRCODE = '23514';
        END IF;

        -- Item Type existence (Rule B)
        SELECT name INTO v_item_type_name FROM item_types WHERE id = v_item_type_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Invalid item_type_id %', v_item_type_id USING ERRCODE = '23514';
        END IF;

        -- Service existence & pricing_type compatibility (Rule D & E)
        SELECT name, pricing_type INTO v_service_name, v_service_pricing_type FROM services WHERE id = v_service_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Service % does not exist', v_service_id USING ERRCODE = '23503';
        END IF;

        IF v_item_pricing_type <> v_service_pricing_type THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: item pricing_type % does not match service pricing_type %', v_item_pricing_type, v_service_pricing_type USING ERRCODE = '23514';
        END IF;

        -- Service / ItemType compatibility (Rule D)
        IF NOT EXISTS (SELECT 1 FROM service_item_types WHERE service_id = v_service_id AND item_type_id = v_item_type_id) THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: service % is not compatible with item_type %', v_service_id, v_item_type_id USING ERRCODE = '23514';
        END IF;

        -- Item Definition compatibility (Rule C)
        IF v_item ? 'item_definition_id' AND v_item->>'item_definition_id' IS NOT NULL AND v_item->>'item_definition_id' <> '' THEN
            v_item_def_id := (v_item->>'item_definition_id')::UUID;
            SELECT name, item_type_id INTO v_def_name, v_def_item_type_id FROM item_definitions WHERE id = v_item_def_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: item_definition % does not exist', v_item_def_id USING ERRCODE = '23514';
            END IF;
            IF v_def_item_type_id <> v_item_type_id THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: item_definition % does not match item_type %', v_item_def_id, v_item_type_id USING ERRCODE = '23514';
            END IF;
        END IF;

        -- Existing item immutability check (Rule F)
        SELECT * INTO v_existing_item FROM order_items WHERE id = v_item_id;
        IF FOUND THEN
            IF v_existing_item.order_id <> p_order_id THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: order item % belongs to another order', v_item_id USING ERRCODE = '23514';
            END IF;
            IF v_existing_item.item_type_id <> v_item_type_id THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Changing item_type on an existing item % is forbidden', v_item_id USING ERRCODE = '23514';
            END IF;
        END IF;

        -- Carpet validation (Rule G)
        IF v_item ? 'carpet_data' AND v_item->'carpet_data' IS NOT NULL AND v_item->'carpet_data' <> 'null'::jsonb THEN
            IF v_item_pricing_type <> 'per_square_meter' THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Carpet data is not allowed for non-carpet pricing types' USING ERRCODE = '23514';
            END IF;
            v_carpet := v_item->'carpet_data';
            v_carpet_length := (v_carpet->>'length')::DOUBLE PRECISION;
            v_carpet_width := (v_carpet->>'width')::DOUBLE PRECISION;
            v_carpet_area := (v_carpet->>'area')::DOUBLE PRECISION;

            IF v_carpet_length IS NULL OR v_carpet_width IS NULL OR v_carpet_area IS NULL
               OR v_carpet_length <= 0 OR v_carpet_width <= 0 OR v_carpet_area <= 0 THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Carpet dimensions and area must be greater than zero' USING ERRCODE = '23514';
            END IF;

            IF abs(v_carpet_area - (v_carpet_length * v_carpet_width)) > 0.01 THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Carpet area does not match length * width' USING ERRCODE = '23514';
            END IF;

            IF v_carpet ? 'carpet_size_id' AND v_carpet->>'carpet_size_id' IS NOT NULL AND v_carpet->>'carpet_size_id' <> '' THEN
                v_carpet_size_id := (v_carpet->>'carpet_size_id')::UUID;
                IF NOT EXISTS (SELECT 1 FROM carpet_sizes WHERE id = v_carpet_size_id) THEN
                    RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Carpet size % does not exist', v_carpet_size_id USING ERRCODE = '23503';
                END IF;
            END IF;
        ELSE
            IF v_item_pricing_type = 'per_square_meter' THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Carpet items must include carpet metadata' USING ERRCODE = '23514';
            END IF;
        END IF;
    END LOOP;

    -- 8. Safe Deletion Guard (Error Code P0006 / Rule H)
    SELECT COALESCE(array_agg(id), ARRAY[]::UUID[]) INTO v_removed_ids
    FROM order_items
    WHERE order_id = p_order_id
      AND id NOT IN (
          SELECT (i->>'id')::UUID
          FROM jsonb_array_elements(p_items) i
          WHERE (i->>'id') IS NOT NULL
      );

    FOREACH v_del_id IN ARRAY v_removed_ids LOOP
        IF EXISTS (SELECT 1 FROM storage_records WHERE order_item_id = v_del_id) THEN
            RAISE EXCEPTION 'EDIT_BLOCKED_ITEM_HAS_STORAGE_RECORDS: item % has storage records', v_del_id USING ERRCODE = 'P0006';
        END IF;
    END LOOP;

    -- Delete removed items and associated carpets
    IF array_length(v_removed_ids, 1) > 0 THEN
        DELETE FROM order_item_carpets WHERE order_item_id = ANY(v_removed_ids);
        DELETE FROM order_items WHERE id = ANY(v_removed_ids);
    END IF;

    -- 9. Upsert Items & Carpets
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        v_item_type_id := (v_item->>'item_type_id')::UUID;
        v_service_id := (v_item->>'service_id')::UUID;
        v_item_pricing_type := v_item->>'pricing_type';
        v_quantity := (v_item->>'quantity')::DOUBLE PRECISION;
        v_unit_price := (v_item->>'unit_price')::BIGINT;
        v_calc_total := (v_item->>'calculated_total')::BIGINT;
        v_notes := v_item->>'notes';

        SELECT name INTO v_item_type_name FROM item_types WHERE id = v_item_type_id;
        SELECT name INTO v_service_name FROM services WHERE id = v_service_id;

        v_item_def_id := NULL;
        v_def_name := NULL;
        IF v_item ? 'item_definition_id' AND v_item->>'item_definition_id' IS NOT NULL AND v_item->>'item_definition_id' <> '' THEN
            v_item_def_id := (v_item->>'item_definition_id')::UUID;
            SELECT name INTO v_def_name FROM item_definitions WHERE id = v_item_def_id;
        END IF;

        v_def_snapshot := CASE
            WHEN v_item_def_id IS NOT NULL THEN COALESCE(v_item->>'item_definition_name_snapshot', v_def_name)
            ELSE NULL
        END;

        IF EXISTS (SELECT 1 FROM order_items WHERE id = v_item_id) THEN
            UPDATE order_items
            SET service_id = v_service_id,
                item_definition_id = v_item_def_id,
                service_name_snapshot = COALESCE(v_item->>'service_name_snapshot', v_service_name),
                item_definition_name_snapshot = v_def_snapshot,
                pricing_type = v_item_pricing_type,
                quantity = v_quantity,
                unit_price = v_unit_price,
                calculated_total = v_calc_total,
                notes = v_notes,
                updated_at = now()
            WHERE id = v_item_id;
        ELSE
            INSERT INTO order_items (
                id, order_id, item_type_id, item_definition_id, service_id,
                item_type_name_snapshot, item_definition_name_snapshot, service_name_snapshot,
                pricing_type, quantity, unit_price, calculated_total, notes,
                created_at, updated_at
            ) VALUES (
                v_item_id, p_order_id, v_item_type_id, v_item_def_id, v_service_id,
                COALESCE(v_item->>'item_type_name_snapshot', v_item_type_name),
                v_def_snapshot,
                COALESCE(v_item->>'service_name_snapshot', v_service_name),
                v_item_pricing_type, v_quantity, v_unit_price, v_calc_total, v_notes,
                COALESCE((v_item->>'created_at')::TIMESTAMPTZ, now()),
                now()
            );
        END IF;

        IF v_item ? 'carpet_data' AND v_item->'carpet_data' IS NOT NULL AND v_item->'carpet_data' <> 'null'::jsonb THEN
            v_carpet := v_item->'carpet_data';
            v_carpet_id := (v_carpet->>'id')::UUID;
            v_carpet_size_id := NULL;
            IF v_carpet ? 'carpet_size_id' AND v_carpet->>'carpet_size_id' IS NOT NULL AND v_carpet->>'carpet_size_id' <> '' THEN
                v_carpet_size_id := (v_carpet->>'carpet_size_id')::UUID;
            END IF;

            INSERT INTO order_item_carpets (
                id, order_item_id, carpet_size_id, length, width, area, created_at, updated_at
            ) VALUES (
                v_carpet_id, v_item_id, v_carpet_size_id,
                (v_carpet->>'length')::DOUBLE PRECISION,
                (v_carpet->>'width')::DOUBLE PRECISION,
                (v_carpet->>'area')::DOUBLE PRECISION,
                COALESCE((v_carpet->>'created_at')::TIMESTAMPTZ, now()),
                now()
            )
            ON CONFLICT (id) DO UPDATE SET
                carpet_size_id = EXCLUDED.carpet_size_id,
                length = EXCLUDED.length,
                width = EXCLUDED.width,
                area = EXCLUDED.area,
                updated_at = now();

            -- Clean up any obsolete carpet records for this item with different id
            DELETE FROM order_item_carpets WHERE order_item_id = v_item_id AND id <> v_carpet_id;
        ELSE
            DELETE FROM order_item_carpets WHERE order_item_id = v_item_id;
        END IF;
    END LOOP;

    -- 10. Status & Order Header Update
    -- Re-evaluate readiness invariant (BR-024, BR-025, BR-087)
    SELECT COUNT(*) INTO v_active_stored_count
    FROM storage_records sr
    JOIN order_items oi ON sr.order_item_id = oi.id
    WHERE oi.order_id = p_order_id AND sr.is_active = true;

    IF jsonb_array_length(p_items) > 0 AND v_active_stored_count = jsonb_array_length(p_items) THEN
        v_status := 'ready';
    ELSE
        v_status := 'processing';
    END IF;

    v_new_server_version := v_existing.server_version + 1;
    v_updated_at := COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now());

    UPDATE orders
    SET customer_id = v_customer_id,
        customer_name_snapshot = v_customer_name,
        customer_phone_snapshot = v_customer_phone,
        status = v_status,
        expected_pickup_date = (p_order->>'expected_pickup_date')::DATE,
        notes = p_order->>'notes',
        customer_pickup_requested = v_pickup_requested,
        customer_pickup_fee = v_pickup_fee,
        customer_delivery_requested = v_delivery_requested,
        customer_delivery_fee = v_delivery_fee,
        subtotal = v_subtotal,
        discount = v_discount,
        tax = v_tax,
        total = v_total,
        server_version = v_new_server_version,
        updated_at = v_updated_at
    WHERE id = p_order_id;

    -- 11. Build Full Authoritative Aggregate for sync_changes
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', oi.id,
            'order_id', oi.order_id,
            'item_type_id', oi.item_type_id,
            'item_definition_id', oi.item_definition_id,
            'service_id', oi.service_id,
            'item_type_name_snapshot', oi.item_type_name_snapshot,
            'item_definition_name_snapshot', oi.item_definition_name_snapshot,
            'service_name_snapshot', oi.service_name_snapshot,
            'pricing_type', oi.pricing_type,
            'quantity', oi.quantity,
            'unit_price', oi.unit_price,
            'calculated_total', oi.calculated_total,
            'notes', oi.notes,
            'created_at', oi.created_at,
            'updated_at', oi.updated_at,
            'carpet_data', (
                SELECT jsonb_build_object(
                    'id', oic.id,
                    'order_item_id', oic.order_item_id,
                    'carpet_size_id', oic.carpet_size_id,
                    'length', oic.length,
                    'width', oic.width,
                    'area', oic.area,
                    'created_at', oic.created_at,
                    'updated_at', oic.updated_at
                )
                FROM order_item_carpets oic
                WHERE oic.order_item_id = oi.id
            )
        ) ORDER BY oi.created_at, oi.id
    ) INTO v_full_items
    FROM order_items oi
    WHERE oi.order_id = p_order_id;

    v_aggregate_payload := jsonb_build_object(
        'id', p_order_id,
        'order_number', v_existing.order_number,
        'customer_id', v_customer_id,
        'customer_name_snapshot', v_customer_name,
        'customer_phone_snapshot', v_customer_phone,
        'status', v_status,
        'expected_pickup_date', (p_order->>'expected_pickup_date')::DATE,
        'notes', p_order->>'notes',
        'customer_pickup_requested', v_pickup_requested,
        'customer_pickup_fee', v_pickup_fee,
        'customer_delivery_requested', v_delivery_requested,
        'customer_delivery_fee', v_delivery_fee,
        'subtotal', v_subtotal,
        'discount', v_discount,
        'tax', v_tax,
        'total', v_total,
        'paid_amount', v_existing.paid_amount,
        'server_version', v_new_server_version,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at,
        'items', COALESCE(v_full_items, '[]'::jsonb)
    );

    v_result := jsonb_build_object(
        'id', p_order_id,
        'order_number', v_existing.order_number,
        'status', v_status,
        'subtotal', v_subtotal,
        'total', v_total,
        'server_version', v_new_server_version,
        'item_count', jsonb_array_length(p_items)
    );

    -- Exactly one sync_changes append-only event
    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'edit', v_aggregate_payload, v_new_server_version, now());

    -- Idempotency logging
    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'edit', now(), v_result);

    RETURN v_result;
END;
$function$;
