-- =============================================================================
-- Migration: 20260924000000_refunds_schema.sql
-- Feature: Refunds for Cancelled Orders (Phase 1 Backend & Database)
--
-- Tables:
--   - refunds: Append-only immutable refund records linked to orders
--
-- Functions:
--   - sync_create_refund: Transactional, idempotent, concurrency-locked RPC
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Refunds Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS refunds (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL CHECK (amount > 0),
    refund_method TEXT NOT NULL CHECK (refund_method IN ('cash', 'insta_pay', 'e_wallet')),
    reason TEXT,
    refunded_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 2. Indexes
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_supabase_refunds_order_id ON refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_supabase_refunds_refunded_at ON refunds(refunded_at);

-- -----------------------------------------------------------------------------
-- 3. Row Level Security
-- -----------------------------------------------------------------------------
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 4. Transactional Atomic Refund RPC with Concurrency Lock & Idempotency
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_create_refund(
    p_op_id TEXT,
    p_refund JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cached JSONB;
    v_id UUID;
    v_order_id UUID;
    v_amount BIGINT;
    v_refund_method TEXT;
    v_reason TEXT;
    v_refunded_at TIMESTAMPTZ;
    v_created_at TIMESTAMPTZ;
    v_updated_at TIMESTAMPTZ;
    v_order_status TEXT;
    v_total_paid BIGINT;
    v_total_refunded BIGINT;
    v_refundable BIGINT;
    v_result JSONB;
BEGIN
    -- 1. Idempotency Check: Return cached response if operation was already processed
    v_cached := check_idempotency(p_op_id);
    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Validate Payload
    IF p_refund IS NULL THEN
        RAISE EXCEPTION 'Refund payload is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_id := (p_refund->>'id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid refund UUID: %', p_refund->>'id' USING ERRCODE = '23514';
    END;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Refund ID is required' USING ERRCODE = '23502';
    END IF;

    BEGIN
        v_order_id := (p_refund->>'order_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid order UUID: %', p_refund->>'order_id' USING ERRCODE = '23514';
    END;

    IF v_order_id IS NULL THEN
        RAISE EXCEPTION 'Order ID is required' USING ERRCODE = '23502';
    END IF;

    IF NOT (p_refund ? 'amount') OR (p_refund->>'amount') IS NULL THEN
        RAISE EXCEPTION 'Refund amount is required' USING ERRCODE = '23502';
    END IF;

    v_amount := (p_refund->>'amount')::BIGINT;
    IF v_amount <= 0 THEN
        RAISE EXCEPTION 'Refund amount must be greater than zero' USING ERRCODE = '23514';
    END IF;

    v_refund_method := p_refund->>'refund_method';
    IF v_refund_method IS NULL OR v_refund_method NOT IN ('cash', 'insta_pay', 'e_wallet') THEN
        RAISE EXCEPTION 'Invalid refund method: %. Must be cash, insta_pay, or e_wallet', v_refund_method USING ERRCODE = '23514';
    END IF;

    v_reason := p_refund->>'reason';
    v_refunded_at := COALESCE((p_refund->>'refunded_at')::TIMESTAMPTZ, now());
    v_created_at := COALESCE((p_refund->>'created_at')::TIMESTAMPTZ, now());
    v_updated_at := COALESCE((p_refund->>'updated_at')::TIMESTAMPTZ, now());

    -- 3. Lock parent order row for concurrency protection
    SELECT status
    INTO v_order_status
    FROM orders
    WHERE id = v_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', v_order_id USING ERRCODE = 'P0002';
    END IF;

    -- 4. Status Check: Only cancelled orders can receive refunds
    IF v_order_status <> 'cancelled' THEN
        RAISE EXCEPTION 'INVALID_LIFECYCLE_TRANSITION: Refunds are only allowed for cancelled orders. Current status: %', v_order_status USING ERRCODE = '23514';
    END IF;

    -- 5. Calculate refundable balance
    SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
    FROM payments
    WHERE order_id = v_order_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_refunded
    FROM refunds
    WHERE order_id = v_order_id;

    v_refundable := v_total_paid - v_total_refunded;

    IF v_amount > v_refundable THEN
        RAISE EXCEPTION 'REFUND_BALANCE_EXCEEDED: Refund amount % exceeds refundable balance %', v_amount, v_refundable USING ERRCODE = '23514';
    END IF;

    -- 6. Insert Refund record (append-only)
    INSERT INTO refunds (
        id,
        order_id,
        amount,
        refund_method,
        reason,
        refunded_at,
        created_at,
        updated_at
    ) VALUES (
        v_id,
        v_order_id,
        v_amount,
        v_refund_method,
        v_reason,
        v_refunded_at,
        v_created_at,
        v_updated_at
    );

    v_result := jsonb_build_object(
        'id', v_id,
        'order_id', v_order_id,
        'amount', v_amount,
        'refund_method', v_refund_method,
        'reason', v_reason,
        'refunded_at', v_refunded_at,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    -- 7. Insert change log (refunds follow payment convention: server_version = NULL)
    INSERT INTO sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
    VALUES (p_op_id, 'refund', v_id::TEXT, 'create', v_result, NULL, now());

    -- 8. Record in idempotency log
    INSERT INTO sync_idempotency_log (operation_id, entity_type, entity_id, operation_type, applied_at, response_payload)
    VALUES (p_op_id, 'refund', v_id::TEXT, 'create', now(), v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
