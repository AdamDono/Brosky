-- Add fcm_token column for push notifications to public.profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255);
