-- =============================================================================
-- Step 11 — Supabase PostgreSQL Schema Migration
-- Laundry Management System — Expense Categories, Expenses, RLS & Sync RPCs
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Expense Categories Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Case-insensitive & whitespace-normalized unique index for category name
CREATE UNIQUE INDEX IF NOT EXISTS idx_expense_categories_name_lower
ON expense_categories (LOWER(TRIM(name)));

-- -----------------------------------------------------------------------------
-- 2. Expenses Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY,
    expense_category_id UUID NOT NULL REFERENCES expense_categories(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL CHECK (amount > 0),
    expense_name TEXT,
    expense_date DATE NOT NULL,
    notes TEXT,
    category_name_snapshot TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expenses_category_date ON expenses(expense_category_id, expense_date);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);

-- -----------------------------------------------------------------------------
-- 3. Row Level Security
-- Expenses and categories are managed securely via server-side Edge Functions.
-- Default-deny prevents unauthorized mutations directly by client keys.
-- -----------------------------------------------------------------------------
ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 4. RPC: sync_create_expense_category
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
    v_result JSONB;
BEGIN
    -- 1. Idempotency check
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Validate input payload
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

    -- Case-insensitive duplicate name check
    IF EXISTS (
        SELECT 1 FROM expense_categories
        WHERE LOWER(TRIM(name)) = LOWER(v_name) AND id <> v_id
    ) THEN
        RAISE EXCEPTION 'Expense category with name "%" already exists', v_name USING ERRCODE = '23505';
    END IF;

    v_is_active := COALESCE((p_category->>'is_active')::BOOLEAN, true);
    v_created_at := COALESCE((p_category->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_category->>'updated_at')::TIMESTAMPTZ, now());

    -- 3. Upsert category
    INSERT INTO expense_categories (id, name, is_active, created_at, updated_at)
    VALUES (v_id, v_name, v_is_active, v_created_at, v_updated_at)
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    -- 4. Construct result payload
    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    -- 5. Record operation in idempotency log
    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'expense_category',
        v_id::TEXT,
        'create',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. RPC: sync_update_expense_category
-- -----------------------------------------------------------------------------
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
    v_result JSONB;
BEGIN
    -- 1. Idempotency check
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Validate category ID
    BEGIN
        v_id := p_category_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid category UUID: %', p_category_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing
    FROM expense_categories
    WHERE id = v_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Expense category % not found', p_category_id USING ERRCODE = 'P0002';
    END IF;

    -- 3. Resolve updates
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

    -- 4. Apply update
    UPDATE expense_categories
    SET name = v_name,
        is_active = v_is_active,
        updated_at = v_updated_at
    WHERE id = v_id;

    -- 5. Construct result
    v_result := jsonb_build_object(
        'id', v_id,
        'name', v_name,
        'is_active', v_is_active,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    -- 6. Record operation in idempotency log
    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'expense_category',
        v_id::TEXT,
        'update',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 6. RPC: sync_create_expense
-- -----------------------------------------------------------------------------
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
    v_result JSONB;
BEGIN
    -- 1. Idempotency check
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Validate input payload
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

    -- Check category referential validity
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

    -- Conditional validation: category "أخرى" requires custom name
    IF (v_snapshot = 'أخرى' OR v_cat_name = 'أخرى') AND v_expense_name = '' THEN
        RAISE EXCEPTION 'Expense name is required when category is أخرى' USING ERRCODE = '23514';
    END IF;

    v_created_at := COALESCE((p_expense->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_expense->>'updated_at')::TIMESTAMPTZ, now());

    -- 3. Upsert Expense Record
    INSERT INTO expenses (
        id,
        expense_category_id,
        amount,
        expense_name,
        expense_date,
        notes,
        category_name_snapshot,
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
        updated_at = EXCLUDED.updated_at;

    -- 4. Construct Result
    v_result := jsonb_build_object(
        'id', v_id,
        'expense_category_id', v_category_id,
        'amount', v_amount,
        'expense_name', NULLIF(v_expense_name, ''),
        'expense_date', v_expense_date,
        'notes', NULLIF(v_notes, ''),
        'category_name_snapshot', v_snapshot,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    -- 5. Record Operation in Idempotency Log
    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'expense',
        v_id::TEXT,
        'create',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. RPC: sync_update_expense
-- -----------------------------------------------------------------------------
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
    v_result JSONB;
BEGIN
    -- 1. Idempotency check
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Validate expense ID
    BEGIN
        v_id := p_expense_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid expense UUID: %', p_expense_id USING ERRCODE = '23514';
    END;

    SELECT * INTO v_existing
    FROM expenses
    WHERE id = v_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Expense % not found', p_expense_id USING ERRCODE = 'P0002';
    END IF;

    -- 3. Resolve Updates
    IF p_expense ? 'amount' AND (p_expense->>'amount') IS NOT NULL THEN
        v_amount := (p_expense->>'amount')::BIGINT;
        IF v_amount <= 0 THEN
            RAISE EXCEPTION 'Expense amount must be greater than zero' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_amount := v_existing.amount;
    END IF;

    IF p_expense ? 'expense_date' AND (p_expense->>'expense_date') IS NOT NULL THEN
        BEGIN
            v_expense_date := (p_expense->>'expense_date')::DATE;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid expense date format: %', p_expense->>'expense_date' USING ERRCODE = '23514';
        END;
    ELSE
        v_expense_date := v_existing.expense_date;
    END IF;

    IF p_expense ? 'expense_name' THEN
        v_expense_name := trim(COALESCE(p_expense->>'expense_name', ''));
        IF v_existing.category_name_snapshot = 'أخرى' AND v_expense_name = '' THEN
            RAISE EXCEPTION 'Expense name is required when category is أخرى' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_expense_name := v_existing.expense_name;
    END IF;

    IF p_expense ? 'notes' THEN
        v_notes := trim(COALESCE(p_expense->>'notes', ''));
    ELSE
        v_notes := v_existing.notes;
    END IF;

    v_updated_at := COALESCE((p_expense->>'updated_at')::TIMESTAMPTZ, now());

    -- 4. Apply Update (expense_category_id is not updated)
    UPDATE expenses
    SET amount = v_amount,
        expense_name = NULLIF(v_expense_name, ''),
        expense_date = v_expense_date,
        notes = NULLIF(v_notes, ''),
        updated_at = v_updated_at
    WHERE id = v_id;

    -- 5. Construct Result
    v_result := jsonb_build_object(
        'id', v_id,
        'expense_category_id', v_existing.expense_category_id,
        'amount', v_amount,
        'expense_name', NULLIF(v_expense_name, ''),
        'expense_date', v_expense_date,
        'notes', NULLIF(v_notes, ''),
        'category_name_snapshot', v_existing.category_name_snapshot,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    -- 6. Record Operation in Idempotency Log
    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'expense',
        v_id::TEXT,
        'update',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
