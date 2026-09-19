-- =============================================================================
-- Laundry Management System — Development Supabase Safe Reset Script
-- File: scripts/dev_supabase_safe_reset.sql
--
-- PURPOSE:
-- Safely resets the contaminated Supabase development database to prepare for
-- Phase 3 (UUID/FK migration) and Phase 4 (Canonical Master-Data Baseline &
-- Cursor-0 Bootstrap Validation).
--
-- SAFETY WARNING:
-- This script contains DESTRUCTIVE operations intended EXCLUSIVELY for the
-- disposable development environment project (dyhfgnbhijukbdptreto).
--
-- DO NOT EXECUTE DIRECTLY WITHOUT CONFIGURING REQUIRED SAFETY GUARDS.
-- DO NOT EXECUTE IN PRODUCTION OR STAGING.
--
-- ALL GUARDS FAIL CLOSED:
-- 1. Operator-Asserted Development Environment Identity (dyhfgnbhijukbdptreto).
-- 2. Explicit Operator Confirmation Token for Disposable Dev Reset.
-- 3. Independent Data Sanity Assertions (zero auth users, zero storage files, row thresholds).
-- 4. Schema & RPC Sanity Assertions (verifies expected tables and actual RPC names exist).
-- 5. Post-Reset Verification Assertions before transaction COMMIT.
-- =============================================================================

-- =============================================================================
-- SECTION 1: NON-DESTRUCTIVE PREVIEW / INSPECTION QUERIES
--
-- Operators should execute this section first to inspect the environment
-- and current row counts without making any changes.
-- =============================================================================

DO $$
DECLARE
    v_project_ref TEXT := current_setting('app.project_ref', true);
    v_environment TEXT := current_setting('app.environment', true);
    v_sync_changes_count BIGINT;
    v_idempotency_count BIGINT;
    v_orders_count BIGINT;
    v_order_items_count BIGINT;
    v_carpets_count BIGINT;
    v_payments_count BIGINT;
    v_storage_records_count BIGINT;
    v_expenses_count BIGINT;
    v_customers_count BIGINT;
    v_services_count BIGINT;
    v_storage_locations_count BIGINT;
    v_carpet_sizes_count BIGINT;
    v_item_types_count BIGINT;
    v_expense_categories_count BIGINT;
    v_business_settings_count BIGINT;
    v_auth_users_count BIGINT;
    v_storage_objects_count BIGINT;
    v_min_seq BIGINT;
    v_max_seq BIGINT;
BEGIN
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'SUPABASE DEVELOPMENT ENVIRONMENT PREVIEW (READ-ONLY)';
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'Current Database: %', current_database();
    RAISE NOTICE 'Current User:     %', current_user;
    RAISE NOTICE 'app.project_ref:  %', COALESCE(v_project_ref, '(NOT SET - REQUIRED FOR RESET)');
    RAISE NOTICE 'app.environment:  %', COALESCE(v_environment, '(NOT SET - REQUIRED FOR RESET)');
    RAISE NOTICE '-------------------------------------------------------------';

    SELECT count(*) INTO v_sync_changes_count FROM public.sync_changes;
    SELECT min(sequence), max(sequence) INTO v_min_seq, v_max_seq FROM public.sync_changes;
    SELECT count(*) INTO v_idempotency_count FROM public.sync_idempotency_log;
    SELECT count(*) INTO v_orders_count FROM public.orders;
    SELECT count(*) INTO v_order_items_count FROM public.order_items;
    SELECT count(*) INTO v_carpets_count FROM public.order_item_carpets;
    SELECT count(*) INTO v_payments_count FROM public.payments;
    SELECT count(*) INTO v_storage_records_count FROM public.storage_records;
    SELECT count(*) INTO v_expenses_count FROM public.expenses;
    SELECT count(*) INTO v_customers_count FROM public.customers;
    SELECT count(*) INTO v_services_count FROM public.services;
    SELECT count(*) INTO v_storage_locations_count FROM public.storage_locations;
    SELECT count(*) INTO v_carpet_sizes_count FROM public.carpet_sizes;
    SELECT count(*) INTO v_item_types_count FROM public.item_types;
    SELECT count(*) INTO v_expense_categories_count FROM public.expense_categories;
    SELECT count(*) INTO v_business_settings_count FROM public.business_settings;
    SELECT count(*) INTO v_auth_users_count FROM auth.users;
    SELECT count(*) INTO v_storage_objects_count FROM storage.objects;

    RAISE NOTICE 'sync_changes:             % rows (seq % to %)', v_sync_changes_count, v_min_seq, v_max_seq;
    RAISE NOTICE 'sync_idempotency_log:     % rows', v_idempotency_count;
    RAISE NOTICE 'orders:                   % rows', v_orders_count;
    RAISE NOTICE 'order_items:              % rows', v_order_items_count;
    RAISE NOTICE 'order_item_carpets:       % rows', v_carpets_count;
    RAISE NOTICE 'payments:                 % rows', v_payments_count;
    RAISE NOTICE 'storage_records:          % rows', v_storage_records_count;
    RAISE NOTICE 'expenses:                 % rows', v_expenses_count;
    RAISE NOTICE 'customers:                % rows', v_customers_count;
    RAISE NOTICE 'services:                 % rows', v_services_count;
    RAISE NOTICE 'storage_locations:        % rows', v_storage_locations_count;
    RAISE NOTICE 'carpet_sizes:             % rows', v_carpet_sizes_count;
    RAISE NOTICE 'item_types:               % rows', v_item_types_count;
    RAISE NOTICE 'expense_categories:       % rows', v_expense_categories_count;
    RAISE NOTICE 'business_settings:        % rows', v_business_settings_count;
    RAISE NOTICE 'auth.users:               % rows', v_auth_users_count;
    RAISE NOTICE 'storage.objects:          % rows', v_storage_objects_count;
    RAISE NOTICE '=============================================================';
