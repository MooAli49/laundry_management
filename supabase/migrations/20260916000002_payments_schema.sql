-- =============================================================================
-- Step 10 — Supabase PostgreSQL Schema Migration
-- Laundry Management System — Payments Table, RLS & Atomic Payment RPC
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Orders: Add paid_amount if not exists
-- -----------------------------------------------------------------------------
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS paid_amount BIGINT NOT NULL DEFAULT 0
CHECK (paid_amount >= 0);

-- -----------------------------------------------------------------------------
-- 2. Payments Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'insta_pay', 'e_wallet')),
    paid_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_supabase_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_supabase_payments_paid_at ON payments(paid_at);

-- -----------------------------------------------------------------------------
-- 3. Row Level Security
-- Payments are immutable and managed securely via server-side Edge Functions.
-- Default-deny prevents unauthorized anonymous mutations.
-- -----------------------------------------------------------------------------
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 4. Atomic Payment RPC with Concurrency Lock & Idempotency
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
    -- 1. Idempotency Check: Return cached response if operation was already processed
    SELECT response_payload INTO v_cached
    FROM sync_idempotency_log
    WHERE operation_id = p_op_id;

    IF v_cached IS NOT NULL THEN
        RETURN v_cached;
    END IF;

    -- 2. Validate and Parse Input Payload
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

    -- 3. Lock Order Row with FOR UPDATE (Authoritative Concurrency Protection)
    SELECT total, paid_amount, status
    INTO v_order_total, v_order_paid_amount, v_order_status
    FROM orders
    WHERE id = v_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', v_order_id USING ERRCODE = 'P0002';
    END IF;

    -- 4. Enforce Business Rules
    IF v_order_status = 'cancelled' THEN
        RAISE EXCEPTION 'Cannot record payment for a cancelled order' USING ERRCODE = '23505';
    END IF;

    v_remaining := v_order_total - COALESCE(v_order_paid_amount, 0);
    IF v_amount > v_remaining THEN
        RAISE EXCEPTION 'Payment amount % exceeds remaining order balance %', v_amount, v_remaining USING ERRCODE = '23505';
    END IF;

    -- 5. Insert Payment Record
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

    -- 6. Atomically Increment Order Paid Amount
    UPDATE orders
    SET paid_amount = paid_amount + v_amount,
        updated_at = now()
    WHERE id = v_order_id;

    -- 7. Construct Result Payload
    v_result := jsonb_build_object(
        'id', v_id,
        'order_id', v_order_id,
        'amount', v_amount,
        'payment_method', v_payment_method,
        'paid_at', v_paid_at,
        'created_at', v_created_at,
        'updated_at', v_updated_at
    );

    -- 8. Record Operation in Idempotency Log (Within Same ACID Transaction)
    INSERT INTO sync_idempotency_log (
        operation_id,
        entity_type,
        entity_id,
        operation_type,
        applied_at,
        response_payload
    ) VALUES (
        p_op_id,
        'payment',
        v_id::TEXT,
        'create',
        now(),
        v_result
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
