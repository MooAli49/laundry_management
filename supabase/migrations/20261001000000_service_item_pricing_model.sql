-- Migration: 20261001000000_service_item_pricing_model.sql
-- Description: Migrate pricing from services to service_item_types (Service + Item Type Pricing Model).
-- Removes fixed_price, services.price, and services.pricing_type.
-- Enforces per_piece and per_square_meter pricing on service_item_types with price > 0.

-- -----------------------------------------------------------------------------
-- 1. Upgrade service_item_types table structure
-- -----------------------------------------------------------------------------

ALTER TABLE service_item_types
    ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid(),
    ADD COLUMN IF NOT EXISTS pricing_type TEXT,
    ADD COLUMN IF NOT EXISTS price BIGINT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Backfill existing service_item_types from services if columns are not yet populated
UPDATE service_item_types sit
SET
    pricing_type = CASE
        WHEN s.pricing_type = 'fixed_price' THEN 'per_piece'
        ELSE s.pricing_type
    END,
    price = s.price,
    updated_at = COALESCE(s.updated_at, now())
FROM services s
WHERE sit.service_id = s.id
  AND (sit.pricing_type IS NULL OR sit.price IS NULL);

-- Clean pre-production invalid/incomplete legacy rows (do not invent fake prices)
DELETE FROM service_item_types
WHERE price IS NULL OR price <= 0 OR pricing_type IS NULL OR pricing_type NOT IN ('per_piece', 'per_square_meter');

-- Ensure UUIDs are set
UPDATE service_item_types SET id = gen_random_uuid() WHERE id IS NULL;

-- Enforce NOT NULL constraints
ALTER TABLE service_item_types
    ALTER COLUMN id SET NOT NULL,
    ALTER COLUMN pricing_type SET NOT NULL,
    ALTER COLUMN price SET NOT NULL,
    ALTER COLUMN updated_at SET NOT NULL;

-- Set Primary Key and Unique constraint
ALTER TABLE service_item_types DROP CONSTRAINT IF EXISTS service_item_types_pkey;
ALTER TABLE service_item_types ADD PRIMARY KEY (id);

ALTER TABLE service_item_types DROP CONSTRAINT IF EXISTS uq_service_item_types_service_item;
ALTER TABLE service_item_types ADD CONSTRAINT uq_service_item_types_service_item UNIQUE (service_id, item_type_id);

-- Enforce check constraints
ALTER TABLE service_item_types DROP CONSTRAINT IF EXISTS service_item_types_pricing_type_check;
ALTER TABLE service_item_types ADD CONSTRAINT service_item_types_pricing_type_check
    CHECK (pricing_type IN ('per_piece', 'per_square_meter'));

ALTER TABLE service_item_types DROP CONSTRAINT IF EXISTS service_item_types_price_check;
ALTER TABLE service_item_types ADD CONSTRAINT service_item_types_price_check
    CHECK (price > 0);

-- Supporting index
CREATE INDEX IF NOT EXISTS idx_supabase_service_item_types_service ON service_item_types(service_id);

-- -----------------------------------------------------------------------------
-- 2. Clean services table (remove price and pricing_type)
-- -----------------------------------------------------------------------------

ALTER TABLE services DROP COLUMN IF EXISTS price;
ALTER TABLE services DROP COLUMN IF EXISTS pricing_type;

-- -----------------------------------------------------------------------------
-- 3. Update order_items constraints to exclude fixed_price
-- -----------------------------------------------------------------------------

UPDATE order_items SET pricing_type = 'per_piece' WHERE pricing_type = 'fixed_price';

ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_pricing_type_check;
ALTER TABLE order_items ADD CONSTRAINT order_items_pricing_type_check
    CHECK (pricing_type IN ('per_piece', 'per_square_meter'));

-- -----------------------------------------------------------------------------
-- 4. Replace sync RPC functions for Service management
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.sync_create_service(text, jsonb, text[]);
DROP FUNCTION IF EXISTS public.sync_update_service(text, uuid, jsonb, text[]);

