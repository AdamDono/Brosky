-- BRO APP DATABASE SCHEMA (PHASE 1)
-- Run this in the Supabase SQL Editor

-- 1. Create a table for public profiles
create table public.profiles (
  id uuid references auth.users not null primary key,
  username text unique,
  avatar_url text,
  bio text,
  vibes text[], -- Array of strings e.g. ['Sports', 'Business']
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. Create policies (Who can see what?)
create policy "Public profiles are viewable by everyone." on public.profiles
  for select using (true);

create policy "Users can insert their own profile." on public.profiles
  for insert with check (auth.uid() = id);

create policy "Users can update own profile." on public.profiles
  for update using (auth.uid() = id);

-- 4. Create the 'Bro Posts' table (The Feed)
create table public.bro_posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  content text not null,
  location_lat float, -- Simple lat/lng for MVP
  location_lng float, 
  image_url text, -- For Vibe Snaps 📸
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. RLS for Posts
alter table public.bro_posts enable row level security;

create policy "Posts are viewable by everyone." on public.bro_posts
  for select using (true);

create policy "Users can create posts." on public.bro_posts
  for insert with check (auth.uid() = user_id);

-- 6. Trigger to automatically create a profile entry when a new user signs up
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, username, bio, vibes)
  values (new.id, new.raw_user_meta_data->>'username', '', '{}');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 7. Create Post Reactions Table
create table public.post_likes (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.bro_posts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  reaction_type text default '👊', -- '👊', '🔥', '💯'
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(post_id, user_id) -- One reaction per user per post
);

alter table public.post_likes enable row level security;

create policy "Reactions are viewable by everyone." on public.post_likes
  for select using (true);

create policy "Users can react to posts." on public.post_likes
  for insert with check (auth.uid() = user_id);

create policy "Users can change/remove their reaction." on public.post_likes
  for update using (auth.uid() = user_id);

create policy "Users can delete their reaction." on public.post_likes
  for delete using (auth.uid() = user_id);

-- 8. Create Post Comments Table
create table if not exists public.post_comments (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.bro_posts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.post_comments enable row level security;

-- Safety: Drop existing policies before creating
drop policy if exists "Comments are viewable by everyone." on public.post_comments;
drop policy if exists "Users can comment on posts." on public.post_comments;
drop policy if exists "Users can delete their own comments." on public.post_comments;

create policy "Comments are viewable by everyone." on public.post_comments
  for select using (true);

create policy "Users can comment on posts." on public.post_comments
  for insert with check (auth.uid() = user_id);

create policy "Users can delete their own comments." on public.post_comments
  for delete using (auth.uid() = user_id);

-- 9. Storage Setup (Bucket)
-- You must create a public bucket named 'post_images' in the Supabase Storage console
-- and allow public access for 'SELECT' and 'INSERT' (for authenticated users).

-- 10. Direct Messages Table
CREATE TABLE IF NOT EXISTS public.direct_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

-- Users can view messages they sent or received
CREATE POLICY "Users can view their own messages" ON public.direct_messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can send messages
CREATE POLICY "Users can send messages" ON public.direct_messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Users can delete their own sent messages
CREATE POLICY "Users can delete their sent messages" ON public.direct_messages
  FOR DELETE USING (auth.uid() = sender_id);

-- 11. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'post_reaction', 'post_comment', 'huddle_invite', 'new_follower', 'direct_message'
  reference_id UUID, -- ID of the related post, comment, huddle, etc.
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can view their own notifications
CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- System can create notifications (this will be handled by triggers or backend)
CREATE POLICY "Authenticated users can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- 12. Add policies for updating and deleting posts
CREATE POLICY "Users can update their own posts." ON public.bro_posts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own posts." ON public.bro_posts
  FOR DELETE USING (auth.uid() = user_id);

-- 13. Add 'vibe' column if it doesn't exist
ALTER TABLE public.bro_posts ADD COLUMN IF NOT EXISTS vibe TEXT DEFAULT 'General';
