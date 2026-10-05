-- =============================================================================
-- Production Hardening — Supabase Security Hardening
-- File: supabase/migrations/20260926000000_security_hardening.sql
--
-- 1. Explicit search_path hardening on all 26 public SECURITY DEFINER functions
--    to prevent search_path manipulation attacks (remediating lint 0011).
-- 2. Revoke EXECUTE on all 26 functions from PUBLIC, anon, and authenticated
--    to prevent unauthenticated/direct PostgREST RPC access (remediating lints 0028 & 0029).
-- 3. Grant EXECUTE exclusively to service_role (and postgres by default as owner),
--    preserving Edge Function execution boundary.
-- 4. Revoke direct DML privileges (INSERT, UPDATE, DELETE, TRUNCATE) on all public
--    tables from anon and authenticated roles as defense-in-depth.
-- 5. Configure default privileges for future functions and tables.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SEARCH_PATH HARDENING (Fix mutable search_path on all SECURITY DEFINER RPCs)
-- -----------------------------------------------------------------------------
ALTER FUNCTION public.check_idempotency(text) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_sync_changes(bigint, integer) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_carpet_size(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_customer(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_expense(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_expense_category(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_item_definition(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_item_type(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_order_aggregate(text, jsonb, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_payment(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_refund(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_service(text, jsonb, text[]) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_storage_location(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_create_storage_record(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_business_settings(text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_carpet_size(text, text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_customer(text, uuid, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_expense(text, text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_expense_category(text, text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_item_definition(text, text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_item_type(text, text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_order(text, uuid, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_order_aggregate(text, uuid, jsonb, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_service(text, uuid, jsonb, text[]) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_storage_location(text, text, jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_update_storage_record(text, uuid, jsonb) SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- 2. FUNCTION PRIVILEGE HARDENING (Restrict RPC invocation to Edge Functions)
-- -----------------------------------------------------------------------------
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- -----------------------------------------------------------------------------
-- 3. TABLE PRIVILEGE HARDENING (Defense-in-depth against direct client mutations)
-- -----------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. FUTURE DEFAULT PRIVILEGES (Maintain secure defaults for newly created objects)
-- -----------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM anon, authenticated;
