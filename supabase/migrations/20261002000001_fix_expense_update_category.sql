-- =============================================================================
-- Migration: 20261002000001_fix_expense_update_category.sql
-- Description: BUG-05 — Permit updating expense_category_id and category_name_snapshot
--              in sync_update_expense RPC, maintaining idempotency, concurrency,
--              foreign key integrity, and sync_changes log accuracy.
-- =============================================================================

CREATE OR REPLACE FUNCTION sync_update_expense(
    p_op_id TEXT,
    p_expense_id TEXT,
    p_expense JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_existing expenses%ROWTYPE;
    v_category_id UUID;
    v_cat_name TEXT;
    v_cat_is_active BOOLEAN;
    v_snapshot TEXT;
    v_amount BIGINT;
    v_expense_name TEXT;
    v_expense_date DATE;
    v_notes TEXT;
    v_updated_at TIMESTAMPTZ;
    v_base_version INTEGER;
    v_new_version INTEGER;
    v_result JSONB;
BEGIN
    -- 1. Idempotency Check
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Validate expense ID
    BEGIN
        v_id := p_expense_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid expense UUID: %', p_expense_id USING ERRCODE = '23514';
    END;

    -- 3. Lock and retrieve existing expense
    SELECT * INTO v_existing FROM expenses WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Expense % not found', p_expense_id USING ERRCODE = 'P0002';
    END IF;

    -- 4. Concurrency Control (base_version check)
    IF p_expense ? 'base_version' AND (p_expense->>'base_version') IS NOT NULL THEN
        v_base_version := (p_expense->>'base_version')::INTEGER;
        IF v_base_version <> v_existing.server_version THEN
            RAISE EXCEPTION 'CONCURRENCY_CONFLICT: base_version % does not match server_version % for expense %',
                v_base_version, v_existing.server_version, p_expense_id USING ERRCODE = 'P0004';
        END IF;
    END IF;

    -- 5. Handle expense_category_id & category_name_snapshot
    IF p_expense ? 'expense_category_id' THEN
        IF (p_expense->>'expense_category_id') IS NULL OR trim(p_expense->>'expense_category_id') = '' THEN
            RAISE EXCEPTION 'Expense category ID cannot be null or empty' USING ERRCODE = '23502';
        END IF;

        BEGIN
            v_category_id := (p_expense->>'expense_category_id')::UUID;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid expense category UUID: %', p_expense->>'expense_category_id' USING ERRCODE = '23514';
        END;

        SELECT name, is_active INTO v_cat_name, v_cat_is_active
        FROM expense_categories
        WHERE id = v_category_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Expense category % does not exist', v_category_id USING ERRCODE = '23503';
        END IF;

        v_snapshot := trim(COALESCE(p_expense->>'category_name_snapshot', v_cat_name));
    ELSE
        v_category_id := v_existing.expense_category_id;
        v_snapshot := v_existing.category_name_snapshot;
        v_cat_name := v_existing.category_name_snapshot;
    END IF;

    -- 6. Handle amount
    IF p_expense ? 'amount' AND (p_expense->>'amount') IS NOT NULL THEN
        v_amount := (p_expense->>'amount')::BIGINT;
        IF v_amount <= 0 THEN
            RAISE EXCEPTION 'Expense amount must be greater than zero' USING ERRCODE = '23514';
        END IF;
    ELSE
        v_amount := v_existing.amount;
    END IF;

    -- 7. Handle expense_name
    IF p_expense ? 'expense_name' THEN
        v_expense_name := trim(COALESCE(p_expense->>'expense_name', ''));
    ELSE
        v_expense_name := v_existing.expense_name;
    END IF;

    -- 8. Category 'أخرى' validation
    IF (v_snapshot = 'أخرى' OR v_cat_name = 'أخرى') AND (v_expense_name IS NULL OR v_expense_name = '') THEN
        RAISE EXCEPTION 'Expense name is required when category is أخرى' USING ERRCODE = '23514';
    END IF;

    -- 9. Handle expense_date
    IF p_expense ? 'expense_date' AND (p_expense->>'expense_date') IS NOT NULL THEN
        BEGIN
            v_expense_date := (p_expense->>'expense_date')::DATE;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid expense date format: %. Expected YYYY-MM-DD', p_expense->>'expense_date' USING ERRCODE = '23514';
        END;
    ELSE
        v_expense_date := v_existing.expense_date;
    END IF;

    -- 10. Handle notes
    IF p_expense ? 'notes' THEN
        v_notes := trim(COALESCE(p_expense->>'notes', ''));
    ELSE
        v_notes := v_existing.notes;
    END IF;

    v_updated_at := COALESCE((p_expense->>'updated_at')::TIMESTAMPTZ, now());
    v_new_version := v_existing.server_version + 1;

    -- 11. Apply Update
    UPDATE expenses
    SET expense_category_id = v_category_id,
        category_name_snapshot = v_snapshot,
        amount = v_amount,
        expense_name = NULLIF(v_expense_name, ''),
        expense_date = v_expense_date,
        notes = NULLIF(v_notes, ''),
        server_version = v_new_version,
        updated_at = v_updated_at
    WHERE id = v_id;

    -- 12. Construct Result Payload
    v_result := jsonb_build_object(
        'id', v_id,
        'expense_category_id', v_category_id,
        'amount', v_amount,
        'expense_name', NULLIF(v_expense_name, ''),
        'expense_date', v_expense_date,
        'notes', NULLIF(v_notes, ''),
        'category_name_snapshot', v_snapshot,
        'server_version', v_new_version,
        'created_at', v_existing.created_at,
        'updated_at', v_updated_at
    );

    -- 13. Insert into sync_changes
    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'expense', v_id::TEXT, 'update', v_result, v_new_version, now());

    -- 14. Record in Idempotency Log
    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'expense', v_id::TEXT, 'update', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER FUNCTION public.sync_update_expense(text, text, jsonb) SET search_path = public, pg_temp;
