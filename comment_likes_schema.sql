-- 1. Create Comment Likes Table
create table if not exists public.comment_likes (
  id uuid default gen_random_uuid() primary key,
  comment_id uuid references public.post_comments(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(comment_id, user_id)
);

-- 2. Enable Row Level Security (RLS)
alter table public.comment_likes enable row level security;

-- 3. Create RLS Policies
create policy "Comment likes are viewable by everyone." on public.comment_likes
  for select using (true);

create policy "Users can like comments." on public.comment_likes
  for insert with check (auth.uid() = user_id);

create policy "Users can delete their comment like." on public.comment_likes
  for delete using (auth.uid() = user_id);
