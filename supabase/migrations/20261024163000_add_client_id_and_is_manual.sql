-- Migration: Add client_id (uniqueness for offline-first upsert) and is_manual to public.rides

-- Add client_id column with unique constraint for deduplication on upsert
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS client_id text;

-- Backfill existing rows with a generated client_id so the NOT NULL constraint can be applied
UPDATE public.rides SET client_id = 'legacy_' || id::text WHERE client_id IS NULL;

-- Now enforce NOT NULL and add unique constraint
ALTER TABLE public.rides ALTER COLUMN client_id SET NOT NULL;
ALTER TABLE public.rides ADD CONSTRAINT rides_client_id_unique UNIQUE (client_id);

-- Add is_manual flag for manually entered rides
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS is_manual boolean NOT NULL DEFAULT false;
