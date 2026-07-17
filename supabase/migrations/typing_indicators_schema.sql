-- Typing indicator: track who a user is currently typing to
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS typing_with UUID REFERENCES public.profiles(id);

-- Allow users to update their own typing_with field
DROP POLICY IF EXISTS "Users can update their own typing status" ON public.profiles;
CREATE POLICY "Users can update their own typing status" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);
