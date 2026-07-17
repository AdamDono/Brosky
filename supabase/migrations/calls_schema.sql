-- 1. Add missing UPDATE policy for direct_messages so receivers can mark messages as read
DROP POLICY IF EXISTS "Users can update messages they received" ON public.direct_messages;
CREATE POLICY "Users can update messages they received" ON public.direct_messages
  FOR UPDATE USING (auth.uid() = receiver_id);

-- 2. Create calls table for real-time signaling
CREATE TABLE IF NOT EXISTS public.calls (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  caller_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  room_id TEXT NOT NULL,
  status TEXT DEFAULT 'connecting' NOT NULL, -- 'connecting', 'ringing', 'answered', 'rejected', 'ended'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Enable RLS on calls
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies for calls table
CREATE POLICY "Users can view their calls" ON public.calls
  FOR SELECT USING (auth.uid() = caller_id OR auth.uid() = receiver_id);
  
CREATE POLICY "Users can create calls" ON public.calls
  FOR INSERT WITH CHECK (auth.uid() = caller_id);
  
CREATE POLICY "Users can update their calls" ON public.calls
  FOR UPDATE USING (auth.uid() = caller_id OR auth.uid() = receiver_id);
  
  
CREATE POLICY "Users can delete their calls" ON public.calls
  FOR DELETE USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

-- 5. Enable Realtime replication for calls and direct_messages tables in Supabase
ALTER TABLE public.calls REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;

-- If direct_messages doesn't update in the background, run these too:
-- ALTER TABLE public.direct_messages REPLICA IDENTITY FULL;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;

