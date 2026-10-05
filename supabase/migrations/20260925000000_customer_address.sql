-- =============================================================================
-- Migration: 20260925000000_customer_address.sql
-- Description: Add optional address TEXT column to customers table and update
--              customer mutation RPCs (sync_create_customer, sync_update_customer)
--              to persist, normalize, and distribute address via sync_changes.
-- =============================================================================

-- 1. Schema Change: Add nullable address column
ALTER TABLE public.customers
ADD COLUMN IF NOT EXISTS address TEXT;

-- 2. Customer Create RPC with address support
CREATE OR REPLACE FUNCTION sync_create_customer(
    p_op_id TEXT,
    p_customer JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_phone TEXT;
    v_address TEXT;
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
    v_address := p_customer->>'address';
    IF v_address IS NOT NULL AND v_address ~ '^\s*$' THEN
        v_address := NULL;
    END IF;
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

    INSERT INTO customers (id, name, phone, address, notes, server_version, created_at, updated_at)
    VALUES (v_id, v_name, v_phone, v_address, v_notes, 1, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        phone = EXCLUDED.phone,
        address = EXCLUDED.address,
        notes = EXCLUDED.notes,
        server_version = customers.server_version + 1,
        updated_at = EXCLUDED.updated_at
    RETURNING server_version INTO v_version;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'phone', v_phone,
        'address', v_address,
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

-- 3. Customer Update RPC with address support
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
    v_address TEXT;
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

    IF p_customer ? 'address' THEN
        v_address := p_customer->>'address';
        IF v_address IS NOT NULL AND v_address ~ '^\s*$' THEN
            v_address := NULL;
        END IF;
    ELSE
        v_address := v_existing.address;
    END IF;

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
        address = v_address,
        notes = v_notes,
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = p_customer_id;

    v_result := jsonb_build_object(
        'id', p_customer_id,
        'name', v_name,
        'phone', v_phone,
        'address', v_address,
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
