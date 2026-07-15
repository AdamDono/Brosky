-- Add human-readable location label to bro_posts
ALTER TABLE public.bro_posts 
  ADD COLUMN IF NOT EXISTS location_label TEXT;