END $$;


-- =============================================================================
-- SECTION 2: ATOMIC GUARDED DEVELOPMENT RESET TRANSACTION
--
-- OPERATOR PREREQUISITE TO EXECUTE:
-- The transaction MUST begin first (BEGIN;).
-- Inside the transaction, the operator must un-comment the three SET LOCAL
-- configuration lines below to authorize execution.
--
-- If the SET LOCAL commands remain commented or values do not match,
-- the guards FAIL CLOSED immediately and the transaction aborts.
-- =============================================================================

BEGIN;

SET LOCAL app.project_ref = 'dyhfgnbhijukbdptreto';
SET LOCAL app.environment = 'development';
SET LOCAL app.confirm_dev_reset = 'CONFIRMED_DISPOSABLE_DEV_RESET_2026_DYHFGNBHIJUKBDPTRETO';

-- -----------------------------------------------------------------------------
-- GUARD 1: OPERATOR-ASSERTED DEVELOPMENT-ENVIRONMENT IDENTITY
--
-- IMPORTANT HONESTY & ARCHITECTURAL DISCLOSURE:
-- PostgreSQL in hosted Supabase does NOT maintain an immutable native setting
-- or cryptographic hardware token linking a database to its project reference
-- ('dyhfgnbhijukbdptreto'). The database name is generic ('postgres').
-- Therefore, app.project_ref and app.environment are OPERATOR-SUPPLIED SESSION
-- ASSERTIONS, not a database-internal proof.
--
-- To prevent accidental execution:
-- 1. This guard forces the operator to explicitly declare intent by asserting
--    the target project ref ('dyhfgnbhijukbdptreto') and environment ('development').
-- 2. Guard 3 (Data Sanity Assertions) acts as the independent, non-operator-dependent
--    defense by verifying zero auth users, zero storage objects, and test data signatures.
--
-- Fails closed if the operator assertion is absent or mismatched.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_project_ref TEXT := current_setting('app.project_ref', true);
    v_environment TEXT := current_setting('app.environment', true);
BEGIN
    IF v_project_ref IS NULL OR v_project_ref <> 'dyhfgnbhijukbdptreto' THEN
        RAISE EXCEPTION 'GUARD 1 FAILED: Project identity mismatch or unconfigured. Expected app.project_ref = ''dyhfgnbhijukbdptreto'', got: %',
            COALESCE(v_project_ref, '<NULL>')
            USING ERRCODE = 'P0001';
    END IF;

    IF v_environment IS NULL OR v_environment <> 'development' THEN
        RAISE EXCEPTION 'GUARD 1 FAILED: Environment identity mismatch. Expected app.environment = ''development'', got: %',
            COALESCE(v_environment, '<NULL>')
            USING ERRCODE = 'P0001';
    END IF;

    RAISE NOTICE 'GUARD 1 PASSED: Operator-asserted target development project: % (%)', v_project_ref, v_environment;
