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
