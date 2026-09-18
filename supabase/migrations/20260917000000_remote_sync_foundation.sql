-- =============================================================================
-- Phase C1 — Supabase PostgreSQL Schema Migration
-- Laundry Management System — Remote Sync Foundation (sync_changes,
-- entity server_version, structured concurrency, and cursor-based pull RPC)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. sync_changes Table (Durable Append-Only Synchronization Change Log)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_changes (
    sequence BIGSERIAL PRIMARY KEY,
    operation_id TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    server_version INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Pull cursor streaming index is provided by PRIMARY KEY (sequence)
CREATE INDEX IF NOT EXISTS idx_sync_changes_entity ON sync_changes(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_changes_created_at ON sync_changes(created_at);

ALTER TABLE sync_changes ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 2. Add server_version Column to Approved Mutable Entities
-- (Per docs/04-database/tables.md §21.1)
-- -----------------------------------------------------------------------------
ALTER TABLE orders ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE expense_categories ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE services ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE item_types ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE item_definitions ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE carpet_sizes ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE storage_locations ADD COLUMN IF NOT EXISTS server_version INTEGER NOT NULL DEFAULT 1;

-- Payments, storage_records, order_items, order_item_carpets intentionally do NOT have server_version.

-- -----------------------------------------------------------------------------
-- 3. Pull Cursor RPC Function: get_sync_changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_sync_changes(
    p_after BIGINT DEFAULT 0,
    p_limit INT DEFAULT 100
) RETURNS JSONB AS $$
DECLARE
    v_limit INT;
    v_oldest_sequence BIGINT;
    v_latest_sequence BIGINT;
    v_changes JSONB;
    v_has_more BOOLEAN;
BEGIN
    v_limit := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);

    SELECT MIN(sequence), MAX(sequence)
    INTO v_oldest_sequence, v_latest_sequence
    FROM sync_changes;

    IF v_oldest_sequence IS NULL THEN
        RETURN jsonb_build_object(
            'changes', '[]'::jsonb,
            'has_more', false,
            'latest_sequence', 0
        );
    END IF;

    IF p_after > 0 AND p_after < (v_oldest_sequence - 1) THEN
        RAISE EXCEPTION 'CURSOR_TOO_OLD: requested sequence % is older than oldest available sequence %', p_after, v_oldest_sequence
            USING ERRCODE = 'P0005';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(c)), '[]'::jsonb)
    INTO v_changes
    FROM (
        SELECT
            sequence,
            operation_id,
            entity_type,
            entity_id,
            operation_type,
            payload,
            server_version,
            created_at
        FROM sync_changes
        WHERE sequence > COALESCE(p_after, 0)
        ORDER BY sequence ASC
        LIMIT v_limit
    ) c;

    SELECT EXISTS (
        SELECT 1
        FROM sync_changes
        WHERE sequence > COALESCE(p_after, 0)
        ORDER BY sequence ASC
        OFFSET v_limit
        LIMIT 1
    ) INTO v_has_more;

    RETURN jsonb_build_object(
        'changes', v_changes,
        'has_more', v_has_more,
        'latest_sequence', COALESCE(v_latest_sequence, 0)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 3.1 Idempotency Helper: check_idempotency
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_idempotency(p_op_id TEXT)
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
-- 4. Customer RPCs with server_version & sync_changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_customer(
    p_op_id TEXT,
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
    v_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_customer->>'id')::UUID;
    v_name := trim(p_customer->>'name');
    v_phone := trim(p_customer->>'phone');
    v_notes := p_customer->>'notes';
    v_created_at := COALESCE((p_customer->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_customer->>'updated_at')::TIMESTAMPTZ, now());

    IF v_name IS NULL OR v_name = '' THEN
        RAISE EXCEPTION 'Customer name is required' USING ERRCODE = '23502';
    END IF;
    IF v_phone IS NULL OR v_phone = '' THEN
        RAISE EXCEPTION 'Customer phone is required' USING ERRCODE = '23502';
    END IF;

    IF EXISTS (SELECT 1 FROM customers WHERE phone = v_phone AND id <> v_id) THEN
        RAISE EXCEPTION 'Customer with phone % already exists', v_phone USING ERRCODE = '23505';
    END IF;

    INSERT INTO customers (id, name, phone, notes, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_phone, v_notes, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        phone = EXCLUDED.phone,
        notes = EXCLUDED.notes,
        server_version = customers.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'phone', v_phone,
        'notes', v_notes,
        'server_version', v_version,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'customer', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'customer', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_customer(
    p_op_id TEXT,
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
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM customers WHERE id = p_customer_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id USING ERRCODE = 'P0002';
    END IF;

    IF p_customer ? 'base_version' AND (p_customer->>'base_version') IS NOT NULL THEN
        v_base_version := (p_customer->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for customer %',
                v_base_version, v_existing.server_version, p_customer_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    v_name := COALESCE(trim(p_customer->>'name'), v_existing.name);
    v_phone := COALESCE(trim(p_customer->>'phone'), v_existing.phone);
    IF p_customer ? 'notes' THEN
        v_notes := p_customer->>'notes';
    ELSE
        v_notes := v_existing.notes;
    END IF;
    v_updated_at := COALESCE((p_customer->>'updated_at')::TIMESTAMPTZ, now());

    IF EXISTS (SELECT 1 FROM customers WHERE phone = v_phone AND id <> p_customer_id) THEN
        RAISE EXCEPTION 'Customer with phone % already exists', v_phone USING ERRCODE = '23505';
    END IF;

    v_new_version := v_existing.server_version + 1;

    UPDATE customers
    SET name = v_name,
        phone = v_phone,
        notes = v_notes,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = p_customer_id;

    v_result := jsonb_build_object(
        'id', p_customer_id,
        'name', v_name,
        'phone', v_phone,
        'notes', v_notes,
        'server_version', v_new_version,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'customer', p_customer_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'customer', p_customer_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. Services RPCs with server_version & sync_changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_service(
    p_op_id TEXT,
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
    v_version INTEGER;
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

    INSERT INTO services (id, name, description, pricing_type, price, is_active, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_description, v_pricing_type, v_price, v_is_active, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        pricing_type = EXCLUDED.pricing_type,
        price = EXCLUDED.price,
        is_active = EXCLUDED.is_active,
        server_version = services.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

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
        'description', v_description,
        'pricing_type', v_pricing_type,
        'price', v_price,
        'is_active', v_is_active,
        'server_version', v_version,
        'supported_item_type_ids', COALESCE(p_item_type_ids, ARRAY[]::TEXT[]),
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'service', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'service', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_service(
    p_op_id TEXT,
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
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM services WHERE id = p_service_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service % not found', p_service_id USING ERRCODE = 'P0002';
    END IF;

    IF p_service ? 'base_version' AND (p_service->>'base_version') IS NOT NULL THEN
        v_base_version := (p_service->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for service %',
                v_base_version, v_existing.server_version, p_service_id USING ERRCODE = 'P0004';
        END IF;
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
    v_new_version := v_existing.server_version + 1;

    UPDATE services
    SET name = v_name,
        description = v_description,
        pricing_type = v_pricing_type,
        price = v_price,
        is_active = v_is_active,
        server_version = v_new_version,
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
        'description', v_description,
        'pricing_type', v_pricing_type,
        'price', v_price,
        'is_active', v_is_active,
        'server_version', v_new_version,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'service', p_service_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'service', p_service_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 6. Order Creation Aggregate & Order Updates
-- (Order Creation is the ONLY aggregate change record)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_order_aggregate(
    p_op_id TEXT,
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
    v_aggregate_payload JSONB;
    v_items_array JSONB := '[]'::jsonb;
    v_item_obj JSONB;
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

    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = v_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', v_customer_id USING ERRCODE = '23503';
    END IF;

    IF EXISTS (SELECT 1 FROM orders WHERE order_number = v_order_number AND id <> v_order_id) THEN
        RAISE EXCEPTION 'Order number % already exists', v_order_number USING ERRCODE = '23505';
    END IF;

    IF v_status NOT IN ('processing', 'ready', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid order status: %', v_status USING ERRCODE = '23514';
    END IF;

    IF v_subtotal < 0 OR v_total < 0 THEN
        RAISE EXCEPTION 'Monetary amounts cannot be negative' USING ERRCODE = '23514';
    END IF;

    -- 1. Insert Order with server_version = 1
    INSERT INTO orders (
        id, order_number, customer_id, customer_name_snapshot, customer_phone_snapshot,
        status, expected_pickup_date, notes,
        customer_pickup_requested, customer_pickup_fee,
        customer_delivery_requested, customer_delivery_fee,
        subtotal, discount, tax, total, paid_amount,
        completed_at, cancelled_at, cancellation_reason,
        server_version, created_at, updated_at
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
        COALESCE((p_order->>'paid_amount')::BIGINT, 0),
        (p_order->>'completed_at')::TIMESTAMPTZ,
        (p_order->>'cancelled_at')::TIMESTAMPTZ,
        p_order->>'cancellation_reason',
        1,
        COALESCE((p_order->>'created_at')::TIMESTAMPTZ, now()),
        COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
    );

    -- 2. Insert Items and optional Carpet data
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        v_service_id := (v_item->>'service_id')::UUID;
        v_item_pricing_type := v_item->>'pricing_type';

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

        v_item_obj := v_item;

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

        v_items_array := v_items_array || jsonb_build_array(v_item_obj);
    END LOOP;

    -- Construct the canonical aggregate payload for RemoteChangeApplier
    v_aggregate_payload := jsonb_build_object(
        'id', v_order_id,
        'order_number', v_order_number,
        'customer_id', v_customer_id,
        'customer_name_snapshot', COALESCE(p_order->>'customer_name_snapshot', ''),
        'customer_phone_snapshot', COALESCE(p_order->>'customer_phone_snapshot', ''),
        'status', v_status,
        'expected_pickup_date', v_expected_pickup_date,
        'notes', p_order->>'notes',
        'customer_pickup_requested', COALESCE((p_order->>'customer_pickup_requested')::BOOLEAN, false),
        'customer_pickup_fee', COALESCE((p_order->>'customer_pickup_fee')::BIGINT, 0),
        'customer_delivery_requested', COALESCE((p_order->>'customer_delivery_requested')::BOOLEAN, false),
        'customer_delivery_fee', COALESCE((p_order->>'customer_delivery_fee')::BIGINT, 0),
        'subtotal', v_subtotal,
        'discount', COALESCE((p_order->>'discount')::BIGINT, 0),
        'tax', COALESCE((p_order->>'tax')::BIGINT, 0),
        'total', v_total,
        'paid_amount', COALESCE((p_order->>'paid_amount')::BIGINT, 0),
        'server_version', 1,
        'items', v_items_array,
        'created_at', COALESCE((p_order->>'created_at')::TIMESTAMPTZ, now()),
        'updated_at', COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
    );

    v_result := jsonb_build_object(
        'id', v_order_id,
        'order_number', v_order_number,
        'status', v_status,
        'subtotal', v_subtotal,
        'total', v_total,
        'server_version', 1,
        'item_count', jsonb_array_length(p_items)
    );

    -- Insert atomic aggregate change to sync_changes
    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', v_aggregate_payload, 1, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_order(
    p_op_id TEXT,
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
    v_notes TEXT;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id USING ERRCODE = 'P0002';
    END IF;

    -- Concurrency check
    IF p_order ? 'base_version' AND (p_order->>'base_version') IS NOT NULL THEN
        v_base_version := (p_order->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for order %',
                v_base_version, v_existing.server_version, p_order_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    v_status := COALESCE(p_order->>'status', v_existing.status);
    IF v_status NOT IN ('processing', 'ready', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid order status: %', v_status USING ERRCODE = '23514';
    END IF;

    -- Domain lifecycle transition matrix check
    IF v_existing.status IN ('completed', 'cancelled') AND v_status <> v_existing.status THEN
        RAISE EXCEPTION 'INVALID_LIFECYCLE_TRANSITION: Cannot transition order % from terminal state % to %',
            p_order_id, v_existing.status, v_status USING ERRCODE = '23514';
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

    IF p_order ? 'notes' THEN
        v_notes := p_order->>'notes';
    ELSE
        v_notes := v_existing.notes;
    END IF;

    v_updated_at := COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    UPDATE orders
    SET status = v_status,
        completed_at = v_completed_at,
        cancelled_at = v_cancelled_at,
        cancellation_reason = v_cancellation_reason,
        notes = v_notes,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = p_order_id;

    -- Subsequent Order mutations are entity-specific (NOT aggregate)
    v_result := jsonb_build_object(
        'id', p_order_id,
        'status', v_status,
        'completed_at', v_completed_at,
        'cancelled_at', v_cancelled_at,
        'cancellation_reason', v_cancellation_reason,
        'notes', v_notes,
        'server_version', v_new_version,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. Payment RPC with Atomic sync_changes (Append-Only, No server_version on payment)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_payment(
    p_op_id TEXT,
    p_payment JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_order_id UUID;
    v_amount BIGINT;
    v_payment_method TEXT;
    v_paid_at TIMESTAMPTZ;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_order_total BIGINT;
    v_order_paid_amount BIGINT;
    v_order_status TEXT;
    v_remaining BIGINT;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_payment IS NULL THEN
        RAISE EXCEPTION 'Payment payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_payment->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid payment UUID: %', p_payment->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Payment ID is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_order_id := (p_payment->>'order_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid order UUID: %', p_payment->>'order_id' USING ERRCODE = '23514';
    END;

    IF v_order_id IS NULL THEN
        RAISE EXCEPTION 'Order ID is required' USING ERRCODE = '23502';
    END IF;

    IF NOT (p_payment ? 'amount') OR (p_payment->>'amount') IS NULL THEN
        RAISE EXCEPTION 'Payment amount is required' USING ERRCODE = '23502';
    END IF;

    v_amount := (p_payment->>'amount')::BIGINT;
    IF v_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero' USING ERRCODE = '23514';
    END IF;

    v_payment_method := p_payment->>'payment_method';
    IF v_payment_method IS NULL OR v_payment_method NOT IN ('cash', 'insta_pay', 'e_wallet') THEN
        RAISE EXCEPTION 'Invalid payment method: %. Must be cash, insta_pay, or e_wallet', v_payment_method USING ERRCODE = '23514';
    END IF;

    v_paid_at := COALESCE((p_payment->>'paid_at')::TIMESTAMPTZ, now());
    v_created_at := COALESCE((p_payment->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_payment->>'updated_at')::TIMESTAMPTZ, now());

    -- Authoritative FOR UPDATE row lock on parent order
    SELECT total, paid_amount, status
    INTO v_order_total, v_order_paid_amount, v_order_status
    FROM orders
    WHERE id = v_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', v_order_id USING ERRCODE = 'P0002';
    END IF;

    IF v_order_status = 'cancelled' THEN
        RAISE EXCEPTION 'INVALID_LIFECYCLE_TRANSITION: Cannot record payment for a cancelled order' USING ERRCODE = '23505';
    END IF;

    v_remaining := v_order_total - COALESCE(v_order_paid_amount, 0);
    IF v_amount > v_remaining THEN
        RAISE EXCEPTION 'PAYMENT_BALANCE_EXCEEDED: Payment amount % exceeds remaining order balance %', v_amount, v_remaining USING ERRCODE = '23505';
    END IF;

    -- Insert Payment record (append-only)
    INSERT INTO payments (
        id,
        order_id,
        amount,
        payment_method,
        paid_at,
        created_at,
        updated_at
    ) VALUES (
        v_id,
        v_order_id,
        v_amount,
        v_payment_method,
        v_paid_at,
        v_created_at,
        v_updated_at
    );

    -- Increment order paid amount atomically
    UPDATE orders
    SET paid_amount = paid_amount + v_amount,
        updated_at = now()
    WHERE id = v_order_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'order_id', v_order_id,
        'amount', v_amount,
        'payment_method', v_payment_method,
        'paid_at', v_paid_at,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    -- Insert change log (payments have server_version = NULL)
    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'payment', v_id::TEXT, 'create', v_result, NULL, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'payment', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 8. Storage Move & Create RPCs with Concurrency Conflict & sync_changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_storage_record(
    p_op_id TEXT,
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
    v_active storage_records%ROWTYPE;
    v_op_type TEXT := 'create';
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

    IF NOT EXISTS (SELECT 1 FROM order_items WHERE id = v_order_item_id) THEN
        RAISE EXCEPTION 'Order item % does not exist', v_order_item_id USING ERRCODE = '23503';
    END IF;

    -- Concurrency check on active storage record for this item
    IF v_is_active = true THEN
        SELECT * INTO v_active
        FROM storage_records
        WHERE order_item_id = v_order_item_id AND is_active = true
        FOR UPDATE;

        IF FOUND THEN
            -- If caller provided expected previous location, verify it matches
            IF p_storage ? 'previous_storage_location_id' AND
               (p_storage->>'previous_storage_location_id') IS NOT NULL AND
               (p_storage->>'previous_storage_location_id') <> v_active.storage_location_id THEN
                RAISE EXCEPTION 'CONCURRENCY_CONFLICT: Item % is at location %, not expected %',
                    v_order_item_id, v_active.storage_location_id, (p_storage->>'previous_storage_location_id') USING ERRCODE = 'P0004';
            END IF;

            -- Deactivate previous active record
            UPDATE storage_records
            SET is_active = false, updated_at = now()
            WHERE id = v_active.id;

            v_op_type := 'move';
        END IF;
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

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'storage_record', v_id::TEXT, v_op_type, v_result, NULL, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'storage_record', v_id::TEXT, v_op_type, now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_storage_record(
    p_op_id TEXT,
    p_record_id UUID,
    p_storage JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_existing storage_records%ROWTYPE;
    v_active storage_records%ROWTYPE;
    v_order_item_id UUID;
    v_location_id TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM storage_records WHERE id = p_record_id FOR UPDATE;

    -- If record doesn't exist, this is a Move dispatch where p_record_id is the new storage record ID
    IF NOT FOUND THEN
        IF p_storage ? 'order_item_id' AND (p_storage->>'order_item_id') IS NOT NULL THEN
            v_order_item_id := (p_storage->>'order_item_id')::UUID;
            v_location_id := p_storage->>'storage_location_id';
            v_is_active := COALESCE((p_storage->>'is_active')::BOOLEAN, (p_storage->>'isActive')::BOOLEAN, true);

            -- Find and lock currently active record for this order item
            SELECT * INTO v_active
            FROM storage_records
            WHERE order_item_id = v_order_item_id AND is_active = true
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'CONCURRENCY_CONFLICT: Order item % has no active storage record to move from',
                    v_order_item_id USING ERRCODE = 'P0004';
            END IF;

            IF p_storage ? 'previous_storage_location_id' AND
               (p_storage->>'previous_storage_location_id') IS NOT NULL AND
               (p_storage->>'previous_storage_location_id') <> v_active.storage_location_id THEN
                RAISE EXCEPTION 'CONCURRENCY_CONFLICT: Order item % is at location %, not expected %',
                    v_order_item_id, v_active.storage_location_id, (p_storage->>'previous_storage_location_id') USING ERRCODE = 'P0004';
            END IF;

            -- Deactivate previous active location
            UPDATE storage_records
            SET is_active = false, updated_at = now()
            WHERE id = v_active.id;

            -- Insert new active location
            INSERT INTO storage_records (id, order_item_id, storage_location_id, is_active, created_at, updated_at)
            VALUES (p_record_id, v_order_item_id, v_location_id, v_is_active, now(), now());

            v_result := jsonb_build_object(
                'id', p_record_id,
                'order_item_id', v_order_item_id,
                'storage_location_id', v_location_id,
                'is_active', v_is_active,
                'updated_at', now()
            );

            INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
            VALUES (p_op_id, 'storage_record', p_record_id::TEXT, 'move', v_result, NULL, now());

            INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
            VALUES (p_op_id, 'storage_record', p_record_id::TEXT, 'move', now(), v_result);

            RETURN v_result;
        ELSE
            RAISE EXCEPTION 'Storage record % not found', p_record_id USING ERRCODE = 'P0002';
        END IF;
    END IF;

    -- Record exists: update in place (e.g. unstore / deactivate)
    v_location_id := COALESCE(p_storage->>'storage_location_id', v_existing.storage_location_id);
    IF p_storage ? 'is_active' THEN
        v_is_active := (p_storage->>'is_active')::BOOLEAN;
    ELSIF p_storage ? 'isActive' THEN
        v_is_active := (p_storage->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_storage->>'updated_at')::TIMESTAMPTZ, now());

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

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'storage_record', p_record_id::TEXT, CASE WHEN v_is_active = false THEN 'unstore' ELSE 'update' END, v_result, NULL, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'storage_record', p_record_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 9. Expenses & Categories RPCs with server_version & sync_changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_expense_category(
    p_op_id TEXT,
    p_category JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_category IS NULL THEN
        RAISE EXCEPTION 'Category payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_category->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid category UUID: %', p_category->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Category ID is required' USING ERRCODE = '23502';
    END IF;

    v_name := trim(COALESCE(p_category->>'name', ''));
    IF v_name = '' THEN
        RAISE EXCEPTION 'Category name cannot be empty' USING ERRCODE = '23502';
    END IF;

    IF EXISTS (
        SELECT 1 FROM expense_categories
        WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Expense category with name "%" already exists', v_name USING ERRCODE = '23505';
    END IF;

    v_is_active := COALESCE((p_category->>'is_active')::BOOLEAN, true);
    v_created_at := COALESCE((p_category->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_category->>'updated_at')::TIMESTAMPTZ, now());

    INSERT INTO expense_categories (id, name, is_active, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_is_active, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        server_version = expense_categories.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_version,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'expense_category', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'expense_category', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_expense_category(
    p_op_id TEXT,
    p_category_id TEXT,
    p_category JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_existing expense_categories%ROWTYPE;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    BEGIN
        v_id := p_category_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid category UUID: %', p_category_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing FROM expense_categories WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Expense category % not found', p_category_id USING ERRCODE = 'P0002';
    END IF;

    IF p_category ? 'base_version' AND (p_category->>'base_version') IS NOT NULL THEN
        v_base_version := (p_category->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for category %',
                v_base_version, v_existing.server_version, p_category_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    IF p_category ? 'name' THEN
        v_name := trim(COALESCE(p_category->>'name', ''));
        IF v_name = '' THEN
            RAISE EXCEPTION 'Category name cannot be empty' USING ERRCODE = '23502';
        END IF;

        IF EXISTS (
            SELECT 1 FROM expense_categories
            WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
        ) THEN
            RAISE EXCEPTION 'Expense category with name "%" already exists', v_name USING ERRCODE = '23505';
        END IF;
    ELSE
        v_name := v_existing.name;
    END IF;

    IF p_category ? 'is_active' THEN
        v_is_active := (p_category->>'is_active')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_category->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    UPDATE expense_categories
    SET name = v_name,
        is_active = v_is_active,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_new_version,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'expense_category', v_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'expense_category', v_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_create_expense(
    p_op_id TEXT,
    p_expense JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_category_id UUID;
    v_amount BIGINT;
    v_expense_name TEXT;
    v_expense_date DATE;
    v_notes TEXT;
    v_snapshot TEXT;
    v_cat_name TEXT;
    v_cat_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_expense IS NULL THEN
        RAISE EXCEPTION 'Expense payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_expense->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid expense UUID: %', p_expense->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Expense ID is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_category_id := (p_expense->>'expense_category_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid expense category UUID: %', p_expense->>'expense_category_id' USING ERRCODE = '23514';
    END;

    IF v_category_id IS NULL THEN
        RAISE EXCEPTION 'Expense category ID is required' USING ERRCODE = '23502';
    END IF;

    SELECT name, is_active INTO v_cat_name, v_cat_is_active
    FROM expense_categories
    WHERE id = v_category_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Expense category % does not exist', v_category_id USING ERRCODE = '23503';
    END IF;

    IF NOT (p_expense ? 'amount') OR (p_expense->>'amount') IS NULL THEN
        RAISE EXCEPTION 'Expense amount is required' USING ERRCODE = '23502';
    END IF;

    v_amount := (p_expense->>'amount')::BIGINT;
    IF v_amount <= 0 THEN
        RAISE EXCEPTION 'Expense amount must be greater than zero' USING ERRCODE = '23514';
    END IF;

    BEGIN
        v_expense_date := (p_expense->>'expense_date')::DATE;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid expense date format: %. Expected YYYY-MM-DD', p_expense->>'expense_date' USING ERRCODE = '23514';
    END;

    IF v_expense_date IS NULL THEN
        RAISE EXCEPTION 'Expense date is required' USING ERRCODE = '23502';
    END IF;

    v_expense_name := trim(COALESCE(p_expense->>'expense_name', ''));
    v_notes := trim(COALESCE(p_expense->>'notes', ''));
    v_snapshot := trim(COALESCE(p_expense->>'category_name_snapshot', v_cat_name));

    IF (v_snapshot = 'أخرى' OR v_cat_name = 'أخرى') AND v_expense_name = '' THEN
        RAISE EXCEPTION 'Expense name is required when category is أخرى' USING ERRCODE = '23514';
    END IF;

    v_created_at := COALESCE((p_expense->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_expense->>'updated_at')::TIMESTAMPTZ, now());

    INSERT INTO expenses (
        id,
        expense_category_id,
        amount,
        expense_name,
        expense_date,
        notes,
        category_name_snapshot,
        server_version,
        created_at,
        updated_at
    ) VALUES (
        v_id,
        v_category_id,
        v_amount,
        NULLIF(v_expense_name, ''),
        v_expense_date,
        NULLIF(v_notes, ''),
        v_snapshot,
        1,
        v_created_at,
        v_updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        expense_category_id = EXCLUDED.expense_category_id,
        amount = EXCLUDED.amount,
        expense_name = EXCLUDED.expense_name,
        expense_date = EXCLUDED.expense_date,
        notes = EXCLUDED.notes,
        category_name_snapshot = EXCLUDED.category_name_snapshot,
        server_version = expenses.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_result := jsonb_build_object(
        'id', v_id,
        'expense_category_id', v_category_id,
        'amount', v_amount,
        'expense_name', NULLIF(v_expense_name, ''),
        'expense_date', v_expense_date,
        'notes', NULLIF(v_notes, ''),
        'category_name_snapshot', v_snapshot,
        'server_version', v_version,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'expense', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'expense', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_expense(
    p_op_id TEXT,
    p_expense_id TEXT,
    p_expense JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_existing expenses%ROWTYPE;
    v_amount BIGINT;
    v_expense_name TEXT;
    v_expense_date DATE;
    v_notes TEXT;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    BEGIN
        v_id := p_expense_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid expense UUID: %', p_expense_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing FROM expenses WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Expense % not found', p_expense_id USING ERRCODE = 'P0002';
    END IF;

    IF p_expense ? 'base_version' AND (p_expense->>'base_version') IS NOT NULL THEN
        v_base_version := (p_expense->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for expense %',
                v_base_version, v_existing.server_version, p_expense_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    IF p_expense ? 'amount' AND (p_expense->>'amount') IS NOT NULL THEN
        v_amount := (p_expense->>'amount')::BIGINT;
        IF v_amount <= 0 THEN
            RAISE EXCEPTION 'Expense amount must be greater than zero' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_amount := v_existing.amount;
    END IF;

    IF p_expense ? 'expense_name' THEN
        v_expense_name := trim(COALESCE(p_expense->>'expense_name', ''));
    ELSE
        v_expense_name := v_existing.expense_name;
    END IF;

    IF p_expense ? 'expense_date' AND (p_expense->>'expense_date') IS NOT NULL THEN
        BEGIN
            v_expense_date := (p_expense->>'expense_date')::DATE;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid expense date format: %. Expected YYYY-MM-DD', p_expense->>'expense_date' USING ERRCODE = '23514';
        END;
    ELSE
        v_expense_date := v_existing.expense_date;
    END IF;

    IF p_expense ? 'notes' THEN
        v_notes := trim(COALESCE(p_expense->>'notes', ''));
    ELSE
        v_notes := v_existing.notes;
    END IF;

    v_updated_at := COALESCE((p_expense->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    UPDATE expenses
    SET amount = v_amount,
        expense_name = NULLIF(v_expense_name, ''),
        expense_date = v_expense_date,
        notes = NULLIF(v_notes, ''),
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'expense_category_id', v_existing.expense_category_id,
        'amount', v_amount,
        'expense_name', NULLIF(v_expense_name, ''),
        'expense_date', v_expense_date,
        'notes', NULLIF(v_notes, ''),
        'category_name_snapshot', v_existing.category_name_snapshot,
        'server_version', v_new_version,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'expense', v_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'expense', v_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 10. Master Data RPCs with server_version & sync_changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_item_type(
    p_op_id TEXT,
    p_item_type JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_item_type->>'id')::UUID;
    v_name := trim(p_item_type->>'name');
    v_is_active := COALESCE((p_item_type->>'is_active')::BOOLEAN, (p_item_type->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_item_type->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_item_type->>'updated_at')::TIMESTAMPTZ, now());

    IF v_name IS NULL OR v_name = '' THEN
        RAISE EXCEPTION 'Item type name is required' USING ERRCODE = '23502';
    END IF;

    IF EXISTS (SELECT 1 FROM item_types WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id) THEN
        RAISE EXCEPTION 'Item type with name "%" already exists', v_name USING ERRCODE = '23505';
    END IF;

    INSERT INTO item_types (id, name, is_active, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_is_active, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        server_version = item_types.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_version,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'item_type', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'item_type', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_item_type(
    p_op_id TEXT,
    p_item_type_id TEXT,
    p_item_type JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_existing item_types%ROWTYPE;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := p_item_type_id::UUID;
    SELECT * INTO v_existing FROM item_types WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item type % not found', p_item_type_id USING ERRCODE = 'P0002';
    END IF;

    IF p_item_type ? 'base_version' AND (p_item_type->>'base_version') IS NOT NULL THEN
        v_base_version := (p_item_type->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for item_type %',
                v_base_version, v_existing.server_version, p_item_type_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    v_name := COALESCE(trim(p_item_type->>'name'), v_existing.name);
    IF p_item_type ? 'is_active' THEN
        v_is_active := (p_item_type->>'is_active')::BOOLEAN;
    ELSIF p_item_type ? 'isActive' THEN
        v_is_active := (p_item_type->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_item_type->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    UPDATE item_types
    SET name = v_name,
        is_active = v_is_active,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_new_version,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'item_type', v_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'item_type', v_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_create_item_definition(
    p_op_id TEXT,
    p_item_def JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_item_type_id UUID;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_item_def->>'id')::UUID;
    v_item_type_id := (p_item_def->>'item_type_id')::UUID;
    v_name := trim(p_item_def->>'name');
    v_is_active := COALESCE((p_item_def->>'is_active')::BOOLEAN, (p_item_def->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_item_def->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_item_def->>'updated_at')::TIMESTAMPTZ, now());

    IF NOT EXISTS (SELECT 1 FROM item_types WHERE id = v_item_type_id) THEN
        RAISE EXCEPTION 'Item type % does not exist', v_item_type_id USING ERRCODE = '23503';
    END IF;

    IF EXISTS (SELECT 1 FROM item_definitions WHERE item_type_id = v_item_type_id AND LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id) THEN
        RAISE EXCEPTION 'Item definition with name "%" already exists for this type', v_name USING ERRCODE = '23505';
    END IF;

    INSERT INTO item_definitions (id, item_type_id, name, is_active, server_version, created_at, updated_at)
    VALUES (v_id, v_item_type_id, v_name, v_is_active, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        server_version = item_definitions.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_result := jsonb_build_object(
        'id', v_id,
        'item_type_id', v_item_type_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_version,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'item_definition', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'item_definition', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_item_definition(
    p_op_id TEXT,
    p_item_def_id TEXT,
    p_item_def JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_existing item_definitions%ROWTYPE;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := p_item_def_id::UUID;
    SELECT * INTO v_existing FROM item_definitions WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item definition % not found', p_item_def_id USING ERRCODE = 'P0002';
    END IF;

    IF p_item_def ? 'base_version' AND (p_item_def->>'base_version') IS NOT NULL THEN
        v_base_version := (p_item_def->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for item_definition %',
                v_base_version, v_existing.server_version, p_item_def_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    v_name := COALESCE(trim(p_item_def->>'name'), v_existing.name);
    IF p_item_def ? 'is_active' THEN
        v_is_active := (p_item_def->>'is_active')::BOOLEAN;
    ELSIF p_item_def ? 'isActive' THEN
        v_is_active := (p_item_def->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_item_def->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    UPDATE item_definitions
    SET name = v_name,
        is_active = v_is_active,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'item_type_id', v_existing.item_type_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_new_version,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'item_definition', v_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'item_definition', v_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_create_carpet_size(
    p_op_id TEXT,
    p_carpet_size JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_length NUMERIC;
    v_width NUMERIC;
    v_area NUMERIC;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_carpet_size->>'id')::UUID;
    v_name := p_carpet_size->>'name';
    v_length := (p_carpet_size->>'length')::NUMERIC;
    v_width := (p_carpet_size->>'width')::NUMERIC;
    v_area := (p_carpet_size->>'area')::NUMERIC;
    v_is_active := COALESCE((p_carpet_size->>'is_active')::BOOLEAN, (p_carpet_size->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_carpet_size->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_carpet_size->>'updated_at')::TIMESTAMPTZ, now());

    IF v_length <= 0 OR v_width <= 0 OR v_area <= 0 THEN
        RAISE EXCEPTION 'Dimensions and area must be positive numbers' USING ERRCODE = '23514';
    END IF;

    INSERT INTO carpet_sizes (id, name, length, width, area, is_active, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_length, v_width, v_area, v_is_active, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        length = EXCLUDED.length,
        width = EXCLUDED.width,
        area = EXCLUDED.area,
        is_active = EXCLUDED.is_active,
        server_version = carpet_sizes.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'length', v_length,
        'width', v_width,
        'area', v_area,
        'is_active', v_is_active,
        'server_version', v_version,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'carpet_size', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'carpet_size', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_carpet_size(
    p_op_id TEXT,
    p_carpet_size_id TEXT,
    p_carpet_size JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_existing carpet_sizes%ROWTYPE;
    v_name TEXT;
    v_length NUMERIC;
    v_width NUMERIC;
    v_area NUMERIC;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := p_carpet_size_id::UUID;
    SELECT * INTO v_existing FROM carpet_sizes WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Carpet size % not found', p_carpet_size_id USING ERRCODE = 'P0002';
    END IF;

    IF p_carpet_size ? 'base_version' AND (p_carpet_size->>'base_version') IS NOT NULL THEN
        v_base_version := (p_carpet_size->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for carpet_size %',
                v_base_version, v_existing.server_version, p_carpet_size_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    v_name := COALESCE(p_carpet_size->>'name', v_existing.name);

    IF p_carpet_size ? 'length' THEN
        v_length := (p_carpet_size->>'length')::NUMERIC;
        IF v_length <= 0 THEN
            RAISE EXCEPTION 'Length must be greater than zero' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_length := v_existing.length;
    END IF;

    IF p_carpet_size ? 'width' THEN
        v_width := (p_carpet_size->>'width')::NUMERIC;
        IF v_width <= 0 THEN
            RAISE EXCEPTION 'Width must be greater than zero' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_width := v_existing.width;
    END IF;

    IF p_carpet_size ? 'area' THEN
        v_area := (p_carpet_size->>'area')::NUMERIC;
        IF v_area <= 0 THEN
            RAISE EXCEPTION 'Area must be greater than zero' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_area := v_existing.area;
    END IF;

    IF EXISTS (
        SELECT 1 FROM carpet_sizes
        WHERE length = v_length AND width = v_width AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Carpet size with dimensions %x% already exists', v_length, v_width USING ERRCODE = '23505';
    END IF;

    IF p_carpet_size ? 'is_active' THEN
        v_is_active := (p_carpet_size->>'is_active')::BOOLEAN;
    ELSIF p_carpet_size ? 'isActive' THEN
        v_is_active := (p_carpet_size->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_carpet_size->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    UPDATE carpet_sizes
    SET name = v_name,
        length = v_length,
        width = v_width,
        area = v_area,
        is_active = v_is_active,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'length', v_length,
        'width', v_width,
        'area', v_area,
        'is_active', v_is_active,
        'server_version', v_new_version,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'carpet_size', v_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'carpet_size', v_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_create_storage_location(
    p_op_id TEXT,
    p_location JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_item_type_ids TEXT[];
    v_item_type_id TEXT;
    v_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_location->>'id')::UUID;
    v_name := trim(p_location->>'name');
    v_is_active := COALESCE((p_location->>'is_active')::BOOLEAN, (p_location->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_location->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_location->>'updated_at')::TIMESTAMPTZ, now());

    IF v_name IS NULL OR v_name = '' THEN
        RAISE EXCEPTION 'Storage location name is required' USING ERRCODE = '23502';
    END IF;

    IF EXISTS (SELECT 1 FROM storage_locations WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id) THEN
        RAISE EXCEPTION 'Storage location with name "%" already exists', v_name USING ERRCODE = '23505';
    END IF;

    INSERT INTO storage_locations (id, name, is_active, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_is_active, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        server_version = storage_locations.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    IF p_location ? 'supported_item_type_ids' OR p_location ? 'supportedItemTypeIds' THEN
        DELETE FROM storage_location_item_types WHERE storage_location_id = v_id;
        v_item_type_ids := ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_location->'supported_item_type_ids', p_location->'supportedItemTypeIds')));
        FOREACH v_item_type_id IN ARRAY v_item_type_ids LOOP
            INSERT INTO storage_location_item_types (storage_location_id, item_type_id, created_at)
            VALUES (v_id, v_item_type_id::UUID, now())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    SELECT COALESCE(jsonb_agg(item_type_id::TEXT), '[]'::JSONB)
    INTO v_supported_ids
    FROM storage_location_item_types
    WHERE storage_location_id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_version,
        'supported_item_type_ids', v_supported_ids,
        'supportedItemTypeIds', v_supported_ids,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'storage_location', v_id::TEXT, 'create', v_result, v_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'storage_location', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_storage_location(
    p_op_id TEXT,
    p_location_id TEXT,
    p_location JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_existing storage_locations%ROWTYPE;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_item_type_ids TEXT[];
    v_item_type_id TEXT;
    v_supported_ids JSONB;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := p_location_id::UUID;
    SELECT * INTO v_existing FROM storage_locations WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Storage location % not found', p_location_id USING ERRCODE = 'P0002';
    END IF;

    IF p_location ? 'base_version' AND (p_location->>'base_version') IS NOT NULL THEN
        v_base_version := (p_location->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for storage_location %',
                v_base_version, v_existing.server_version, p_location_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    v_name := COALESCE(trim(p_location->>'name'), v_existing.name);
    IF p_location ? 'is_active' THEN
        v_is_active := (p_location->>'is_active')::BOOLEAN;
    ELSIF p_location ? 'isActive' THEN
        v_is_active := (p_location->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_location->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    UPDATE storage_locations
    SET name = v_name,
        is_active = v_is_active,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = v_id;

    IF p_location ? 'supported_item_type_ids' OR p_location ? 'supportedItemTypeIds' THEN
        DELETE FROM storage_location_item_types WHERE storage_location_id = v_id;
        v_item_type_ids := ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_location->'supported_item_type_ids', p_location->'supportedItemTypeIds')));
        FOREACH v_item_type_id IN ARRAY v_item_type_ids LOOP
            INSERT INTO storage_location_item_types (storage_location_id, item_type_id, created_at)
            VALUES (v_id, v_item_type_id::UUID, now())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    SELECT COALESCE(jsonb_agg(item_type_id::TEXT), '[]'::JSONB)
    INTO v_supported_ids
    FROM storage_location_item_types
    WHERE storage_location_id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'server_version', v_new_version,
        'supported_item_type_ids', v_supported_ids,
        'supportedItemTypeIds', v_supported_ids,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'storage_location', v_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'storage_location', v_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_update_business_settings(
    p_op_id TEXT,
    p_settings JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id TEXT;
    v_existing business_settings%ROWTYPE;
    v_name TEXT;
    v_address TEXT;
    v_phone TEXT;
    v_logo TEXT;
    v_footer TEXT;
    v_tax_enabled BOOLEAN;
    v_tax_rate DOUBLE PRECISION;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- Singleton row lookup
    SELECT * INTO v_existing FROM business_settings LIMIT 1 FOR UPDATE;

    IF FOUND THEN
        v_id := v_existing.id;
        IF p_settings ? 'base_version' AND (p_settings->>'base_version') IS NOT NULL THEN
            v_base_version := (p_settings->>'base_version')::INTEGER;
            IF v_base_version <> v_existing.server_version THEN
                RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for business_settings',
                    v_base_version, v_existing.server_version USING ERRCODE = 'P0004';
            END IF;
        END IF;
        v_new_version := v_existing.server_version + 1;
    ELSE
        v_id := COALESCE(p_settings->>'id', '00000000-0000-0000-0000-000000000001');
        v_new_version := 1;
    END IF;

    v_name := COALESCE(p_settings->>'business_name', p_settings->>'businessName', v_existing.business_name, 'مغسلة الأمل');
    v_address := COALESCE(p_settings->>'address', v_existing.address);
    v_phone := COALESCE(p_settings->>'phone', v_existing.phone);
    v_logo := COALESCE(p_settings->>'logo_reference', p_settings->>'logoReference', v_existing.logo_reference);
    v_footer := COALESCE(p_settings->>'invoice_footer_text', p_settings->>'invoiceFooterText', v_existing.invoice_footer_text);
    v_tax_enabled := COALESCE((p_settings->>'tax_enabled')::BOOLEAN, (p_settings->>'taxEnabled')::BOOLEAN, v_existing.tax_enabled, false);
    v_tax_rate := COALESCE((p_settings->>'tax_rate')::DOUBLE PRECISION, (p_settings->>'taxRate')::DOUBLE PRECISION, v_existing.tax_rate, 0.0);
    v_updated_at := COALESCE((p_settings->>'updated_at')::TIMESTAMPTZ, now());

    IF v_tax_rate < 0.0 THEN
        RAISE EXCEPTION 'Tax rate must be non-negative' USING ERRCODE = '23514';
    END IF;

    IF FOUND THEN
        UPDATE business_settings
        SET business_name = v_name,
            address = v_address,
            phone = v_phone,
            logo_reference = v_logo,
            invoice_footer_text = v_footer,
            tax_enabled = v_tax_enabled,
            tax_rate = v_tax_rate,
            server_version = v_new_version,
            updated_at = v_updated_at
        WHERE id = v_id;
    ELSE
        INSERT INTO business_settings (
            id, business_name, address, phone, logo_reference, invoice_footer_text,
            tax_enabled, tax_rate, server_version, created_at, updated_at
        ) VALUES (
            v_id, v_name, v_address, v_phone, v_logo, v_footer,
            v_tax_enabled, v_tax_rate, 1, now(), v_updated_at
        );
    END IF;

    v_result := jsonb_build_object(
        'id', v_id,
        'business_name', v_name,
        'address', v_address,
        'phone', v_phone,
        'logo_reference', v_logo,
        'invoice_footer_text', v_footer,
        'tax_enabled', v_tax_enabled,
        'tax_rate', v_tax_rate,
        'server_version', v_new_version,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'business_settings', v_id, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'business_settings', v_id, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
