-- Add missing columns to huddles table
ALTER TABLE public.huddles ADD COLUMN IF NOT EXISTS creator_id UUID REFERENCES public.profiles(id);
ALTER TABLE public.huddles ADD COLUMN IF NOT EXISTS manifesto TEXT;
ALTER TABLE public.huddles ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;

-- Create huddle_join_requests table
CREATE TABLE IF NOT EXISTS public.huddle_join_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  huddle_id UUID REFERENCES public.huddles(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.huddle_join_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view join requests for squads they created or requested" ON public.huddle_join_requests
  FOR SELECT USING (
    auth.uid() = user_id OR 
    EXISTS (
      SELECT 1 FROM public.huddles 
      WHERE huddles.id = huddle_join_requests.huddle_id AND huddles.creator_id = auth.uid()
    )
  );

CREATE POLICY "Users can create join requests" ON public.huddle_join_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Squad creators can update join requests" ON public.huddle_join_requests
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.huddles 
      WHERE huddles.id = huddle_join_requests.huddle_id AND huddles.creator_id = auth.uid()
    )
  );

CREATE POLICY "Users and squad creators can delete join requests" ON public.huddle_join_requests
  FOR DELETE USING (
    auth.uid() = user_id OR 
    EXISTS (
      SELECT 1 FROM public.huddles 
      WHERE huddles.id = huddle_join_requests.huddle_id AND huddles.creator_id = auth.uid()
    )
  );

-- Storage bucket setup for post_images
INSERT INTO storage.buckets (id, name, public)
VALUES ('post_images', 'post_images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for post_images
DROP POLICY IF EXISTS "Public Access to post_images" ON storage.objects;
CREATE POLICY "Public Access to post_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'post_images');

DROP POLICY IF EXISTS "Authenticated users can upload to post_images" ON storage.objects;
CREATE POLICY "Authenticated users can upload to post_images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'post_images' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update their uploads in post_images" ON storage.objects;
CREATE POLICY "Users can update their uploads in post_images" ON storage.objects
  FOR UPDATE USING (bucket_id = 'post_images' AND auth.uid() = owner);

DROP POLICY IF EXISTS "Users can delete their uploads in post_images" ON storage.objects;
CREATE POLICY "Users can delete their uploads in post_images" ON storage.objects
  FOR DELETE USING (bucket_id = 'post_images' AND auth.uid() = owner);
