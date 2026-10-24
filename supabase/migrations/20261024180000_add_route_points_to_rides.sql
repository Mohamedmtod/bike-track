-- Migration: Add route_points JSONB column to public.rides for storing polyline coordinates
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS route_points JSONB NOT NULL DEFAULT '[]'::jsonb;
