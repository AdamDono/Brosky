-- 1. Add reaction column to direct_messages table
ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS reaction TEXT;

-- 2. Add update security policy for direct_messages
DROP POLICY IF EXISTS "Users can update reactions on messages" ON public.direct_messages;
CREATE POLICY "Users can update reactions on messages" ON public.direct_messages
  FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
