-- =============================================================================
-- Phase C3 — Supabase Realtime Publication for sync_changes
-- Laundry Management System — Realtime Wake-Up Signal Foundation
-- =============================================================================

-- Adds public.sync_changes to supabase_realtime publication idempotently.
-- Safe to execute on both fresh and pre-existing environments.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'sync_changes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.sync_changes;
  END IF;
END $$;
