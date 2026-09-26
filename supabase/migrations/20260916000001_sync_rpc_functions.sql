-- =============================================================================
-- Step 9 — Supabase PostgreSQL RPC Functions for Atomic Mutations & Idempotency
-- =============================================================================

-- Helper to check and return idempotent response
CREATE OR REPLACE FUNCTION check_idempotency(p_op_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_response JSONB;
BEGIN
    SELECT response_payload INTO v_response
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;
    RETURN v_response;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 1. Sync Create Customer
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_customer(
    p_op_id UUID,
    p_customer JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_phone TEXT;
    v_notes TEXT;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    -- Idempotency check
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_customer->>'id')::UUID;
    v_name := p_customer->>'name';
    v_phone := p_customer->>'phone';
    v_notes := p_customer->>'notes';
    v_created_at := COALESCE((p_customer->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_customer->>'updated_at')::TIMESTAMPTZ, now());

    IF v_name IS NULL OR trim(v_name) = '' THEN
        RAISE EXCEPTION 'Customer name is required' USING ERRCODE = '23502';
    END IF;
    IF v_phone IS NULL OR trim(v_phone) = '' THEN
        RAISE EXCEPTION 'Customer phone is required' USING ERRCODE = '23502';
    END IF;

    -- Check phone uniqueness
    IF EXISTS (SELECT 1 FROM customers WHERE phone = v_phone AND id <> v_id) THEN
        RAISE EXCEPTION 'Customer with phone % already exists', v_phone USING ERRCODE = '23505';
    END IF;

    INSERT INTO customers (id, name, phone, notes, created_at, updated_at)
    VALUES (v_id, v_name, v_phone, v_notes, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        phone = EXCLUDED.phone,
        notes = EXCLUDED.notes,
        updated_at = EXCLUDED.updated_at;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'phone', v_phone,
        'notes', v_notes,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'customer', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 2. Sync Update Customer
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_customer(
    p_op_id UUID,
    p_customer_id UUID,
    p_customer JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_existing customers%ROWTYPE;
    v_name TEXT;
    v_phone TEXT;
    v_notes TEXT;
    v_updated_at TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM customers WHERE id = p_customer_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id USING ERRCODE = 'P0002';
    END IF;

    v_name := COALESCE(p_customer->>'name', v_existing.name);
    v_phone := COALESCE(p_customer->>'phone', v_existing.phone);
    IF p_customer ? 'notes' THEN
        v_notes := p_customer->>'notes';
    ELSE
        v_notes := v_existing.notes;
    END IF;
    v_updated_at := COALESCE((p_customer->>'updated_at')::TIMESTAMPTZ, now());

    IF EXISTS (SELECT 1 FROM customers WHERE phone = v_phone AND id <> p_customer_id) THEN
        RAISE EXCEPTION 'Customer with phone % already exists', v_phone USING ERRCODE = '23505';
    END IF;

    UPDATE customers
    SET name = v_name,
        phone = v_phone,
        notes = v_notes,
        updated_at = v_updated_at
    WHERE id = p_customer_id;

    v_result := jsonb_build_object(
        'id', p_customer_id,
        'name', v_name,
        'phone', v_phone,
        'notes', v_notes,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'customer', p_customer_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 3. Sync Create Service
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_service(
    p_op_id UUID,
    p_service JSONB,
    p_item_type_ids TEXT[] DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_description TEXT;
    v_pricing_type TEXT;
    v_price BIGINT;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_item_type_id TEXT;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_service->>'id')::UUID;
    v_name := p_service->>'name';
    v_description := p_service->>'description';
    v_pricing_type := p_service->>'pricing_type';
    v_price := (p_service->>'price')::BIGINT;
    v_is_active := COALESCE((p_service->>'is_active')::BOOLEAN, (p_service->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_service->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_service->>'updated_at')::TIMESTAMPTZ, now());

    IF v_pricing_type NOT IN ('per_piece', 'per_square_meter', 'fixed_price') THEN
        RAISE EXCEPTION 'Invalid pricing type: %. Must be per_piece, per_square_meter, or fixed_price', v_pricing_type USING ERRCODE = '23514';
    END IF;

    IF v_price < 0 THEN
        RAISE EXCEPTION 'Price must be non-negative' USING ERRCODE = '23514';
    END IF;

    INSERT INTO services (id, name, description, pricing_type, price, is_active, created_at, updated_at)
    VALUES (v_id, v_name, v_description, v_pricing_type, v_price, v_is_active, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        pricing_type = EXCLUDED.pricing_type,
        price = EXCLUDED.price,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    IF p_item_type_ids IS NOT NULL THEN
        DELETE FROM service_item_types WHERE service_id = v_id;
        FOREACH v_item_type_id IN ARRAY p_item_type_ids LOOP
            INSERT INTO service_item_types (service_id, item_type_id, created_at)
            VALUES (v_id, v_item_type_id, now())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'pricing_type', v_pricing_type,
        'price', v_price,
        'is_active', v_is_active,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'service', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 4. Sync Update Service
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_service(
    p_op_id UUID,
    p_service_id UUID,
    p_service JSONB,
    p_item_type_ids TEXT[] DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_existing services%ROWTYPE;
    v_name TEXT;
    v_description TEXT;
    v_pricing_type TEXT;
    v_price BIGINT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_item_type_id TEXT;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM services WHERE id = p_service_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service % not found', p_service_id USING ERRCODE = 'P0002';
    END IF;

    v_name := COALESCE(p_service->>'name', v_existing.name);
    IF p_service ? 'description' THEN
        v_description := p_service->>'description';
    ELSE
        v_description := v_existing.description;
    END IF;

    v_pricing_type := COALESCE(p_service->>'pricing_type', v_existing.pricing_type);
    IF v_pricing_type NOT IN ('per_piece', 'per_square_meter', 'fixed_price') THEN
        RAISE EXCEPTION 'Invalid pricing type: %. Must be per_piece, per_square_meter, or fixed_price', v_pricing_type USING ERRCODE = '23514';
    END IF;

    IF p_service ? 'price' THEN
        v_price := (p_service->>'price')::BIGINT;
        IF v_price < 0 THEN
            RAISE EXCEPTION 'Price must be non-negative' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_price := v_existing.price;
    END IF;

    IF p_service ? 'is_active' THEN
        v_is_active := (p_service->>'is_active')::BOOLEAN;
    ELSIF p_service ? 'isActive' THEN
        v_is_active := (p_service->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_service->>'updated_at')::TIMESTAMPTZ, now());

    UPDATE services
    SET name = v_name,
        description = v_description,
        pricing_type = v_pricing_type,
        price = v_price,
        is_active = v_is_active,
        updated_at = v_updated_at
    WHERE id = p_service_id;

    IF p_item_type_ids IS NOT NULL THEN
        DELETE FROM service_item_types WHERE service_id = p_service_id;
        FOREACH v_item_type_id IN ARRAY p_item_type_ids LOOP
            INSERT INTO service_item_types (service_id, item_type_id, created_at)
            VALUES (p_service_id, v_item_type_id, now())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    v_result := jsonb_build_object(
        'id', p_service_id,
        'name', v_name,
        'pricing_type', v_pricing_type,
        'price', v_price,
        'is_active', v_is_active,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'service', p_service_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. Sync Create Order Aggregate (ATOMIC Order + Items + Carpets)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_order_aggregate(
    p_op_id UUID,
    p_order JSONB,
    p_items JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_order_id UUID;
    v_customer_id UUID;
    v_order_number TEXT;
    v_status TEXT;
    v_expected_pickup_date DATE;
    v_subtotal BIGINT;
    v_total BIGINT;
    v_item JSONB;
    v_item_id UUID;
    v_service_id UUID;
    v_item_pricing_type TEXT;
    v_carpet JSONB;
    v_carpet_id UUID;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_order_id := (p_order->>'id')::UUID;
    v_customer_id := (p_order->>'customer_id')::UUID;
    v_order_number := p_order->>'order_number';
    v_status := p_order->>'status';
    v_expected_pickup_date := (p_order->>'expected_pickup_date')::DATE;
    v_subtotal := (p_order->>'subtotal')::BIGINT;
    v_total := (p_order->>'total')::BIGINT;

    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = v_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', v_customer_id USING ERRCODE = '23503';
    END IF;

    -- Validate order number uniqueness
    IF EXISTS (SELECT 1 FROM orders WHERE order_number = v_order_number AND id <> v_order_id) THEN
        RAISE EXCEPTION 'Order number % already exists', v_order_number USING ERRCODE = '23505';
    END IF;

    -- Validate status
    IF v_status NOT IN ('processing', 'ready', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid order status: %', v_status USING ERRCODE = '23514';
    END IF;

    -- Validate non-negative financial values
    IF v_subtotal < 0 OR v_total < 0 THEN
        RAISE EXCEPTION 'Monetary amounts cannot be negative' USING ERRCODE = '23514';
    END IF;

    -- 1. Insert Order
    INSERT INTO orders (
        id, order_number, customer_id, customer_name_snapshot, customer_phone_snapshot,
        status, expected_pickup_date, notes,
        customer_pickup_requested, customer_pickup_fee,
        customer_delivery_requested, customer_delivery_fee,
        subtotal, discount, tax, total,
        completed_at, cancelled_at, cancellation_reason,
        created_at, updated_at
    ) VALUES (
        v_order_id,
        v_order_number,
        v_customer_id,
        COALESCE(p_order->>'customer_name_snapshot', ''),
        COALESCE(p_order->>'customer_phone_snapshot', ''),
        v_status,
        v_expected_pickup_date,
        p_order->>'notes',
        COALESCE((p_order->>'customer_pickup_requested')::BOOLEAN, false),
        COALESCE((p_order->>'customer_pickup_fee')::BIGINT, 0),
        COALESCE((p_order->>'customer_delivery_requested')::BOOLEAN, false),
        COALESCE((p_order->>'customer_delivery_fee')::BIGINT, 0),
        v_subtotal,
        COALESCE((p_order->>'discount')::BIGINT, 0),
        COALESCE((p_order->>'tax')::BIGINT, 0),
        v_total,
        (p_order->>'completed_at')::TIMESTAMPTZ,
        (p_order->>'cancelled_at')::TIMESTAMPTZ,
        p_order->>'cancellation_reason',
        COALESCE((p_order->>'created_at')::TIMESTAMPTZ, now()),
        COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
    );

    -- 2. Insert Items and optional Carpet data
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        v_service_id := (v_item->>'service_id')::UUID;
        v_item_pricing_type := v_item->>'pricing_type';

        -- Verify service exists
        IF NOT EXISTS (SELECT 1 FROM services WHERE id = v_service_id) THEN
            RAISE EXCEPTION 'Service % does not exist', v_service_id USING ERRCODE = '23503';
        END IF;

        IF v_item_pricing_type NOT IN ('per_piece', 'per_square_meter', 'fixed_price') THEN
            RAISE EXCEPTION 'Invalid order item pricing type: %', v_item_pricing_type USING ERRCODE = '23514';
        END IF;

        INSERT INTO order_items (
            id, order_id, item_type_id, item_definition_id, service_id,
            item_type_name_snapshot, item_definition_name_snapshot, service_name_snapshot,
            pricing_type, quantity, unit_price, calculated_total, notes,
            created_at, updated_at
        ) VALUES (
            v_item_id,
            v_order_id,
            v_item->>'item_type_id',
            v_item->>'item_definition_id',
            v_service_id,
            COALESCE(v_item->>'item_type_name_snapshot', ''),
            v_item->>'item_definition_name_snapshot',
            COALESCE(v_item->>'service_name_snapshot', ''),
            v_item_pricing_type,
            (v_item->>'quantity')::DOUBLE PRECISION,
            (v_item->>'unit_price')::BIGINT,
            (v_item->>'calculated_total')::BIGINT,
            v_item->>'notes',
            COALESCE((v_item->>'created_at')::TIMESTAMPTZ, now()),
            COALESCE((v_item->>'updated_at')::TIMESTAMPTZ, now())
        );

        -- If item contains carpet_data, insert it
        IF v_item ? 'carpet_data' AND (v_item->'carpet_data') IS NOT NULL AND (v_item->'carpet_data') <> 'null'::jsonb THEN
            v_carpet := v_item->'carpet_data';
            v_carpet_id := (v_carpet->>'id')::UUID;

            INSERT INTO order_item_carpets (
                id, order_item_id, carpet_size_id, length, width, area, created_at, updated_at
            ) VALUES (
                v_carpet_id,
                v_item_id,
                v_carpet->>'carpet_size_id',
                (v_carpet->>'length')::DOUBLE PRECISION,
                (v_carpet->>'width')::DOUBLE PRECISION,
                (v_carpet->>'area')::DOUBLE PRECISION,
                COALESCE((v_carpet->>'created_at')::TIMESTAMPTZ, now()),
                COALESCE((v_carpet->>'updated_at')::TIMESTAMPTZ, now())
            );
        END IF;
    END LOOP;

    v_result := jsonb_build_object(
        'id', v_order_id,
        'order_number', v_order_number,
        'status', v_status,
        'subtotal', v_subtotal,
        'total', v_total,
        'item_count', jsonb_array_length(p_items)
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 6. Sync Update Order
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_order(
    p_op_id UUID,
    p_order_id UUID,
    p_order JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_existing orders%ROWTYPE;
    v_status TEXT;
    v_completed_at TIMESTAMPTZ;
    v_cancelled_at TIMESTAMPTZ;
    v_cancellation_reason TEXT;
    v_updated_at TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id USING ERRCODE = 'P0002';
    END IF;

    v_status := COALESCE(p_order->>'status', v_existing.status);
    IF v_status NOT IN ('processing', 'ready', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid order status: %', v_status USING ERRCODE = '23514';
    END IF;

    IF p_order ? 'completed_at' THEN
        v_completed_at := (p_order->>'completed_at')::TIMESTAMPTZ;
    ELSE
        v_completed_at := v_existing.completed_at;
    END IF;

    IF p_order ? 'cancelled_at' THEN
        v_cancelled_at := (p_order->>'cancelled_at')::TIMESTAMPTZ;
    ELSE
        v_cancelled_at := v_existing.cancelled_at;
    END IF;

    IF p_order ? 'cancellation_reason' THEN
        v_cancellation_reason := p_order->>'cancellation_reason';
    ELSE
        v_cancellation_reason := v_existing.cancellation_reason;
    END IF;

    v_updated_at := COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now());

    UPDATE orders
    SET status = v_status,
        completed_at = v_completed_at,
        cancelled_at = v_cancelled_at,
        cancellation_reason = v_cancellation_reason,
        notes = COALESCE(p_order->>'notes', orders.notes),
        updated_at = v_updated_at
    WHERE id = p_order_id;

    v_result := jsonb_build_object(
        'id', p_order_id,
        'status', v_status,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. Sync Create Storage Record (Atomic Invariant: 1 active record per item)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_storage_record(
    p_op_id UUID,
    p_storage JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_order_item_id UUID;
    v_location_id TEXT;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_storage->>'id')::UUID;
    v_order_item_id := (p_storage->>'order_item_id')::UUID;
    v_location_id := p_storage->>'storage_location_id';
    v_is_active := COALESCE((p_storage->>'is_active')::BOOLEAN, (p_storage->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_storage->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_storage->>'updated_at')::TIMESTAMPTZ, now());

    -- Validate order item exists
    IF NOT EXISTS (SELECT 1 FROM order_items WHERE id = v_order_item_id) THEN
        RAISE EXCEPTION 'Order item % does not exist', v_order_item_id USING ERRCODE = '23503';
    END IF;

    -- Enforce storage invariant: if new record is active, deactivate previous active records for this item
    IF v_is_active = true THEN
        UPDATE storage_records
        SET is_active = false, updated_at = now()
        WHERE order_item_id = v_order_item_id AND is_active = true;
    END IF;

    INSERT INTO storage_records (id, order_item_id, storage_location_id, is_active, created_at, updated_at)
    VALUES (v_id, v_order_item_id, v_location_id, v_is_active, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        storage_location_id = EXCLUDED.storage_location_id,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    v_result := jsonb_build_object(
        'id', v_id,
        'order_item_id', v_order_item_id,
        'storage_location_id', v_location_id,
        'is_active', v_is_active,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'storage_record', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 8. Sync Update Storage Record (Move / Unstore)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_storage_record(
    p_op_id UUID,
    p_record_id UUID,
    p_storage JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_existing storage_records%ROWTYPE;
    v_location_id TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM storage_records WHERE id = p_record_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Storage record % not found', p_record_id USING ERRCODE = 'P0002';
    END IF;

    v_location_id := COALESCE(p_storage->>'storage_location_id', v_existing.storage_location_id);
    IF p_storage ? 'is_active' THEN
        v_is_active := (p_storage->>'is_active')::BOOLEAN;
    ELSIF p_storage ? 'isActive' THEN
        v_is_active := (p_storage->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_storage->>'updated_at')::TIMESTAMPTZ, now());

    -- If activating/moving to active, ensure no other record for this item is active
    IF v_is_active = true AND v_existing.is_active = false THEN
        UPDATE storage_records
        SET is_active = false, updated_at = now()
        WHERE order_item_id = v_existing.order_item_id AND is_active = true AND id <> p_record_id;
    END IF;

    UPDATE storage_records
    SET storage_location_id = v_location_id,
        is_active = v_is_active,
        updated_at = v_updated_at
    WHERE id = p_record_id;

    v_result := jsonb_build_object(
        'id', p_record_id,
        'order_item_id', v_existing.order_item_id,
        'storage_location_id', v_location_id,
        'is_active', v_is_active,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'storage_record', p_record_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
