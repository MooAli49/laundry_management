-- =============================================================================
-- Step 12 — Supabase PostgreSQL Schema Migration
-- Laundry Management System — Master Data (Item Types, Item Definitions,
-- Carpet Sizes, Storage Locations, Business Settings), RLS & Sync RPCs
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Item Types Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS item_types (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_item_types_name_lower
ON item_types (LOWER(TRIM(name)));

-- -----------------------------------------------------------------------------
-- 2. Item Definitions Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS item_definitions (
    id UUID PRIMARY KEY,
    item_type_id UUID NOT NULL REFERENCES item_types(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_item_definitions_type_name
ON item_definitions (item_type_id, LOWER(TRIM(name)));

CREATE INDEX IF NOT EXISTS idx_item_definitions_type
ON item_definitions (item_type_id);

-- -----------------------------------------------------------------------------
-- 3. Carpet Sizes Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS carpet_sizes (
    id UUID PRIMARY KEY,
    name TEXT,
    length NUMERIC NOT NULL CHECK (length > 0),
    width NUMERIC NOT NULL CHECK (width > 0),
    area NUMERIC NOT NULL CHECK (area > 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_carpet_sizes_dimensions
ON carpet_sizes (length, width);

-- -----------------------------------------------------------------------------
-- 4. Storage Locations Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS storage_locations (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_storage_locations_name_lower
ON storage_locations (LOWER(TRIM(name)));

-- -----------------------------------------------------------------------------
-- 5. Storage Location Item Types Junction Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS storage_location_item_types (
    storage_location_id UUID NOT NULL REFERENCES storage_locations(id) ON DELETE CASCADE,
    item_type_id UUID NOT NULL REFERENCES item_types(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (storage_location_id, item_type_id)
);

CREATE INDEX IF NOT EXISTS idx_storage_loc_item_types_type
ON storage_location_item_types (item_type_id);

-- -----------------------------------------------------------------------------
-- 6. Business Settings Table (Singleton)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS business_settings (
    id TEXT PRIMARY KEY,
    business_name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    logo_reference TEXT,
    invoice_footer_text TEXT,
    tax_enabled BOOLEAN NOT NULL DEFAULT false,
    tax_rate DOUBLE PRECISION NOT NULL DEFAULT 0.0 CHECK (tax_rate >= 0.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 7. Row Level Security
-- Default-deny for direct public/client mutation.
-- Mutations and queries occur via the trusted service-role Edge Function.
-- -----------------------------------------------------------------------------
ALTER TABLE item_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE carpet_sizes ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_location_item_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_settings ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 8. RPC: sync_create_item_type
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
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_item_type IS NULL THEN
        RAISE EXCEPTION 'Item type payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_item_type->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid item type UUID: %', p_item_type->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Item type ID is required' USING ERRCODE = '23502';
    END IF;

    v_name := trim(COALESCE(p_item_type->>'name', ''));
    IF v_name = '' THEN
        RAISE EXCEPTION 'Item type name cannot be empty' USING ERRCODE = '23502';
    END IF;

    IF EXISTS (
        SELECT 1 FROM item_types
        WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Item type with name "%" already exists', v_name USING ERRCODE = '23505';
    END IF;

    v_is_active := COALESCE((p_item_type->>'is_active')::BOOLEAN, (p_item_type->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_item_type->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_item_type->>'updated_at')::TIMESTAMPTZ, now());

    INSERT INTO item_types (id, name, is_active, created_at, updated_at)
    VALUES (v_id, v_name, v_is_active, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'item_type',
        v_id::TEXT,
        'create',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 9. RPC: sync_update_item_type
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_item_type(
    p_op_id TEXT,
    p_item_type_id TEXT,
    p_item_type JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_existing RECORD;
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    BEGIN
        v_id := p_item_type_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid item type UUID: %', p_item_type_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing FROM item_types WHERE id = v_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item type not found: %', p_item_type_id USING ERRCODE = 'P0002';
    END IF;

    IF p_item_type IS NULL THEN
        RAISE EXCEPTION 'Update payload is required' USING ERRCODE = '23502';
    END IF;

    IF p_item_type ? 'name' THEN
        v_name := trim(p_item_type->>'name');
        IF v_name = '' THEN
            RAISE EXCEPTION 'Item type name cannot be empty' USING ERRCODE = '23502';
        END IF;

        IF EXISTS (
            SELECT 1 FROM item_types
            WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
        ) THEN
            RAISE EXCEPTION 'Item type with name "%" already exists', v_name USING ERRCODE = '23505';
        END IF;
    ELSE
        v_name := v_existing.name;
    END IF;

    IF p_item_type ? 'is_active' THEN
        v_is_active := (p_item_type->>'is_active')::BOOLEAN;
    ELSIF p_item_type ? 'isActive' THEN
        v_is_active := (p_item_type->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_item_type->>'updated_at')::TIMESTAMPTZ, now());

    UPDATE item_types SET
        name = v_name,
        is_active = v_is_active,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'item_type',
        v_id::TEXT,
        'update',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 10. RPC: sync_create_item_definition
-- -----------------------------------------------------------------------------
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
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_item_def IS NULL THEN
        RAISE EXCEPTION 'Item definition payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_item_def->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid item definition UUID: %', p_item_def->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Item definition ID is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_item_type_id := (COALESCE(p_item_def->>'item_type_id', p_item_def->>'itemTypeId'))::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid item_type_id UUID: %', COALESCE(p_item_def->>'item_type_id', p_item_def->>'itemTypeId') USING ERRCODE = '23514';
    END;

    IF v_item_type_id IS NULL THEN
        RAISE EXCEPTION 'item_type_id is required' USING ERRCODE = '23502';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM item_types WHERE id = v_item_type_id) THEN
        RAISE EXCEPTION 'Item type not found: %', v_item_type_id USING ERRCODE = '23503';
    END IF;

    v_name := trim(COALESCE(p_item_def->>'name', ''));
    IF v_name = '' THEN
        RAISE EXCEPTION 'Item definition name cannot be empty' USING ERRCODE = '23502';
    END IF;

    IF EXISTS (
        SELECT 1 FROM item_definitions
        WHERE item_type_id = v_item_type_id AND LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Item definition with name "%" already exists for this item type', v_name USING ERRCODE = '23505';
    END IF;

    v_is_active := COALESCE((p_item_def->>'is_active')::BOOLEAN, (p_item_def->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_item_def->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_item_def->>'updated_at')::TIMESTAMPTZ, now());

    INSERT INTO item_definitions (id, item_type_id, name, is_active, created_at, updated_at)
    VALUES (v_id, v_item_type_id, v_name, v_is_active, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        item_type_id = EXCLUDED.item_type_id,
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    v_result := jsonb_build_object(
        'id', v_id,
        'item_type_id', v_item_type_id,
        'name', v_name,
        'is_active', v_is_active,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'item_definition',
        v_id::TEXT,
        'create',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 11. RPC: sync_update_item_definition
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_item_definition(
    p_op_id TEXT,
    p_item_def_id TEXT,
    p_item_def JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_item_type_id UUID;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_existing RECORD;
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    BEGIN
        v_id := p_item_def_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid item definition UUID: %', p_item_def_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing FROM item_definitions WHERE id = v_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item definition not found: %', p_item_def_id USING ERRCODE = 'P0002';
    END IF;

    IF p_item_def IS NULL THEN
        RAISE EXCEPTION 'Update payload is required' USING ERRCODE = '23502';
    END IF;

    IF p_item_def ? 'item_type_id' OR p_item_def ? 'itemTypeId' THEN
        BEGIN
            v_item_type_id := (COALESCE(p_item_def->>'item_type_id', p_item_def->>'itemTypeId'))::UUID;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid item_type_id UUID' USING ERRCODE = '23514';
        END;

        IF NOT EXISTS (SELECT 1 FROM item_types WHERE id = v_item_type_id) THEN
            RAISE EXCEPTION 'Item type not found: %', v_item_type_id USING ERRCODE = '23503';
        END IF;
    ELSE
        v_item_type_id := v_existing.item_type_id;
    END IF;

    IF p_item_def ? 'name' THEN
        v_name := trim(p_item_def->>'name');
        IF v_name = '' THEN
            RAISE EXCEPTION 'Item definition name cannot be empty' USING ERRCODE = '23502';
        END IF;
    ELSE
        v_name := v_existing.name;
    END IF;

    IF EXISTS (
        SELECT 1 FROM item_definitions
        WHERE item_type_id = v_item_type_id AND LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Item definition with name "%" already exists for this item type', v_name USING ERRCODE = '23505';
    END IF;

    IF p_item_def ? 'is_active' THEN
        v_is_active := (p_item_def->>'is_active')::BOOLEAN;
    ELSIF p_item_def ? 'isActive' THEN
        v_is_active := (p_item_def->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    v_updated_at := COALESCE((p_item_def->>'updated_at')::TIMESTAMPTZ, now());

    UPDATE item_definitions SET
        item_type_id = v_item_type_id,
        name = v_name,
        is_active = v_is_active,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'item_type_id', v_item_type_id,
        'name', v_name,
        'is_active', v_is_active,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'item_definition',
        v_id::TEXT,
        'update',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 12. RPC: sync_create_carpet_size
-- -----------------------------------------------------------------------------
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
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_carpet_size IS NULL THEN
        RAISE EXCEPTION 'Carpet size payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_carpet_size->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid carpet size UUID: %', p_carpet_size->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Carpet size ID is required' USING ERRCODE = '23502';
    END IF;

    v_length := (p_carpet_size->>'length')::NUMERIC;
    v_width := (p_carpet_size->>'width')::NUMERIC;
    v_area := (p_carpet_size->>'area')::NUMERIC;

    IF v_length IS NULL OR v_length <= 0 THEN
        RAISE EXCEPTION 'Carpet size length must be greater than zero' USING ERRCODE = '23514';
    END IF;
    IF v_width IS NULL OR v_width <= 0 THEN
        RAISE EXCEPTION 'Carpet size width must be greater than zero' USING ERRCODE = '23514';
    END IF;
    IF v_area IS NULL OR v_area <= 0 THEN
        RAISE EXCEPTION 'Carpet size area must be greater than zero' USING ERRCODE = '23514';
    END IF;

    v_name := p_carpet_size->>'name';

    IF EXISTS (
        SELECT 1 FROM carpet_sizes
        WHERE length = v_length AND width = v_width AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Carpet size with dimensions %x% already exists', v_length, v_width USING ERRCODE = '23505';
    END IF;

    v_is_active := COALESCE((p_carpet_size->>'is_active')::BOOLEAN, (p_carpet_size->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_carpet_size->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_carpet_size->>'updated_at')::TIMESTAMPTZ, now());

    INSERT INTO carpet_sizes (id, name, length, width, area, is_active, created_at, updated_at)
    VALUES (v_id, v_name, v_length, v_width, v_area, v_is_active, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        length = EXCLUDED.length,
        width = EXCLUDED.width,
        area = EXCLUDED.area,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'length', v_length,
        'width', v_width,
        'area', v_area,
        'is_active', v_is_active,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'carpet_size',
        v_id::TEXT,
        'create',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 13. RPC: sync_update_carpet_size
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_carpet_size(
    p_op_id TEXT,
    p_carpet_size_id TEXT,
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
    v_updated_at TIMESTAMPTZ;
    v_existing RECORD;
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    BEGIN
        v_id := p_carpet_size_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid carpet size UUID: %', p_carpet_size_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing FROM carpet_sizes WHERE id = v_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Carpet size not found: %', p_carpet_size_id USING ERRCODE = 'P0002';
    END IF;

    IF p_carpet_size IS NULL THEN
        RAISE EXCEPTION 'Update payload is required' USING ERRCODE = '23502';
    END IF;

    IF p_carpet_size ? 'name' THEN
        v_name := p_carpet_size->>'name';
    ELSE
        v_name := v_existing.name;
    END IF;

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

    UPDATE carpet_sizes SET
        name = v_name,
        length = v_length,
        width = v_width,
        area = v_area,
        is_active = v_is_active,
        updated_at = v_updated_at
    WHERE id = v_id;

    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'length', v_length,
        'width', v_width,
        'area', v_area,
        'is_active', v_is_active,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'carpet_size',
        v_id::TEXT,
        'update',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 14. RPC: sync_create_storage_location
-- -----------------------------------------------------------------------------
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
    v_type_id_text TEXT;
    v_type_id UUID;
    v_supported_ids JSONB := '[]'::JSONB;
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_location IS NULL THEN
        RAISE EXCEPTION 'Storage location payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_location->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid storage location UUID: %', p_location->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Storage location ID is required' USING ERRCODE = '23502';
    END IF;

    v_name := trim(COALESCE(p_location->>'name', ''));
    IF v_name = '' THEN
        RAISE EXCEPTION 'Storage location name cannot be empty' USING ERRCODE = '23502';
    END IF;

    IF EXISTS (
        SELECT 1 FROM storage_locations
        WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Storage location with name "%" already exists', v_name USING ERRCODE = '23505';
    END IF;

    v_is_active := COALESCE((p_location->>'is_active')::BOOLEAN, (p_location->>'isActive')::BOOLEAN, true);
    v_created_at := COALESCE((p_location->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_location->>'updated_at')::TIMESTAMPTZ, now());

    INSERT INTO storage_locations (id, name, is_active, created_at, updated_at)
    VALUES (v_id, v_name, v_is_active, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    -- Replace supported item types if array provided
    IF (p_location ? 'supported_item_type_ids' AND jsonb_typeof(p_location->'supported_item_type_ids') = 'array') OR
       (p_location ? 'supportedItemTypeIds' AND jsonb_typeof(p_location->'supportedItemTypeIds') = 'array') THEN
        DELETE FROM storage_location_item_types WHERE storage_location_id = v_id;

        FOR v_type_id_text IN
            SELECT jsonb_array_elements_text(COALESCE(p_location->'supported_item_type_ids', p_location->'supportedItemTypeIds'))
        LOOP
            BEGIN
                v_type_id := v_type_id_text::UUID;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'Invalid item_type UUID in supported types: %', v_type_id_text USING ERRCODE = '23514';
            END;

            IF NOT EXISTS (SELECT 1 FROM item_types WHERE id = v_type_id) THEN
                RAISE EXCEPTION 'Item type not found: %', v_type_id USING ERRCODE = '23503';
            END IF;

            INSERT INTO storage_location_item_types (storage_location_id, item_type_id, created_at)
            VALUES (v_id, v_type_id, now())
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
        'supported_item_type_ids', v_supported_ids,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'storage_location',
        v_id::TEXT,
        'create',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 15. RPC: sync_update_storage_location
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_storage_location(
    p_op_id TEXT,
    p_location_id TEXT,
    p_location JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_name TEXT;
    v_is_active BOOLEAN;
    v_updated_at TIMESTAMPTZ;
    v_existing RECORD;
    v_type_id_text TEXT;
    v_type_id UUID;
    v_supported_ids JSONB;
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    BEGIN
        v_id := p_location_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid storage location UUID: %', p_location_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing FROM storage_locations WHERE id = v_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Storage location not found: %', p_location_id USING ERRCODE = 'P0002';
    END IF;

    IF p_location IS NULL THEN
        RAISE EXCEPTION 'Update payload is required' USING ERRCODE = '23502';
    END IF;

    IF p_location ? 'name' THEN
        v_name := trim(p_location->>'name');
        IF v_name = '' THEN
            RAISE EXCEPTION 'Storage location name cannot be empty' USING ERRCODE = '23502';
        END IF;

        IF EXISTS (
            SELECT 1 FROM storage_locations
            WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
        ) THEN
            RAISE EXCEPTION 'Storage location with name "%" already exists', v_name USING ERRCODE = '23505';
        END IF;
    ELSE
        v_name := v_existing.name;
    END IF;

    IF p_location ? 'is_active' THEN
        v_is_active := (p_location->>'is_active')::BOOLEAN;
    ELSIF p_location ? 'isActive' THEN
        v_is_active := (p_location->>'isActive')::BOOLEAN;
    ELSE
        v_is_active := v_existing.is_active;
    END IF;

    -- Strict business invariant: Cannot deactivate storage location while active items are stored in it
    IF v_is_active = false AND v_existing.is_active = true THEN
        IF EXISTS (
            SELECT 1 FROM storage_records
            WHERE storage_location_id = v_id::TEXT AND is_active = true
        ) THEN
            RAISE EXCEPTION 'Cannot deactivate storage location while items are stored in it' USING ERRCODE = '23514';
        END IF;
    END IF;

    v_updated_at := COALESCE((p_location->>'updated_at')::TIMESTAMPTZ, now());

    UPDATE storage_locations SET
        name = v_name,
        is_active = v_is_active,
        updated_at = v_updated_at
    WHERE id = v_id;

    -- Replace supported item types if array provided
    IF (p_location ? 'supported_item_type_ids' AND jsonb_typeof(p_location->'supported_item_type_ids') = 'array') OR
       (p_location ? 'supportedItemTypeIds' AND jsonb_typeof(p_location->'supportedItemTypeIds') = 'array') THEN
        DELETE FROM storage_location_item_types WHERE storage_location_id = v_id;

        FOR v_type_id_text IN
            SELECT jsonb_array_elements_text(COALESCE(p_location->'supported_item_type_ids', p_location->'supportedItemTypeIds'))
        LOOP
            BEGIN
                v_type_id := v_type_id_text::UUID;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'Invalid item_type UUID in supported types: %', v_type_id_text USING ERRCODE = '23514';
            END;

            IF NOT EXISTS (SELECT 1 FROM item_types WHERE id = v_type_id) THEN
                RAISE EXCEPTION 'Item type not found: %', v_type_id USING ERRCODE = '23503';
            END IF;

            INSERT INTO storage_location_item_types (storage_location_id, item_type_id, created_at)
            VALUES (v_id, v_type_id, now())
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
        'supported_item_type_ids', v_supported_ids,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'storage_location',
        v_id::TEXT,
        'update',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 16. RPC: sync_update_business_settings
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_update_business_settings(
    p_op_id TEXT,
    p_settings JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id TEXT;
    v_business_name TEXT;
    v_address TEXT;
    v_phone TEXT;
    v_logo_reference TEXT;
    v_invoice_footer_text TEXT;
    v_tax_enabled BOOLEAN;
    v_tax_rate DOUBLE PRECISION;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_existing RECORD;
    v_result JSONB;
BEGIN
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    IF p_settings IS NULL THEN
        RAISE EXCEPTION 'Settings payload is required' USING ERRCODE = '23502';
    END IF;

    v_id := COALESCE(p_settings->>'id', '00000000-0000-0000-0000-000000000001');

    SELECT * INTO v_existing FROM business_settings WHERE id = v_id;

    v_business_name := trim(COALESCE(p_settings->>'business_name', p_settings->>'businessName', v_existing.business_name, ''));
    IF v_business_name = '' THEN
        RAISE EXCEPTION 'Business name cannot be empty' USING ERRCODE = '23502';
    END IF;

    IF p_settings ? 'address' THEN
        v_address := p_settings->>'address';
    ELSE
        v_address := v_existing.address;
    END IF;

    IF p_settings ? 'phone' THEN
        v_phone := p_settings->>'phone';
    ELSE
        v_phone := v_existing.phone;
    END IF;

    IF p_settings ? 'logo_reference' THEN
        v_logo_reference := p_settings->>'logo_reference';
    ELSIF p_settings ? 'logoReference' THEN
        v_logo_reference := p_settings->>'logoReference';
    ELSE
        v_logo_reference := v_existing.logo_reference;
    END IF;

    IF p_settings ? 'invoice_footer_text' THEN
        v_invoice_footer_text := p_settings->>'invoice_footer_text';
    ELSIF p_settings ? 'invoiceFooterText' THEN
        v_invoice_footer_text := p_settings->>'invoiceFooterText';
    ELSE
        v_invoice_footer_text := v_existing.invoice_footer_text;
    END IF;

    IF p_settings ? 'tax_enabled' THEN
        v_tax_enabled := (p_settings->>'tax_enabled')::BOOLEAN;
    ELSIF p_settings ? 'taxEnabled' THEN
        v_tax_enabled := (p_settings->>'taxEnabled')::BOOLEAN;
    ELSE
        v_tax_enabled := COALESCE(v_existing.tax_enabled, false);
    END IF;

    IF p_settings ? 'tax_rate' THEN
        v_tax_rate := (p_settings->>'tax_rate')::DOUBLE PRECISION;
    ELSIF p_settings ? 'taxRate' THEN
        v_tax_rate := (p_settings->>'taxRate')::DOUBLE PRECISION;
    ELSE
        v_tax_rate := COALESCE(v_existing.tax_rate, 0.0);
    END IF;

    IF v_tax_rate < 0.0 THEN
        RAISE EXCEPTION 'Tax rate cannot be negative' USING ERRCODE = '23514';
    END IF;

    v_created_at := COALESCE((p_settings->>'created_at')::TIMESTAMPTZ, v_existing.created_at, now());
    v_updated_at := COALESCE((p_settings->>'updated_at')::TIMESTAMPTZ, now());

    INSERT INTO business_settings (
        id, business_name, address, phone, logo_reference,
        invoice_footer_text, tax_enabled, tax_rate, created_at, updated_at
    ) VALUES (
        v_id, v_business_name, v_address, v_phone, v_logo_reference,
        v_invoice_footer_text, v_tax_enabled, v_tax_rate, v_created_at, v_updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        business_name = EXCLUDED.business_name,
        address = EXCLUDED.address,
        phone = EXCLUDED.phone,
        logo_reference = EXCLUDED.logo_reference,
        invoice_footer_text = EXCLUDED.invoice_footer_text,
        tax_enabled = EXCLUDED.tax_enabled,
        tax_rate = EXCLUDED.tax_rate,
        updated_at = EXCLUDED.updated_at;

    v_result := jsonb_build_object(
        'id', v_id,
        'business_name', v_business_name,
        'address', v_address,
        'phone', v_phone,
        'logo_reference', v_logo_reference,
        'invoice_footer_text', v_invoice_footer_text,
        'tax_enabled', v_tax_enabled,
        'tax_rate', v_tax_rate,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'business_settings',
        v_id,
        'update',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
