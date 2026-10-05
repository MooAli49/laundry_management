-- =============================================================================
-- License Info Table
-- File: supabase/migrations/20260930000000_license_info.sql
--
-- PURPOSE:
--   Enables remote license control by the system owner.
--   The client application reads this table via the /api/v1/license Edge
--   Function endpoint (service_role context). The anon role is granted NO
--   direct access — consistent with the project's existing RLS pattern
--   where all client table access goes through Edge Functions.
--
-- ADMIN WORKFLOW:
--   Suspend:
--     UPDATE license_info SET status = 'suspended', suspended_at = now()
--     WHERE id = 'singleton';
--
--   Reinstate:
--     UPDATE license_info SET status = 'active', suspended_at = NULL
--     WHERE id = 'singleton';
--
-- PRODUCTION SAFETY:
--   !! This file is created LOCALLY only. !!
--   !! Do NOT apply automatically. Apply via the Supabase dashboard or CLI !!
--   !! after explicit review and approval.                                  !!
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. License Info Table (singleton row, admin-controlled)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.license_info (
  id           TEXT        PRIMARY KEY DEFAULT 'singleton',
  status       TEXT        NOT NULL DEFAULT 'active'
                           CHECK (status IN ('active', 'suspended')),
  suspended_at TIMESTAMPTZ,   -- Authoritative suspension timestamp (set by admin)
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed the singleton row (idempotent)
INSERT INTO public.license_info (id, status)
VALUES ('singleton', 'active')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. Auto-update updated_at on modification
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_license_info_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_license_info_updated_at
BEFORE UPDATE ON public.license_info
FOR EACH ROW EXECUTE FUNCTION public.set_license_info_updated_at();

-- -----------------------------------------------------------------------------
-- 3. RLS — consistent with the project's existing security model
--    All client reads go through the Edge Function (service_role bypasses RLS).
--    No direct anon or authenticated access is granted.
-- -----------------------------------------------------------------------------
ALTER TABLE public.license_info ENABLE ROW LEVEL SECURITY;

-- Explicit: no INSERT, UPDATE, DELETE, TRUNCATE for anon / authenticated
-- (matches the project-wide REVOKE in 20260926000000_security_hardening.sql)
-- No additional grants needed; service_role bypasses RLS automatically.

-- -----------------------------------------------------------------------------
-- 4. Function privilege — consistent with security hardening pattern
--    The trigger helper function is restricted to service_role only.
-- -----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.set_license_info_updated_at() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.set_license_info_updated_at() TO service_role;
