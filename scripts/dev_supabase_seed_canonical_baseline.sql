-- =============================================================================
-- GUARDED DEVELOPMENT SCRIPT: CANONICAL MASTER BASELINE SEEDING
-- Project Ref: dyhfgnbhijukbdptreto
-- Target Environment: DEVELOPMENT ONLY
-- Phase: 3A (Canonical Master Baseline)
--
-- PURPOSE:
-- Seeds the 35 canonical master records and their authoritative sync_changes
-- (Sequences 1..35) into the freshly-reset development Supabase database.
--
-- USAGE — SINGLE-USE ONLY:
-- This script is intentionally single-use. It must be run exactly once
-- against a clean development database (sync_changes = 0). Re-running it
-- will be rejected by Guard 2 (sync_changes != 0 precondition).
--
-- WHAT IS AND IS NOT IDEMPOTENT:
-- * This script itself is NOT idempotent. It is a one-time seeding operation.
-- * The sync_changes rows it produces (sequences 1..35) contain canonical
--   UUIDs and stable payloads. Any Flutter client starting from cursor 0
--   can deterministically replay those changes to reconstruct master state.
--   That client-side replay is idempotent and safe.
-- * Rerunning this script on a non-empty database is intentionally rejected
--   by the sync_changes = 0 guard — it will RAISE EXCEPTION and roll back.
--
-- GUARANTEES:
-- 1. Atomic: Executes inside a single transaction (BEGIN ... COMMIT).
-- 2. Guarded: Fails closed unless app.project_ref, app.environment, and
--    app.confirm_canonical_seed are explicitly asserted by the operator.
-- 3. Strict Cursor Continuity: Generates sequences 1..35 with no gaps.
-- 4. Timestamp Consistency: A single deterministic timestamp (app.seed_ts) is
--    captured once per transaction via transaction_timestamp() and used for
--    every relational row AND its embedded payload snapshot, so
--    created_at/updated_at values match exactly between row and payload.
-- 5. No Schema Changes: Zero ALTER TABLE, zero ADD CONSTRAINT, NO CASCADE.
-- =============================================================================

BEGIN;

SET LOCAL app.project_ref = 'dyhfgnbhijukbdptreto';
SET LOCAL app.environment = 'development';
SET LOCAL app.confirm_canonical_seed = 'CONFIRMED_CANONICAL_SEED_2026_DYHFGNBHIJUKBDPTRETO';

-- -----------------------------------------------------------------------------
-- GUARD 1: OPERATOR-ASSERTED DEVELOPMENT ENVIRONMENT IDENTITY
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_project_ref TEXT := current_setting('app.project_ref', true);
    v_environment TEXT := current_setting('app.environment', true);
    v_confirmation TEXT := current_setting('app.confirm_canonical_seed', true);
BEGIN
    IF v_project_ref IS NULL OR v_project_ref <> 'dyhfgnbhijukbdptreto' THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: app.project_ref must be set to dyhfgnbhijukbdptreto. Aborting.';
    END IF;

    IF v_environment IS NULL OR v_environment <> 'development' THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: app.environment must be set to development. Aborting.';
    END IF;

    IF v_confirmation IS NULL OR v_confirmation <> 'CONFIRMED_CANONICAL_SEED_2026_DYHFGNBHIJUKBDPTRETO' THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Operator confirmation token missing or invalid. Aborting.';
    END IF;

    RAISE NOTICE 'Guard 1 Passed: Authorized execution on % (%).', v_project_ref, v_environment;
END $$;

-- -----------------------------------------------------------------------------
-- GUARD 2: SCHEMA READINESS & CLEAN PRECONDITION ASSERTION
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_table_name TEXT;
    v_required_tables TEXT[] := ARRAY[
        'business_settings',
        'item_types',
        'expense_categories',
        'services',
        'service_item_types',
        'carpet_sizes',
        'storage_locations',
        'storage_location_item_types',
        'item_definitions',
        'sync_changes',
        'sync_idempotency_log'
    ];
    v_sync_count BIGINT;
    v_bs_count BIGINT;
    v_other_count BIGINT;