CREATE OR REPLACE FUNCTION public.sync_create_service(
    p_op_id text,
    p_service jsonb,
    p_service_item_types jsonb DEFAULT NULL::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_description TEXT;
    v_is_active BOOLEAN;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_version INTEGER;
    v_raw_items JSONB;
    v_item JSONB;
    v_item_id UUID;
    v_item_type_id UUID;
    v_pricing_type TEXT;
    v_price BIGINT;
    v_sit_results JSONB := '[]'::jsonb;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_id := (p_service->>'id')::UUID;
    v_name := trim(p_service->>'name');
    IF v_name IS NULL OR v_name = '' THEN
        RAISE EXCEPTION 'Service name cannot be empty' USING ERRCODE = '23514';
    END IF;

    v_description := p_service->>'description';

    IF p_service ? 'is_active' THEN
        v_is_active := (p_service->>'is_active')::BOOLEAN;
    ELSIF p_service ? 'isActive' THEN
        v_is_active := (p_service->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := true;
    END IF;

    v_created_at := COALESCE((p_service->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_service->>'updated_at')::TIMESTAMPTZ, now());

    IF EXISTS (SELECT 1 FROM services WHERE name = v_name AND id <> v_id) THEN
        RAISE EXCEPTION 'Service with name "%" already exists', v_name USING ERRCODE = '23505';
    END IF;

    INSERT INTO services (id, name, description, is_active, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_description, v_is_active, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        is_active = EXCLUDED.is_active,
        server_version = services.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_raw_items := COALESCE(p_service_item_types, p_service->'service_item_types');

    IF v_raw_items IS NOT NULL AND jsonb_typeof(v_raw_items) = 'array' THEN
        DELETE FROM service_item_types WHERE service_id = v_id;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_raw_items) LOOP
            v_item_id := COALESCE((v_item->>'id')::UUID, gen_random_uuid());
            v_item_type_id := (v_item->>'item_type_id')::UUID;
            v_pricing_type := v_item->>'pricing_type';
            v_price := (v_item->>'price')::BIGINT;

            IF v_pricing_type NOT IN ('per_piece', 'per_square_meter') THEN
                RAISE EXCEPTION 'Invalid pricing type: %. Must be per_piece or per_square_meter', v_pricing_type USING ERRCODE = '23514';
            END IF;

            IF v_price <= 0 THEN
                RAISE EXCEPTION 'Price must be greater than zero' USING ERRCODE = '23514';
            END IF;

            IF NOT EXISTS (SELECT 1 FROM item_types WHERE id = v_item_type_id) THEN
                RAISE EXCEPTION 'Item type % does not exist', v_item_type_id USING ERRCODE = '23503';
            END IF;

            INSERT INTO service_item_types (id, service_id, item_type_id, pricing_type, price, created_at, updated_at)
            VALUES (v_item_id, v_id, v_item_type_id, v_pricing_type, v_price, now(), now())
            ON CONFLICT (service_id, item_type_id) DO UPDATE SET
                pricing_type = EXCLUDED.pricing_type,
                price = EXCLUDED.price,
                updated_at = EXCLUDED.updated_at;

            v_sit_results := v_sit_results || jsonb_build_object(
                'id', v_item_id,
                'service_id', v_id,
                'item_type_id', v_item_type_id,
                'pricing_type', v_pricing_type,
                'price', v_price
            );
        END LOOP;
    END IF;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'description', v_description,
        'is_active', v_is_active,
        'server_version', v_version,
        'service_item_types', v_sit_results,
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

CREATE OR REPLACE FUNCTION public.sync_update_service(
    p_op_id text,
    p_service_id uuid,
    p_service jsonb,
    p_service_item_types jsonb DEFAULT NULL::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_cached JSONB;
    v_existing services%ROWTYPE;
    v_name TEXT;
    v_description TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_raw_items JSONB;
    v_item JSONB;
    v_item_id UUID;
    v_item_type_id UUID;
    v_pricing_type TEXT;
    v_price BIGINT;
    v_sit_results JSONB := '[]'::jsonb;
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
    IF v_name IS NOT NULL AND trim(v_name) = '' THEN
        RAISE EXCEPTION 'Service name cannot be empty' USING ERRCODE = '23514';
    END IF;

    IF p_service ? 'description' THEN
        v_description := p_service->>'description';
    ELSE
        v_description := v_existing.description;
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
        is_active = v_is_active,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = p_service_id;

    v_raw_items := COALESCE(p_service_item_types, p_service->'service_item_types');

    IF v_raw_items IS NOT NULL AND jsonb_typeof(v_raw_items) = 'array' THEN
        DELETE FROM service_item_types WHERE service_id = p_service_id;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_raw_items) LOOP
            v_item_id := COALESCE((v_item->>'id')::UUID, gen_random_uuid());
            v_item_type_id := (v_item->>'item_type_id')::UUID;
            v_pricing_type := v_item->>'pricing_type';
            v_price := (v_item->>'price')::BIGINT;

            IF v_pricing_type NOT IN ('per_piece', 'per_square_meter') THEN
                RAISE EXCEPTION 'Invalid pricing type: %. Must be per_piece or per_square_meter', v_pricing_type USING ERRCODE = '23514';
            END IF;

            IF v_price <= 0 THEN
                RAISE EXCEPTION 'Price must be greater than zero' USING ERRCODE = '23514';
            END IF;

            IF NOT EXISTS (SELECT 1 FROM item_types WHERE id = v_item_type_id) THEN
                RAISE EXCEPTION 'Item type % does not exist', v_item_type_id USING ERRCODE = '23503';
            END IF;

            INSERT INTO service_item_types (id, service_id, item_type_id, pricing_type, price, created_at, updated_at)
            VALUES (v_item_id, p_service_id, v_item_type_id, v_pricing_type, v_price, now(), now())
            ON CONFLICT (service_id, item_type_id) DO UPDATE SET
                pricing_type = EXCLUDED.pricing_type,
                price = EXCLUDED.price,
                updated_at = EXCLUDED.updated_at;

            v_sit_results := v_sit_results || jsonb_build_object(
                'id', v_item_id,
                'service_id', p_service_id,
                'item_type_id', v_item_type_id,
                'pricing_type', v_pricing_type,
                'price', v_price
            );
        END LOOP;
    ELSE
        -- Select existing service_item_types for result payload
        SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'id', id,
            'service_id', service_id,
            'item_type_id', item_type_id,
            'pricing_type', pricing_type,
            'price', price
        )), '[]'::jsonb) INTO v_sit_results
        FROM service_item_types
        WHERE service_id = p_service_id;
    END IF;

    v_result := jsonb_build_object(
        'id', p_service_id,
        'name', v_name,
        'description', v_description,
        'is_active', v_is_active,
        'server_version', v_new_version,
        'service_item_types', v_sit_results,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'service', p_service_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'service', p_service_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 5. Update sync_create_order_aggregate to validate against service_item_types
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_create_order_aggregate(p_op_id text, p_order jsonb, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_cached JSONB;
    v_order_id UUID;
    v_customer_id UUID;
    v_status TEXT;
    v_total_amount BIGINT;
    v_paid_amount BIGINT;
    v_order_number TEXT;
    v_item JSONB;
    v_item_id UUID;
    v_service_id UUID;
    v_item_type_id UUID;
    v_item_pricing_type TEXT;
    v_sit_pricing_type TEXT;
    v_carpet JSONB;
    v_carpet_id UUID;
    v_items_result JSONB := '[]'::jsonb;
    v_item_obj JSONB;
    v_result JSONB;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    v_order_id := (p_order->>'id')::UUID;
    v_customer_id := (p_order->>'customer_id')::UUID;
    v_status := p_order->>'status';
    v_total_amount := (p_order->>'total_amount')::BIGINT;
    v_paid_amount := (p_order->>'paid_amount')::BIGINT;
    v_order_number := p_order->>'order_number';

    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = v_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', v_customer_id USING ERRCODE = '23503';
    END IF;

    IF v_status NOT IN ('pending', 'processing', 'completed', 'delivered', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid order status: %', v_status USING ERRCODE = '23514';
    END IF;

    IF v_total_amount < 0 THEN
        RAISE EXCEPTION 'Total amount must be non-negative' USING ERRCODE = '23514';
    END IF;

    IF v_paid_amount < 0 OR v_paid_amount > v_total_amount THEN
        RAISE EXCEPTION 'Paid amount must be between 0 and total_amount' USING ERRCODE = '23514';
    END IF;

    INSERT INTO orders (
        id, order_number, customer_id, customer_name_snapshot, customer_phone_snapshot,
        status, total_amount, paid_amount, notes, server_version,
        created_at, updated_at
    ) VALUES (
        v_order_id,
        v_order_number,
        v_customer_id,
        COALESCE(p_order->>'customer_name_snapshot', ''),
        COALESCE(p_order->>'customer_phone_snapshot', ''),
        v_status,
        v_total_amount,
        v_paid_amount,
        p_order->>'notes',
        1,
        COALESCE((p_order->>'created_at')::TIMESTAMPTZ, now()),
        COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
    );

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        v_service_id := (v_item->>'service_id')::UUID;
        v_item_type_id := (v_item->>'item_type_id')::UUID;
        v_item_pricing_type := v_item->>'pricing_type';

        IF NOT EXISTS (SELECT 1 FROM services WHERE id = v_service_id) THEN
            RAISE EXCEPTION 'Service % does not exist', v_service_id USING ERRCODE = '23503';
        END IF;

        IF v_item_pricing_type NOT IN ('per_piece', 'per_square_meter') THEN
            RAISE EXCEPTION 'Invalid order item pricing type: %', v_item_pricing_type USING ERRCODE = '23514';
        END IF;

        -- Verify compatibility & pricing_type with service_item_types
        SELECT pricing_type INTO v_sit_pricing_type
        FROM service_item_types
        WHERE service_id = v_service_id AND item_type_id = v_item_type_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: service % is not compatible with item_type %', v_service_id, v_item_type_id USING ERRCODE = '23514';
        END IF;

        IF v_item_pricing_type <> v_sit_pricing_type THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: item pricing_type % does not match configured pricing_type %', v_item_pricing_type, v_sit_pricing_type USING ERRCODE = '23514';
        END IF;

        INSERT INTO order_items (
            id, order_id, item_type_id, item_definition_id, service_id,
            item_type_name_snapshot, item_definition_name_snapshot, service_name_snapshot,
            pricing_type, quantity, unit_price, calculated_total, notes,
            created_at, updated_at
        ) VALUES (
            v_item_id,
            v_order_id,
            v_item_type_id,
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

        v_items_result := v_items_result || jsonb_build_array(v_item_obj);
    END LOOP;

    v_result := jsonb_build_object(
        'order', jsonb_build_object(
            'id', v_order_id,
            'order_number', v_order_number,
            'customer_id', v_customer_id,
            'status', v_status,
            'total_amount', v_total_amount,
            'paid_amount', v_paid_amount,
            'server_version', 1,
            'created_at', COALESCE((p_order->>'created_at')::TIMESTAMPTZ, now()),
            'updated_at', COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
        ),
        'items', v_items_result
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', v_result, 1, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', v_order_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 6. Update sync_update_order_aggregate to validate against service_item_types
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_update_order_aggregate(p_op_id text, p_order_id uuid, p_order jsonb, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_cached JSONB;
    v_existing_order orders%ROWTYPE;
    v_existing_item order_items%ROWTYPE;
    v_new_version INTEGER;
    v_base_version INTEGER;
    v_item JSONB;
    v_item_id UUID;
    v_item_action TEXT;
    v_item_type_id UUID;
    v_service_id UUID;
    v_item_def_id UUID;
    v_unit_price BIGINT;
    v_quantity DOUBLE PRECISION;
    v_item_pricing_type TEXT;
    v_item_type_name TEXT;
    v_service_name TEXT;
    v_sit_pricing_type TEXT;
    v_def_name TEXT;
    v_def_item_type_id UUID;
    v_incoming_item_ids UUID[] := '{}';
    v_carpet JSONB;
    v_carpet_id UUID;
    v_length DOUBLE PRECISION;
    v_width DOUBLE PRECISION;
    v_recalculated_total BIGINT := 0;
    v_provided_total BIGINT;
    v_item_count INTEGER := 0;
    v_result JSONB;
    v_items_result JSONB := '[]'::jsonb;
    v_item_obj JSONB;
    v_carpet_obj JSONB;
    v_is_new_or_changed BOOLEAN;
BEGIN
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    SELECT * INTO v_existing_order FROM orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id USING ERRCODE = 'P0002';
    END IF;

    IF v_existing_order.status <> 'processing' THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Only orders in processing status can be edited (current status: %)',
            v_existing_order.status USING ERRCODE = '23514';
    END IF;

    IF p_order ? 'base_version' AND (p_order->>'base_version') IS NOT NULL THEN
        v_base_version := (p_order->>'base_version')::INTEGER;
        IF v_base_version <> v_existing_order.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for order %',
                v_base_version, v_existing_order.server_version, p_order_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Order must contain at least one item' USING ERRCODE = '23514';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_action := COALESCE(v_item->>'_action', 'keep');
        IF v_item_action <> 'delete' THEN
            v_item_count := v_item_count + 1;
        END IF;
    END LOOP;

    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Order must contain at least one item' USING ERRCODE = '23514';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        v_item_action := COALESCE(v_item->>'_action', 'keep');

        IF v_item_action = 'delete' THEN
            SELECT * INTO v_existing_item FROM order_items WHERE id = v_item_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Order item % does not exist', v_item_id USING ERRCODE = '23503';
            END IF;

            IF EXISTS (SELECT 1 FROM storage_records WHERE order_item_id = v_item_id AND is_active = true) THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Item % is currently checked into storage and cannot be deleted', v_item_id USING ERRCODE = '23514';
            END IF;

            CONTINUE;
        END IF;

        v_incoming_item_ids := array_append(v_incoming_item_ids, v_item_id);
        v_item_type_id := (v_item->>'item_type_id')::UUID;
        v_service_id := (v_item->>'service_id')::UUID;
        v_unit_price := (v_item->>'unit_price')::BIGINT;
        v_quantity := (v_item->>'quantity')::DOUBLE PRECISION;
        v_item_pricing_type := v_item->>'pricing_type';

        IF v_unit_price <= 0 THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: unit_price must be greater than zero' USING ERRCODE = '23514';
        END IF;

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: quantity must be greater than zero' USING ERRCODE = '23514';
        END IF;

        IF v_item_pricing_type NOT IN ('per_piece', 'per_square_meter') THEN
            RAISE EXCEPTION 'Invalid order item pricing type: %', v_item_pricing_type USING ERRCODE = '23514';
        END IF;

        SELECT * INTO v_existing_item FROM order_items WHERE id = v_item_id;
        v_is_new_or_changed := NOT FOUND OR (v_existing_item.service_id <> v_service_id OR v_existing_item.item_type_id <> v_item_type_id);

        IF FOUND THEN
            IF EXISTS (SELECT 1 FROM storage_records WHERE order_item_id = v_item_id AND is_active = true) THEN
                IF v_existing_item.item_type_id <> v_item_type_id OR
                   v_existing_item.service_id <> v_service_id OR
                   v_existing_item.pricing_type <> v_item_pricing_type OR
                   v_existing_item.unit_price <> v_unit_price THEN
                    RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Item % is currently in storage; identity, service, and pricing cannot be modified', v_item_id USING ERRCODE = '23514';
                END IF;
            END IF;
        END IF;

        IF v_is_new_or_changed THEN
            SELECT name INTO v_item_type_name FROM item_types WHERE id = v_item_type_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Invalid item_type_id %', v_item_type_id USING ERRCODE = '23514';
            END IF;

            SELECT name INTO v_service_name FROM services WHERE id = v_service_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Service % does not exist', v_service_id USING ERRCODE = '23503';
            END IF;

            SELECT pricing_type INTO v_sit_pricing_type
            FROM service_item_types
            WHERE service_id = v_service_id AND item_type_id = v_item_type_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: service % is not compatible with item_type %', v_service_id, v_item_type_id USING ERRCODE = '23514';
            END IF;

            IF v_item_pricing_type <> v_sit_pricing_type THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: item pricing_type % does not match configured pricing_type %', v_item_pricing_type, v_sit_pricing_type USING ERRCODE = '23514';
            END IF;
        ELSE
            SELECT name INTO v_item_type_name FROM item_types WHERE id = v_item_type_id;
            IF NOT FOUND THEN
                v_item_type_name := v_existing_item.item_type_name_snapshot;
            END IF;

            SELECT name INTO v_service_name FROM services WHERE id = v_service_id;
            IF NOT FOUND THEN
                v_service_name := v_existing_item.service_name_snapshot;
            END IF;
        END IF;

        IF v_item ? 'item_definition_id' AND v_item->>'item_definition_id' IS NOT NULL AND v_item->>'item_definition_id' <> '' THEN
            v_item_def_id := (v_item->>'item_definition_id')::UUID;
            SELECT name, item_type_id INTO v_def_name, v_def_item_type_id FROM item_definitions WHERE id = v_item_def_id;
            IF NOT FOUND THEN
                IF NOT v_is_new_or_changed AND v_existing_item.item_definition_id = v_item_def_id THEN
                    v_def_name := v_existing_item.item_definition_name_snapshot;
                ELSE
                    RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: item_definition % does not exist', v_item_def_id USING ERRCODE = '23514';
                END IF;
            ELSE
                IF v_def_item_type_id <> v_item_type_id THEN
                    RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: item_definition % does not match item_type %', v_item_def_id, v_item_type_id USING ERRCODE = '23514';
                END IF;
            END IF;
        ELSE
            v_item_def_id := NULL;
            v_def_name := NULL;
        END IF;

        IF v_item_pricing_type = 'per_square_meter' THEN
            IF NOT (v_item ? 'carpet_data') OR (v_item->'carpet_data') IS NULL OR (v_item->'carpet_data') = 'null'::jsonb THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: carpet_data required for per_square_meter' USING ERRCODE = '23514';
            END IF;
            v_carpet := v_item->'carpet_data';
            v_length := (v_carpet->>'length')::DOUBLE PRECISION;
            v_width := (v_carpet->>'width')::DOUBLE PRECISION;
            IF v_length <= 0 OR v_width <= 0 THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Carpet dimensions must be positive' USING ERRCODE = '23514';
            END IF;
        ELSE
            IF v_item ? 'carpet_data' AND (v_item->'carpet_data') IS NOT NULL AND (v_item->'carpet_data') <> 'null'::jsonb THEN
                RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: carpet_data not allowed for non-carpet items' USING ERRCODE = '23514';
            END IF;
        END IF;

        v_recalculated_total := v_recalculated_total + (v_item->>'calculated_total')::BIGINT;
    END LOOP;

    v_provided_total := (p_order->>'total_amount')::BIGINT;
    IF v_provided_total IS NOT NULL AND v_provided_total <> v_recalculated_total THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: Provided total_amount % does not match items sum %',
            v_provided_total, v_recalculated_total USING ERRCODE = '23514';
    END IF;

    IF v_existing_order.paid_amount > v_recalculated_total THEN
        RAISE EXCEPTION 'BUSINESS_RULE_VIOLATION: paid_amount % exceeds new total_amount %',
            v_existing_order.paid_amount, v_recalculated_total USING ERRCODE = '23514';
    END IF;

    v_new_version := v_existing_order.server_version + 1;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := (v_item->>'id')::UUID;
        v_item_action := COALESCE(v_item->>'_action', 'keep');

        IF v_item_action = 'delete' THEN
            DELETE FROM order_item_carpets WHERE order_item_id = v_item_id;
            DELETE FROM order_items WHERE id = v_item_id;
            CONTINUE;
        END IF;

        v_item_type_id := (v_item->>'item_type_id')::UUID;
        v_service_id := (v_item->>'service_id')::UUID;
        v_item_pricing_type := v_item->>'pricing_type';
        SELECT name INTO v_item_type_name FROM item_types WHERE id = v_item_type_id;
        SELECT name INTO v_service_name FROM services WHERE id = v_service_id;

        IF v_item ? 'item_definition_id' AND v_item->>'item_definition_id' IS NOT NULL AND v_item->>'item_definition_id' <> '' THEN
            v_item_def_id := (v_item->>'item_definition_id')::UUID;
            SELECT name INTO v_def_name FROM item_definitions WHERE id = v_item_def_id;
        ELSE
            v_item_def_id := NULL;
            v_def_name := NULL;
        END IF;

        INSERT INTO order_items (
            id, order_id, item_type_id, item_definition_id, service_id,
            item_type_name_snapshot, item_definition_name_snapshot, service_name_snapshot,
            pricing_type, quantity, unit_price, calculated_total, notes,
            created_at, updated_at
        ) VALUES (
            v_item_id,
            p_order_id,
            v_item_type_id,
            v_item_def_id,
            v_service_id,
            COALESCE(v_item->>'item_type_name_snapshot', v_item_type_name),
            COALESCE(v_item->>'item_definition_name_snapshot', v_def_name),
            COALESCE(v_item->>'service_name_snapshot', v_service_name),
            v_item_pricing_type,
            (v_item->>'quantity')::DOUBLE PRECISION,
            (v_item->>'unit_price')::BIGINT,
            (v_item->>'calculated_total')::BIGINT,
            v_item->>'notes',
            COALESCE((v_item->>'created_at')::TIMESTAMPTZ, now()),
            COALESCE((v_item->>'updated_at')::TIMESTAMPTZ, now())
        )
        ON CONFLICT (id) DO UPDATE SET
            item_type_id = EXCLUDED.item_type_id,
            item_definition_id = EXCLUDED.item_definition_id,
            service_id = EXCLUDED.service_id,
            item_type_name_snapshot = EXCLUDED.item_type_name_snapshot,
            item_definition_name_snapshot = EXCLUDED.item_definition_name_snapshot,
            service_name_snapshot = EXCLUDED.service_name_snapshot,
            pricing_type = EXCLUDED.pricing_type,
            quantity = EXCLUDED.quantity,
            unit_price = EXCLUDED.unit_price,
            calculated_total = EXCLUDED.calculated_total,
            notes = EXCLUDED.notes,
            updated_at = EXCLUDED.updated_at;

        IF v_item ? 'carpet_data' AND (v_item->'carpet_data') IS NOT NULL AND (v_item->'carpet_data') <> 'null'::jsonb THEN
            v_carpet := v_item->'carpet_data';
            v_carpet_id := COALESCE((v_carpet->>'id')::UUID, gen_random_uuid());
            v_length := (v_carpet->>'length')::DOUBLE PRECISION;
            v_width := (v_carpet->>'width')::DOUBLE PRECISION;

            INSERT INTO order_item_carpets (
                id, order_item_id, carpet_size_id, length, width, area, created_at, updated_at
            ) VALUES (
                v_carpet_id,
                v_item_id,
                (v_carpet->>'carpet_size_id')::UUID,
                v_length,
                v_width,
                round((v_length * v_width)::numeric, 4),
                COALESCE((v_carpet->>'created_at')::TIMESTAMPTZ, now()),
                COALESCE((v_carpet->>'updated_at')::TIMESTAMPTZ, now())
            )
            ON CONFLICT (id) DO UPDATE SET
                carpet_size_id = EXCLUDED.carpet_size_id,
                length = EXCLUDED.length,
                width = EXCLUDED.width,
                area = EXCLUDED.area,
                updated_at = EXCLUDED.updated_at;
        ELSE
            DELETE FROM order_item_carpets WHERE order_item_id = v_item_id;
        END IF;

        v_item_obj := jsonb_build_object(
            'id', v_item_id,
            'order_id', p_order_id,
            'item_type_id', v_item_type_id,
            'item_definition_id', v_item_def_id,
            'service_id', v_service_id,
            'item_type_name_snapshot', COALESCE(v_item->>'item_type_name_snapshot', v_item_type_name),
            'item_definition_name_snapshot', COALESCE(v_item->>'item_definition_name_snapshot', v_def_name),
            'service_name_snapshot', COALESCE(v_item->>'service_name_snapshot', v_service_name),
            'pricing_type', v_item_pricing_type,
            'quantity', (v_item->>'quantity')::DOUBLE PRECISION,
            'unit_price', (v_item->>'unit_price')::BIGINT,
            'calculated_total', (v_item->>'calculated_total')::BIGINT,
            'notes', v_item->>'notes',
            'created_at', COALESCE((v_item->>'created_at')::TIMESTAMPTZ, now()),
            'updated_at', COALESCE((v_item->>'updated_at')::TIMESTAMPTZ, now())
        );

        IF v_item ? 'carpet_data' AND (v_item->'carpet_data') IS NOT NULL AND (v_item->'carpet_data') <> 'null'::jsonb THEN
            v_carpet := v_item->'carpet_data';
            v_carpet_obj := jsonb_build_object(
                'id', v_carpet_id,
                'order_item_id', v_item_id,
                'carpet_size_id', (v_carpet->>'carpet_size_id')::UUID,
                'length', v_length,
                'width', v_width,
                'area', round((v_length * v_width)::numeric, 4),
                'created_at', COALESCE((v_carpet->>'created_at')::TIMESTAMPTZ, now()),
                'updated_at', COALESCE((v_carpet->>'updated_at')::TIMESTAMPTZ, now())
            );
            v_item_obj := v_item_obj || jsonb_build_object('carpet_data', v_carpet_obj);
        END IF;

        v_items_result := v_items_result || jsonb_build_array(v_item_obj);
    END LOOP;

    UPDATE orders
    SET total_amount = v_recalculated_total,
        server_version = v_new_version,
        notes = COALESCE(p_order->>'notes', notes),
        updated_at = COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
    WHERE id = p_order_id;

    v_result := jsonb_build_object(
        'order', jsonb_build_object(
            'id', p_order_id,
            'order_number', v_existing_order.order_number,
            'customer_id', v_existing_order.customer_id,
            'status', v_existing_order.status,
            'total_amount', v_recalculated_total,
            'paid_amount', v_existing_order.paid_amount,
            'notes', COALESCE(p_order->>'notes', v_existing_order.notes),
            'server_version', v_new_version,
            'created_at', v_existing_order.created_at,
            'updated_at', COALESCE((p_order->>'updated_at')::TIMESTAMPTZ, now())
        ),
        'items', v_items_result
    );

    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'update', v_result, v_new_version, now());

    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'order', p_order_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$function$;