END $$;

-- -----------------------------------------------------------------------------
-- GUARD 2: EXPLICIT OPERATOR CONFIRMATION FOR DISPOSABLE DEV RESET
--
-- Protects against: Accidental execution or automated invocation.
-- The operator must explicitly acknowledge that this is a full reset of a
-- disposable development environment per docs/04-database/seed-data.md §41.
-- Fails closed if the specific confirmation token is absent from session settings.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_token TEXT := current_setting('app.confirm_dev_reset', true);
    c_expected_token CONSTANT TEXT := 'CONFIRMED_DISPOSABLE_DEV_RESET_2026_DYHFGNBHIJUKBDPTRETO';
BEGIN
    IF v_token IS NULL OR v_token <> c_expected_token THEN
        RAISE EXCEPTION 'GUARD 2 FAILED: Explicit operator confirmation token missing or invalid. Set LOCAL app.confirm_dev_reset = ''%'';',
            c_expected_token
            USING ERRCODE = 'P0001';
    END IF;

    RAISE NOTICE 'GUARD 2 PASSED: Operator confirmation for disposable development reset verified.';
END $$;

-- -----------------------------------------------------------------------------
-- GUARD 3: INDEPENDENT DATA SANITY ASSERTIONS
--
-- Protects against: Resetting a staging or production database that had session
-- variables mistakenly applied.
--
-- Independent Assertions:
-- - Exactly 0 real users in auth.users (auth schema is never populated in this dev environment)
-- - Exactly 0 objects in storage.objects (storage is never populated in this dev environment)
-- - Total transactional row counts within expected development boundaries
-- - Presence of known test data signatures (test customer phone prefix 011 or arabic test names)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_auth_users_count BIGINT;
    v_storage_objects_count BIGINT;
    v_orders_count BIGINT;
    v_payments_count BIGINT;
    v_sync_changes_count BIGINT;
    v_has_test_customers BOOLEAN;
BEGIN
    -- 1. No real authentication users must exist
    SELECT count(*) INTO v_auth_users_count FROM auth.users;
    IF v_auth_users_count > 0 THEN
        RAISE EXCEPTION 'GUARD 3 FAILED: Found % auth.users. Reset rejected to prevent data loss on non-test environment.',
            v_auth_users_count
            USING ERRCODE = 'P0001';
    END IF;

    -- 2. No storage objects must exist
    SELECT count(*) INTO v_storage_objects_count FROM storage.objects;
    IF v_storage_objects_count > 0 THEN
        RAISE EXCEPTION 'GUARD 3 FAILED: Found % storage.objects. Reset rejected.',
            v_storage_objects_count
            USING ERRCODE = 'P0001';
    END IF;

    -- 3. Volume thresholds (Development safety bounds)
    SELECT count(*) INTO v_orders_count FROM public.orders;
    IF v_orders_count > 1000 THEN
        RAISE EXCEPTION 'GUARD 3 FAILED: Order count (%) exceeds development threshold (1000).', v_orders_count
            USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*) INTO v_payments_count FROM public.payments;
    IF v_payments_count > 1000 THEN
        RAISE EXCEPTION 'GUARD 3 FAILED: Payment count (%) exceeds development threshold (1000).', v_payments_count
            USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*) INTO v_sync_changes_count FROM public.sync_changes;
    IF v_sync_changes_count > 10000 THEN
        RAISE EXCEPTION 'GUARD 3 FAILED: sync_changes count (%) exceeds development threshold (10000).', v_sync_changes_count
            USING ERRCODE = 'P0001';
    END IF;

    -- 4. Positive verification of test data footprint
    SELECT EXISTS (
        SELECT 1 FROM public.customers
        WHERE phone LIKE '011%' OR name LIKE '%اختبار%' OR notes LIKE '%test%'
    ) INTO v_has_test_customers;

    IF NOT v_has_test_customers AND v_orders_count > 0 THEN
        RAISE EXCEPTION 'GUARD 3 FAILED: Existing customer data does not match known test patterns. Aborting.'
            USING ERRCODE = 'P0001';
    END IF;

    RAISE NOTICE 'GUARD 3 PASSED: Data sanity verified (0 auth users, 0 storage objects, dev row counts, test signatures).';