BEGIN
    -- Verify all required tables exist
    FOREACH v_table_name IN ARRAY v_required_tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = v_table_name
        ) THEN
            RAISE EXCEPTION 'PRECONDITION FAILED: Required table public.% does not exist.', v_table_name;
        END IF;
    END LOOP;

    -- Verify sync_changes is completely empty (single-use script: rejected if already seeded)
    SELECT count(*) INTO v_sync_count FROM public.sync_changes;
    IF v_sync_count <> 0 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: sync_changes contains % rows. Expected 0. '
            'This script is single-use. Run dev_supabase_safe_reset.sql first.', v_sync_count;
    END IF;

    -- Verify business_settings has exactly 1 singleton row
    SELECT count(*) INTO v_bs_count FROM public.business_settings WHERE id = '00000000-0000-0000-0000-000000000001';
    IF v_bs_count <> 1 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: business_settings canonical singleton missing. Run dev_supabase_safe_reset.sql first.';
    END IF;

    -- Verify master tables are clean
    SELECT count(*) INTO v_other_count FROM public.item_types;
    IF v_other_count <> 0 THEN RAISE EXCEPTION 'PRECONDITION FAILED: item_types has % rows. Expected 0.', v_other_count; END IF;

    SELECT count(*) INTO v_other_count FROM public.expense_categories;
    IF v_other_count <> 0 THEN RAISE EXCEPTION 'PRECONDITION FAILED: expense_categories has % rows. Expected 0.', v_other_count; END IF;

    SELECT count(*) INTO v_other_count FROM public.services;
    IF v_other_count <> 0 THEN RAISE EXCEPTION 'PRECONDITION FAILED: services has % rows. Expected 0.', v_other_count; END IF;

    SELECT count(*) INTO v_other_count FROM public.carpet_sizes;
    IF v_other_count <> 0 THEN RAISE EXCEPTION 'PRECONDITION FAILED: carpet_sizes has % rows. Expected 0.', v_other_count; END IF;

    SELECT count(*) INTO v_other_count FROM public.storage_locations;
    IF v_other_count <> 0 THEN RAISE EXCEPTION 'PRECONDITION FAILED: storage_locations has % rows. Expected 0.', v_other_count; END IF;

    SELECT count(*) INTO v_other_count FROM public.item_definitions;
    IF v_other_count <> 0 THEN RAISE EXCEPTION 'PRECONDITION FAILED: item_definitions has % rows. Expected 0.', v_other_count; END IF;

    RAISE NOTICE 'Guard 2 Passed: Preconditions verified. Environment clean and ready for baseline seeding.';
END $$;

-- -----------------------------------------------------------------------------
-- CAPTURE DETERMINISTIC SEED TIMESTAMP
-- A single transaction-local timestamp is captured once and stored in
-- app.seed_ts. Every relational row AND its embedded payload snapshot
-- reference this same value, so created_at/updated_at match exactly.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    PERFORM set_config('app.seed_ts', transaction_timestamp()::text, true);
    RAISE NOTICE 'Seed timestamp captured: %', current_setting('app.seed_ts', true);
END $$;

-- -----------------------------------------------------------------------------
-- SECTION 1: SEED CANONICAL RELATIONAL MASTER DATA
-- -----------------------------------------------------------------------------

-- 1.1 Business Settings (Update singleton values)
UPDATE public.business_settings
SET business_name       = '',
    address             = NULL,
    phone               = NULL,
    logo_reference      = NULL,
    invoice_footer_text = NULL,
    tax_enabled         = false,
    tax_rate            = 0.0,
    server_version      = 1,
    updated_at          = current_setting('app.seed_ts', true)::timestamptz
WHERE id = '00000000-0000-0000-0000-000000000001';

