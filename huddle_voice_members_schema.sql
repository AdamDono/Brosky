-- 1. Create Huddle Voice Members Table
create table if not exists public.huddle_voice_members (
  id uuid default gen_random_uuid() primary key,
  huddle_id uuid references public.huddles(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(huddle_id, user_id)
);

-- 2. Enable Row Level Security (RLS)
alter table public.huddle_voice_members enable row level security;

-- 3. Create RLS Policies
create policy "Voice members are viewable by everyone." on public.huddle_voice_members
  for select using (true);

create policy "Users can join huddle voice." on public.huddle_voice_members
  for insert with check (auth.uid() = user_id);

-- 4. Allow any authenticated user to clean up voice presence on disconnect
create policy "Users can leave huddle voice." on public.huddle_voice_members
  for delete using (auth.uid() = user_id);