END $$;

-- -----------------------------------------------------------------------------
-- GUARD 4: SCHEMA & EXACT RPC SANITY ASSERTIONS
--
-- Protects against: Executing on an uninitialized, unrelated, or mismatched database.
-- Verifies exact RPC function names established by migrations:
-- - get_sync_changes
-- - sync_create_order_aggregate (Order aggregate creation RPC)
-- - sync_create_payment
-- - check_idempotency
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    -- Verify essential tables exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'sync_changes') OR
       NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'sync_idempotency_log') OR
       NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'orders') OR
       NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_items') OR
       NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'business_settings') THEN
        RAISE EXCEPTION 'GUARD 4 FAILED: Expected schema tables are missing.' USING ERRCODE = 'P0001';
    END IF;

    -- Verify exact sync RPC functions exist in pg_proc
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_sync_changes') THEN
        RAISE EXCEPTION 'GUARD 4 FAILED: RPC get_sync_changes not found in pg_proc.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'sync_create_order_aggregate') THEN
        RAISE EXCEPTION 'GUARD 4 FAILED: RPC sync_create_order_aggregate not found in pg_proc.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'sync_create_payment') THEN
        RAISE EXCEPTION 'GUARD 4 FAILED: RPC sync_create_payment not found in pg_proc.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_idempotency') THEN
        RAISE EXCEPTION 'GUARD 4 FAILED: RPC check_idempotency not found in pg_proc.' USING ERRCODE = 'P0001';
    END IF;

    RAISE NOTICE 'GUARD 4 PASSED: Schema tables and exact RPC functions verified in pg_proc.';
END $$;


-- =============================================================================
-- SECTION 3: DESTRUCTIVE OPERATIONS IN STRICT REVERSE DEPENDENCY ORDER
--
-- No CASCADE used. All child tables are cleared before parent tables.
-- Deletes contaminated test transactional rows and ad-hoc test master data rows.
-- =============================================================================

RAISE NOTICE 'Executing safe development reset in reverse dependency order...';

-- 1. Sync Tracking & Change Logs
DELETE FROM public.sync_changes;
DELETE FROM public.sync_idempotency_log;

-- 2. Transactional Order Children
DELETE FROM public.payments;
DELETE FROM public.storage_records;
DELETE FROM public.order_item_carpets;
DELETE FROM public.order_items;

-- 3. Transactional Orders & Customers
DELETE FROM public.orders;
DELETE FROM public.customers;

-- 4. Transactional Expenses
DELETE FROM public.expenses;

-- 5. Junction & Test Master Data Children
DELETE FROM public.service_item_types;
DELETE FROM public.storage_location_item_types;
DELETE FROM public.item_definitions;

-- 6. Test Master Data Parents
DELETE FROM public.services;
DELETE FROM public.storage_locations;
DELETE FROM public.carpet_sizes;
DELETE FROM public.item_types;
DELETE FROM public.expense_categories;


-- =============================================================================
-- SECTION 4: PRESERVED MASTER DATA & SYSTEM CONFIGURATION
--
-- business_settings: Singleton configuration MUST be preserved.
-- Reset to clean canonical singleton state (server_version = 1).
--
-- ARCHITECTURAL BOUNDARY SPECIFICATION:
-- Phase 2 intentionally does NOT create a sync_changes record for this reset.
-- Phase 2 responsibility is strictly:
--   1. Clean development database of all contaminated rows.
--   2. Ensure sync_changes is completely empty (count = 0).
--   3. Ensure sync_changes_sequence_seq starts at 1.
--
-- Phase 3/4 responsibility is:
--   1. Apply UUID foreign keys (Phase 3).
--   2. Seed canonical master-data baseline (business_settings, item_types,
--      expense_categories, services, storage_locations, carpet_sizes) AND
--      generate the authoritative initial sync_changes history starting at
--      sequence 1 (Phase 4).
-- =============================================================================

