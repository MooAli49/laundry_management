-- =============================================================================
-- Migration: 20260919000000_enforce_master_foreign_keys.sql
-- Description: Phase 3B — Enforce referential integrity for master data FKs,
--              convert legacy TEXT columns to native UUID, add supporting indexes,
--              and update RPC write paths with explicit UUID casts.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Convert Foreign Key Columns from TEXT to native UUID
-- -----------------------------------------------------------------------------

ALTER TABLE order_items
    ALTER COLUMN item_type_id TYPE UUID USING item_type_id::UUID,
    ALTER COLUMN item_definition_id TYPE UUID USING item_definition_id::UUID;

ALTER TABLE order_item_carpets
    ALTER COLUMN carpet_size_id TYPE UUID USING carpet_size_id::UUID;

ALTER TABLE storage_records
    ALTER COLUMN storage_location_id TYPE UUID USING storage_location_id::UUID;

-- Alters PK column in-place without dropping the primary key constraint
ALTER TABLE service_item_types
    ALTER COLUMN item_type_id TYPE UUID USING item_type_id::UUID;

-- -----------------------------------------------------------------------------
-- 2. Add Foreign Key Constraints
-- -----------------------------------------------------------------------------

ALTER TABLE order_items
    ADD CONSTRAINT order_items_item_type_id_fkey
    FOREIGN KEY (item_type_id) REFERENCES item_types(id) ON DELETE RESTRICT;

ALTER TABLE order_items
    ADD CONSTRAINT order_items_item_definition_id_fkey
    FOREIGN KEY (item_definition_id) REFERENCES item_definitions(id) ON DELETE SET NULL;

ALTER TABLE order_item_carpets
    ADD CONSTRAINT order_item_carpets_carpet_size_id_fkey
    FOREIGN KEY (carpet_size_id) REFERENCES carpet_sizes(id) ON DELETE SET NULL;

ALTER TABLE storage_records
    ADD CONSTRAINT storage_records_storage_location_id_fkey
    FOREIGN KEY (storage_location_id) REFERENCES storage_locations(id) ON DELETE RESTRICT;

ALTER TABLE service_item_types
    ADD CONSTRAINT service_item_types_item_type_id_fkey
    FOREIGN KEY (item_type_id) REFERENCES item_types(id) ON DELETE RESTRICT;

-- -----------------------------------------------------------------------------
-- 3. Add Supporting Performance Indexes for Foreign Keys
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_order_items_item_type_id
    ON order_items(item_type_id);

CREATE INDEX IF NOT EXISTS idx_order_items_item_definition_id
    ON order_items(item_definition_id);

CREATE INDEX IF NOT EXISTS idx_order_item_carpets_carpet_size_id
    ON order_item_carpets(carpet_size_id);

CREATE INDEX IF NOT EXISTS idx_storage_records_storage_location_id
    ON storage_records(storage_location_id);

-- -----------------------------------------------------------------------------
-- 4. Update RPC Write Paths with Explicit UUID Casts
-- -----------------------------------------------------------------------------

-- 4.1 sync_create_order_aggregate
CREATE OR REPLACE FUNCTION public.sync_create_order_aggregate(p_op_id text, p_order jsonb, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
            (v_item->>'item_type_id')::UUID,
            (v_item->>'item_definition_id')::UUID,
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
                (v_carpet->>'carpet_size_id')::UUID,
                (v_carpet->>'length')::DOUBLE PRECISION,
                (v_carpet->>'width')::DOUBLE PRECISION,
                (v_carpet->>'area')::DOUBLE PRECISION,
                COALESCE((v_carpet->>'created_at')::TIMESTAMPTZ, now()),
                COALESCE((v_carpet->>'updated_at')::TIMESTAMPTZ, now())
            );
        END IF;

        v_items_array := v_items_array || jsonb_build_array(v_item_obj);
    END LOOP;

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

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', v_aggregate_payload, 1, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$function$;

-- 4.2 sync_create_storage_record
CREATE OR REPLACE FUNCTION public.sync_create_storage_record(p_op_id text, p_storage jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_order_item_id UUID;
    v_location_id UUID;
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
    v_location_id := (p_storage->>'storage_location_id')::UUID;
    v_is_active := COALESCE((p_storage->>'is_active')::BOOLEAN, (p_storage->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_storage->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_storage->>'updated_at')::TIMESTAMPTZ, now());

    IF NOT EXISTS (SELECT 1 FROM order_items WHERE id = v_order_item_id) THEN
        RAISE EXCEPTION 'Order item % does not exist', v_order_item_id USING ERRCODE = '23503';
    END IF;

    IF v_is_active = true THEN
        SELECT * INTO v_active
        FROM storage_records
        WHERE order_item_id = v_order_item_id AND is_active = true
        FOR UPDATE;

        IF FOUND THEN
            IF p_storage ? 'previous_storage_location_id' AND
               (p_storage->>'previous_storage_location_id') IS NOT NULL AND
               (p_storage->>'previous_storage_location_id')::UUID <> v_active.storage_location_id THEN
                RAISE EXCEPTION 'CONCURRENCY_CONFLICT: Item % is at location %, not expected %',
                    v_order_item_id, v_active.storage_location_id, (p_storage->>'previous_storage_location_id') USING ERRCODE = 'P0004';
            END IF;

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
$function$;

-- 4.3 sync_update_storage_record
CREATE OR REPLACE FUNCTION public.sync_update_storage_record(p_op_id text, p_record_id uuid, p_storage jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_cached JSONB;
    v_existing storage_records%ROWTYPE;
    v_active storage_records%ROWTYPE;
    v_order_item_id UUID;
    v_location_id UUID;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing FROM storage_records WHERE id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        IF p_storage ? 'order_item_id' AND (p_storage->>'order_item_id') IS NOT NULL THEN
            v_order_item_id := (p_storage->>'order_item_id')::UUID;
            v_location_id := (p_storage->>'storage_location_id')::UUID;
            v_is_active := COALESCE((p_storage->>'is_active')::BOOLEAN, (p_storage->>'isActive')::BOOLEAN, true);

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
               (p_storage->>'previous_storage_location_id')::UUID <> v_active.storage_location_id THEN
                RAISE EXCEPTION 'CONCURRENCY_CONFLICT: Order item % is at location %, not expected %',
                    v_order_item_id, v_active.storage_location_id, (p_storage->>'previous_storage_location_id') USING ERRCODE = 'P0004';
            END IF;

            UPDATE storage_records
            SET is_active = false, updated_at = now()
            WHERE id = v_active.id;

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

    v_location_id := COALESCE((p_storage->>'storage_location_id')::UUID, v_existing.storage_location_id);
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
$function$;

-- 4.4 sync_create_service
CREATE OR REPLACE FUNCTION public.sync_create_service(p_op_id text, p_service jsonb, p_item_type_ids text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
            VALUES (v_id, v_item_type_id::UUID, now())
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
$function$;

-- 4.5 sync_update_service
CREATE OR REPLACE FUNCTION public.sync_update_service(p_op_id text, p_service_id uuid, p_service jsonb, p_item_type_ids text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
            VALUES (p_service_id, v_item_type_id::UUID, now())
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
$function$;

COMMIT;
