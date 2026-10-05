-- Migration: 20260923000002_allow_completed_to_processing_correction.sql
-- Description: Aligns backend lifecycle contract with the approved domain model and client specifications.
--              Permits administrative status correction of orders from 'completed' back to 'processing'.
--              Cancelled orders remain strictly terminal.
--              Completed orders cannot transition to 'ready' or 'cancelled'.
--              Completed -> Processing clears completed_at, preserves payments, preserves inactive storage records,
--              and emits an atomic sync_change event.

CREATE OR REPLACE FUNCTION public.sync_update_order(
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
    -- 1. Cancelled orders are strictly terminal in V1
    IF v_existing.status = 'cancelled' AND v_status <> v_existing.status THEN
        RAISE EXCEPTION 'INVALID_LIFECYCLE_TRANSITION: Cannot transition order % from terminal state % to %',
            p_order_id, v_existing.status, v_status USING ERRCODE = '23514';
    END IF;

    -- 2. Completed orders: only administrative correction back to 'processing' is permitted.
    --    Transitions to 'ready' or 'cancelled' are rejected.
    --    Same-status ('completed' -> 'completed') is idempotent/harmless.
    IF v_existing.status = 'completed' AND v_status <> v_existing.status THEN
        IF v_status <> 'processing' THEN
            RAISE EXCEPTION 'INVALID_LIFECYCLE_TRANSITION: Cannot transition order % from completed to %',
                p_order_id, v_status USING ERRCODE = '23514';
        END IF;
    END IF;

    -- Completed_at handling:
    -- If transitioning to 'processing', completed_at must be cleared to NULL
    IF v_status = 'processing' THEN
        v_completed_at := NULL;
    ELSIF p_order ? 'completed_at' THEN
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
