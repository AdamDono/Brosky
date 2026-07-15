-- Add soft-delete flag to direct_messages
ALTER TABLE public.direct_messages 
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;