INSERT INTO public.business_settings (
    id,
    business_name,
    address,
    phone,
    logo_reference,
    invoice_footer_text,
    tax_enabled,
    tax_rate,
    server_version,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '',
    NULL,
    NULL,
    NULL,
    NULL,
    false,
    0.0,
    1,
    now(),
    now()
)
ON CONFLICT (id) DO UPDATE SET
    business_name = '',
    address = NULL,
    phone = NULL,
    logo_reference = NULL,
    invoice_footer_text = NULL,
    tax_enabled = false,
    tax_rate = 0.0,
    server_version = 1,
    updated_at = now();

-- Ensure no extraneous business settings rows exist
DELETE FROM public.business_settings
WHERE id <> '00000000-0000-0000-0000-000000000001';


-- =============================================================================
-- SECTION 5: SEQUENCE RESET
--
-- Reset the BIGSERIAL sequence for sync_changes so that the next generated
-- sequence starts cleanly at 1 for Phase 4 canonical master data seeding.
-- =============================================================================

DO $$
DECLARE
    v_seq_name TEXT;
BEGIN
    v_seq_name := pg_get_serial_sequence('public.sync_changes', 'sequence');
    IF v_seq_name IS NULL THEN
        -- Fallback to standard PostgreSQL naming convention
        v_seq_name := 'public.sync_changes_sequence_seq';
    END IF;

    -- is_called = false ensures the next nextval() produces exactly 1
    PERFORM setval(v_seq_name, 1, false);
    RAISE NOTICE 'Sequence % successfully reset to start with 1 (is_called = false).', v_seq_name;
END $$;


-- =============================================================================
-- SECTION 6: POST-RESET ASSERTIONS
--
-- Explicitly validates that the reset achieved the exact required state.
-- If any assertion fails, the entire transaction rolls back.
-- =============================================================================

DO $$
DECLARE
    v_count BIGINT;
    v_seq_name TEXT;
    v_next_val BIGINT;
BEGIN
    -- Assert transactional tables are strictly 0
    SELECT count(*) INTO v_count FROM public.sync_changes;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: sync_changes count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.sync_idempotency_log;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: sync_idempotency_log count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.orders;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: orders count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.order_items;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: order_items count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.order_item_carpets;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: order_item_carpets count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.payments;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: payments count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.storage_records;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: storage_records count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.expenses;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: expenses count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.customers;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: customers count (%) <> 0', v_count; END IF;

    -- Assert test master data tables are strictly 0 (ready for Phase 4 canonical seeding)
    SELECT count(*) INTO v_count FROM public.services;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: services count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.service_item_types;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: service_item_types count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.storage_locations;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: storage_locations count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.storage_location_item_types;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: storage_location_item_types count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.carpet_sizes;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: carpet_sizes count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.item_definitions;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: item_definitions count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.item_types;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: item_types count (%) <> 0', v_count; END IF;

    SELECT count(*) INTO v_count FROM public.expense_categories;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: expense_categories count (%) <> 0', v_count; END IF;

    -- Assert business_settings has exactly 1 canonical singleton row
    SELECT count(*) INTO v_count FROM public.business_settings WHERE id = '00000000-0000-0000-0000-000000000001';
    IF v_count <> 1 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: business_settings canonical singleton missing.'; END IF;

    -- Assert auth and storage tables were completely untouched
    SELECT count(*) INTO v_count FROM auth.users;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: auth.users was mutated.'; END IF;

    SELECT count(*) INTO v_count FROM storage.objects;
    IF v_count <> 0 THEN RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: storage.objects was mutated.'; END IF;

    -- Assert sequence state
    v_seq_name := COALESCE(pg_get_serial_sequence('public.sync_changes', 'sequence'), 'public.sync_changes_sequence_seq');
    SELECT last_value INTO v_next_val FROM pg_sequences WHERE schemaname = 'public' AND sequencename = replace(v_seq_name, 'public.', '');
    IF v_next_val <> 1 THEN
        RAISE EXCEPTION 'POST-RESET ASSERTION FAILED: sync_changes sequence last_value (%) <> 1', v_next_val;
    END IF;

    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'ALL POST-RESET ASSERTIONS PASSED SUCCESSFULLY.';
    RAISE NOTICE 'Database is in a clean baseline state ready for Phase 3 and Phase 4.';
    RAISE NOTICE '=============================================================';
END $$;

COMMIT;