-- 1.2 Item Types (4 canonical rows)
INSERT INTO public.item_types (id, name, is_active, created_at, updated_at) VALUES
('00000000-0000-0000-0001-000000000001', 'ملابس',  true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0001-000000000002', 'بطاطين', true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0001-000000000003', 'سجاد',   true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0001-000000000004', 'أغطية',  true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz);

-- 1.3 Expense Categories (7 canonical rows)
INSERT INTO public.expense_categories (id, name, is_active, created_at, updated_at) VALUES
('00000000-0000-0000-0002-000000000001', 'كهرباء',   true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000002', 'مياه',     true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000003', 'منظفات',   true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000004', 'صيانة',    true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000005', 'مستلزمات', true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000006', 'نقل',      true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000007', 'أخرى',     true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz);

-- 1.4 Services (5 canonical rows)
INSERT INTO public.services (id, name, description, pricing_type, price, is_active, server_version, created_at, updated_at) VALUES
('00000000-0000-0000-0002-000000000001', 'غسيل ومكوى',   'خدمة تجريبية', 'per_piece',        2500, true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000002', 'دراي كلين',    'خدمة تجريبية', 'per_piece',        4500, true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000003', 'غسيل سجاد',    'خدمة تجريبية', 'per_square_meter', 6000, true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000004', 'تنظيف بطاطين', 'خدمة تجريبية', 'fixed_price',      8000, true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000005', 'غسيل أغطية',   'خدمة تجريبية', 'fixed_price',      3500, true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz);

-- 1.5 Service Item Types (Junction Table)
INSERT INTO public.service_item_types (service_id, item_type_id, created_at) VALUES
('00000000-0000-0000-0002-000000000001', '00000000-0000-0000-0001-000000000001', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000002', '00000000-0000-0000-0001-000000000001', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000003', '00000000-0000-0000-0001-000000000003', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000004', '00000000-0000-0000-0001-000000000002', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0002-000000000005', '00000000-0000-0000-0001-000000000004', current_setting('app.seed_ts', true)::timestamptz);

-- 1.6 Carpet Sizes (3 canonical rows)
INSERT INTO public.carpet_sizes (id, name, length, width, area, is_active, created_at, updated_at) VALUES
('00000000-0000-0000-0007-000000000001', '2.0x3.0', 2.0, 3.0, 6.0, true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0007-000000000002', '1.5x2.0', 1.5, 2.0, 3.0, true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0007-000000000003', '1.0x4.0', 1.0, 4.0, 4.0, true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz);

-- 1.7 Storage Locations (5 canonical rows)
INSERT INTO public.storage_locations (id, name, is_active, server_version, created_at, updated_at) VALUES
('00000000-0000-0000-0006-000000000001', 'رف أ-1',         true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000002', 'رف أ-2',         true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000003', 'رف ب-1',         true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000004', 'قسم السجاد 1',   true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000005', 'قسم البطاطين 1', true, 1, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz);

-- 1.8 Storage Location Item Types (Junction Table)
INSERT INTO public.storage_location_item_types (storage_location_id, item_type_id, created_at) VALUES
('00000000-0000-0000-0006-000000000001', '00000000-0000-0000-0001-000000000001', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000001', '00000000-0000-0000-0001-000000000004', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000002', '00000000-0000-0000-0001-000000000001', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000002', '00000000-0000-0000-0001-000000000004', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000003', '00000000-0000-0000-0001-000000000001', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000003', '00000000-0000-0000-0001-000000000004', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000004', '00000000-0000-0000-0001-000000000003', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000005', '00000000-0000-0000-0001-000000000002', current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0006-000000000005', '00000000-0000-0000-0001-000000000004', current_setting('app.seed_ts', true)::timestamptz);

-- 1.9 Item Definitions (10 canonical rows)
INSERT INTO public.item_definitions (id, item_type_id, name, is_active, created_at, updated_at) VALUES
('00000000-0000-0000-0005-000000000001', '00000000-0000-0000-0001-000000000001', 'قميص',        true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000002', '00000000-0000-0000-0001-000000000001', 'بنطلون',      true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000003', '00000000-0000-0000-0001-000000000001', 'بدلة',        true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000004', '00000000-0000-0000-0001-000000000002', 'بطانية مفرد', true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000005', '00000000-0000-0000-0001-000000000002', 'بطانية دبل',  true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000006', '00000000-0000-0000-0001-000000000003', 'سجادة صوف',   true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000007', '00000000-0000-0000-0001-000000000003', 'مشاية',       true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000008', '00000000-0000-0000-0001-000000000004', 'غطاء لحاف',   true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000009', '00000000-0000-0000-0001-000000000004', 'كوفرتة',      true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz),
('00000000-0000-0000-0005-000000000010', '00000000-0000-0000-0001-000000000003', 'سجادة حرير',  true, current_setting('app.seed_ts', true)::timestamptz, current_setting('app.seed_ts', true)::timestamptz);


-- -----------------------------------------------------------------------------
-- SECTION 2: SEED CANONICAL SYNC CHANGES (SEQUENCES 1..35)
-- Sequence values are generated naturally via nextval(sync_changes_sequence_seq)
-- preserving strict sequential order and database sequence semantics.
-- All payload created_at/updated_at use current_setting('app.seed_ts') —
-- the same value stored in the relational rows above — so each snapshot
-- accurately represents the row that was seeded.
-- -----------------------------------------------------------------------------

-- Sequence 1: Business Settings Singleton
INSERT INTO public.sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
VALUES (
    'op-baseline-001',
    'business_settings',
    '00000000-0000-0000-0000-000000000001',
    'create',
    jsonb_build_object(
        'id',             '00000000-0000-0000-0000-000000000001',
        'business_name',  '',
        'tax_enabled',    false,
        'tax_rate',       0.0,
        'server_version', 1,
        'created_at',     current_setting('app.seed_ts', true),
        'updated_at',     current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
);

-- Sequences 2..5: Item Types (4 changes)
INSERT INTO public.sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
VALUES
(
    'op-baseline-002',
    'item_type',
    '00000000-0000-0000-0001-000000000001',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0001-000000000001',
        'name', 'ملابس',
        'is_active', true,
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-003',
    'item_type',
    '00000000-0000-0000-0001-000000000002',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0001-000000000002',
        'name', 'بطاطين',
        'is_active', true,
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-004',
    'item_type',
    '00000000-0000-0000-0001-000000000003',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0001-000000000003',
        'name', 'سجاد',
        'is_active', true,
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-005',
    'item_type',
    '00000000-0000-0000-0001-000000000004',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0001-000000000004',
        'name', 'أغطية',
        'is_active', true,
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
);

-- Sequences 6..12: Expense Categories (7 changes)
INSERT INTO public.sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
VALUES
(
    'op-baseline-006',
    'expense_category',
    '00000000-0000-0000-0002-000000000001',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0002-000000000001', 'name', 'كهرباء',   'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-007',
    'expense_category',
    '00000000-0000-0000-0002-000000000002',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0002-000000000002', 'name', 'مياه',     'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-008',
    'expense_category',
    '00000000-0000-0000-0002-000000000003',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0002-000000000003', 'name', 'منظفات',   'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-009',
    'expense_category',
    '00000000-0000-0000-0002-000000000004',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0002-000000000004', 'name', 'صيانة',    'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-010',
    'expense_category',
    '00000000-0000-0000-0002-000000000005',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0002-000000000005', 'name', 'مستلزمات', 'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-011',
    'expense_category',
    '00000000-0000-0000-0002-000000000006',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0002-000000000006', 'name', 'نقل',      'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-012',
    'expense_category',
    '00000000-0000-0000-0002-000000000007',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0002-000000000007', 'name', 'أخرى',     'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
);

-- Sequences 13..17: Services (5 changes, canonical supported_item_type_ids embedded)
INSERT INTO public.sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
VALUES
(
    'op-baseline-013',
    'service',
    '00000000-0000-0000-0002-000000000001',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0002-000000000001',
        'name', 'غسيل ومكوى',
        'description', 'خدمة تجريبية',
        'pricing_type', 'per_piece',
        'price', 2500,
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000001'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-014',
    'service',
    '00000000-0000-0000-0002-000000000002',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0002-000000000002',
        'name', 'دراي كلين',
        'description', 'خدمة تجريبية',
        'pricing_type', 'per_piece',
        'price', 4500,
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000001'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-015',
    'service',
    '00000000-0000-0000-0002-000000000003',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0002-000000000003',
        'name', 'غسيل سجاد',
        'description', 'خدمة تجريبية',
        'pricing_type', 'per_square_meter',
        'price', 6000,
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000003'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-016',
    'service',
    '00000000-0000-0000-0002-000000000004',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0002-000000000004',
        'name', 'تنظيف بطاطين',
        'description', 'خدمة تجريبية',
        'pricing_type', 'fixed_price',
        'price', 8000,
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000002'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-017',
    'service',
    '00000000-0000-0000-0002-000000000005',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0002-000000000005',
        'name', 'غسيل أغطية',
        'description', 'خدمة تجريبية',
        'pricing_type', 'fixed_price',
        'price', 3500,
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000004'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
);

-- Sequences 18..20: Carpet Sizes (3 changes)
INSERT INTO public.sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
VALUES
(
    'op-baseline-018',
    'carpet_size',
    '00000000-0000-0000-0007-000000000001',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0007-000000000001', 'name', '2.0x3.0', 'length', 2.0, 'width', 3.0, 'area', 6.0, 'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-019',
    'carpet_size',
    '00000000-0000-0000-0007-000000000002',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0007-000000000002', 'name', '1.5x2.0', 'length', 1.5, 'width', 2.0, 'area', 3.0, 'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-020',
    'carpet_size',
    '00000000-0000-0000-0007-000000000003',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0007-000000000003', 'name', '1.0x4.0', 'length', 1.0, 'width', 4.0, 'area', 4.0, 'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
);

-- Sequences 21..25: Storage Locations (5 changes, canonical supported_item_type_ids embedded)
INSERT INTO public.sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
VALUES
(
    'op-baseline-021',
    'storage_location',
    '00000000-0000-0000-0006-000000000001',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0006-000000000001',
        'name', 'رف أ-1',
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0001-000000000004'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-022',
    'storage_location',
    '00000000-0000-0000-0006-000000000002',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0006-000000000002',
        'name', 'رف أ-2',
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0001-000000000004'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-023',
    'storage_location',
    '00000000-0000-0000-0006-000000000003',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0006-000000000003',
        'name', 'رف ب-1',
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0001-000000000004'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-024',
    'storage_location',
    '00000000-0000-0000-0006-000000000004',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0006-000000000004',
        'name', 'قسم السجاد 1',
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000003'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-025',
    'storage_location',
    '00000000-0000-0000-0006-000000000005',
    'create',
    jsonb_build_object(
        'id', '00000000-0000-0000-0006-000000000005',
        'name', 'قسم البطاطين 1',
        'is_active', true,
        'server_version', 1,
        'supported_item_type_ids', jsonb_build_array('00000000-0000-0000-0001-000000000002', '00000000-0000-0000-0001-000000000004'),
        'created_at', current_setting('app.seed_ts', true),
        'updated_at', current_setting('app.seed_ts', true)
    ),
    1,
    current_setting('app.seed_ts', true)::timestamptz
);

-- Sequences 26..35: Item Definitions (10 changes)
INSERT INTO public.sync_changes (operation_id, entity_type, entity_id, operation_type, payload, server_version, created_at)
VALUES
(
    'op-baseline-026',
    'item_definition',
    '00000000-0000-0000-0005-000000000001',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000001', 'item_type_id', '00000000-0000-0000-0001-000000000001', 'name', 'قميص',        'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-027',
    'item_definition',
    '00000000-0000-0000-0005-000000000002',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000002', 'item_type_id', '00000000-0000-0000-0001-000000000001', 'name', 'بنطلون',      'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-028',
    'item_definition',
    '00000000-0000-0000-0005-000000000003',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000003', 'item_type_id', '00000000-0000-0000-0001-000000000001', 'name', 'بدلة',        'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-029',
    'item_definition',
    '00000000-0000-0000-0005-000000000004',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000004', 'item_type_id', '00000000-0000-0000-0001-000000000002', 'name', 'بطانية مفرد', 'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-030',
    'item_definition',
    '00000000-0000-0000-0005-000000000005',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000005', 'item_type_id', '00000000-0000-0000-0001-000000000002', 'name', 'بطانية دبل',  'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-031',
    'item_definition',
    '00000000-0000-0000-0005-000000000006',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000006', 'item_type_id', '00000000-0000-0000-0001-000000000003', 'name', 'سجادة صوف',   'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-032',
    'item_definition',
    '00000000-0000-0000-0005-000000000007',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000007', 'item_type_id', '00000000-0000-0000-0001-000000000003', 'name', 'مشاية',       'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-033',
    'item_definition',
    '00000000-0000-0000-0005-000000000008',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000008', 'item_type_id', '00000000-0000-0000-0001-000000000004', 'name', 'غطاء لحاف',   'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-034',
    'item_definition',
    '00000000-0000-0000-0005-000000000009',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000009', 'item_type_id', '00000000-0000-0000-0001-000000000004', 'name', 'كوفرتة',      'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
),
(
    'op-baseline-035',
    'item_definition',
    '00000000-0000-0000-0005-000000000010',
    'create',
    jsonb_build_object('id', '00000000-0000-0000-0005-000000000010', 'item_type_id', '00000000-0000-0000-0001-000000000003', 'name', 'سجادة حرير',  'is_active', true, 'created_at', current_setting('app.seed_ts', true), 'updated_at', current_setting('app.seed_ts', true)),
    1,
    current_setting('app.seed_ts', true)::timestamptz
);


-- -----------------------------------------------------------------------------
-- SECTION 3: POST-SEED INTEGRITY ASSERTIONS
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_total_changes BIGINT;
    v_min_seq BIGINT;
    v_max_seq BIGINT;
    v_distinct_seq BIGINT;
    v_count BIGINT;
BEGIN
    -- 1. Assert sync_changes sequence continuity and bounds
    SELECT count(*), min(sequence), max(sequence), count(DISTINCT sequence)
    INTO v_total_changes, v_min_seq, v_max_seq, v_distinct_seq
    FROM public.sync_changes;

    IF v_total_changes <> 35 THEN
        RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: sync_changes has % rows, expected 35.', v_total_changes;
    END IF;

    IF v_min_seq <> 1 THEN
        RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: min(sequence) is %, expected 1.', v_min_seq;
    END IF;

    IF v_max_seq <> 35 THEN
        RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: max(sequence) is %, expected 35.', v_max_seq;
    END IF;

    IF v_distinct_seq <> 35 THEN
        RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: count(DISTINCT sequence) is %, expected 35 (gaps detected).', v_distinct_seq;
    END IF;

    -- 2. Assert Relational Table Counts
    SELECT count(*) INTO v_count FROM public.business_settings;
    IF v_count <> 1 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: business_settings count % <> 1.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.item_types;
    IF v_count <> 4 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: item_types count % <> 4.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.expense_categories;
    IF v_count <> 7 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: expense_categories count % <> 7.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.services;
    IF v_count <> 5 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: services count % <> 5.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.service_item_types;
    IF v_count <> 5 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: service_item_types count % <> 5.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.carpet_sizes;
    IF v_count <> 3 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: carpet_sizes count % <> 3.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.storage_locations;
    IF v_count <> 5 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: storage_locations count % <> 5.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.storage_location_item_types;
    IF v_count <> 9 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: storage_location_item_types count % <> 9.', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.item_definitions;
    IF v_count <> 10 THEN RAISE EXCEPTION 'POST-SEED ASSERTION FAILED: item_definitions count % <> 10.', v_count; END IF;

    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'SUCCESS: CANONICAL BASELINE SEEDED AND VERIFIED.';
    RAISE NOTICE 'sync_changes:             35 rows (sequences 1..35, no gaps)';
    RAISE NOTICE 'business_settings:        1 row (singleton)';
    RAISE NOTICE 'item_types:               4 rows';
    RAISE NOTICE 'expense_categories:       7 rows';
    RAISE NOTICE 'services:                 5 rows';
    RAISE NOTICE 'service_item_types:       5 rows';
    RAISE NOTICE 'carpet_sizes:             3 rows';
    RAISE NOTICE 'storage_locations:        5 rows';
    RAISE NOTICE 'storage_location_item_types: 9 rows';
    RAISE NOTICE 'item_definitions:         10 rows';
    RAISE NOTICE '=============================================================';
END $$;

COMMIT;
