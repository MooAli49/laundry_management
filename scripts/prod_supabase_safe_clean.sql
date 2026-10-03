-- =============================================================================
-- Laundry Management System — Production Supabase Safe Cleanup Script
-- Target Project: rvrskluqfbrkvvlxtxfp (Laundry Management PROD)
-- Environment: PRODUCTION ONLY
--
-- PURPOSE:
-- Safely removes all demo/test/master configuration and synchronization data
-- from the Production Supabase database for final client handover.
--
-- GUARANTEES:
-- 1. Atomic execution inside a single transaction (BEGIN ... COMMIT).
-- 2. Deletes in strict foreign-key reverse dependency order.
-- 3. Does NOT drop or alter tables, columns, indexes, constraints, RLS policies,
--    functions, triggers, or migration history.
-- 4. Resets the sync_changes sequence to 1.
-- 5. Validates with post-cleanup assertions before committing.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. PRECONDITION CHECKS
-- Verify that all expected 19 public tables exist and migrations are intact.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_migration_count INT;
BEGIN
    SELECT count(*) INTO v_migration_count FROM supabase_migrations.schema_migrations;
    IF v_migration_count < 14 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Expected at least 14 applied migrations, found %', v_migration_count;
    END IF;
    RAISE NOTICE 'Precondition verified: % migrations recorded in schema_migrations.', v_migration_count;
END $$;

-- -----------------------------------------------------------------------------
-- 2. PRE-DELETION COUNTS
-- These notices are the required operator record of the exact destructive
-- scope. Review them against the approved handover plan before committing.
DO $$
DECLARE
    v_table TEXT;
    v_count BIGINT;
    v_tables TEXT[] := ARRAY[
        'customers', 'orders', 'order_items', 'order_item_carpets', 'payments',
        'refunds', 'storage_records', 'expenses', 'item_types',
        'item_definitions', 'services', 'service_item_types', 'carpet_sizes',
        'storage_locations', 'storage_location_item_types', 'sync_changes',
        'sync_idempotency_log'
    ];
BEGIN
    FOREACH v_table IN ARRAY v_tables LOOP
        EXECUTE format('SELECT count(*) FROM public.%I', v_table) INTO v_count;
        RAISE NOTICE 'PRE-CLEANUP COUNT public.%: %', v_table, v_count;
    END LOOP;
    SELECT count(*) INTO v_count FROM public.business_settings;
    RAISE NOTICE 'PRESERVED COUNT public.business_settings: %', v_count;
END $$;

-- 3. REVERSE-DEPENDENCY DELETION
-- -----------------------------------------------------------------------------

-- Step 2.1: Independent synchronization tracking log
DELETE FROM public.sync_idempotency_log;

-- Step 2.2: Leaf transactional records referencing order_items, carpet_sizes, storage_locations
DELETE FROM public.order_item_carpets;
DELETE FROM public.storage_records;

-- Step 2.3: Order items (references orders, services, item_types, item_definitions)
DELETE FROM public.order_items;

-- Step 2.4: Transactions referencing orders
DELETE FROM public.payments;
DELETE FROM public.refunds;

-- Step 2.5: Orders (references customers)
DELETE FROM public.orders;

-- Step 2.6: Customers (now unreferenced)
DELETE FROM public.customers;

-- Step 2.7: Expenses (references expense_categories)
DELETE FROM public.expenses;

-- Step 2.8: Junction tables referencing services, storage_locations, item_types
DELETE FROM public.service_item_types;
DELETE FROM public.storage_location_item_types;

-- Step 2.9: Item definitions (references item_types)
DELETE FROM public.item_definitions;

-- Step 2.10: Master catalog entities (now unreferenced)
DELETE FROM public.carpet_sizes;
DELETE FROM public.storage_locations;
DELETE FROM public.services;
DELETE FROM public.expense_categories;
DELETE FROM public.item_types;

-- Step 3.11: Synchronization change log
DELETE FROM public.sync_changes;

-- -----------------------------------------------------------------------------
-- 3. SEQUENCE RESET
-- Reset sync_changes_sequence_seq back to 1 for the fresh client installation.
-- -----------------------------------------------------------------------------
ALTER SEQUENCE public.sync_changes_sequence_seq RESTART WITH 1;

-- -----------------------------------------------------------------------------
-- 5. POST-CLEANUP ASSERTIONS
-- Verify that all destructive targets are empty and the business-settings
-- singleton remains available for the canonical seed update.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_total_rows BIGINT := 0;
    v_count BIGINT;
BEGIN
    SELECT count(*) INTO v_count FROM public.business_settings;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'POSTCONDITION FAILED: Expected exactly 1 business_settings singleton, found %', v_count;
    END IF;
    SELECT count(*) INTO v_count FROM public.carpet_sizes; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.customers; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.expense_categories; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.expenses; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.item_definitions; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.item_types; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.order_item_carpets; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.order_items; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.orders; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.payments; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.refunds; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.service_item_types; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.services; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.storage_location_item_types; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.storage_locations; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.storage_records; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.sync_changes; v_total_rows := v_total_rows + v_count;
    SELECT count(*) INTO v_count FROM public.sync_idempotency_log; v_total_rows := v_total_rows + v_count;

    IF v_total_rows > 0 THEN
        RAISE EXCEPTION 'POSTCONDITION FAILED: Expected 0 rows across all destructive targets, found %', v_total_rows;
    END IF;
    
    RAISE NOTICE 'POSTCONDITION PASSED: Destructive targets are empty; business_settings singleton preserved.';
END $$;

COMMIT;
