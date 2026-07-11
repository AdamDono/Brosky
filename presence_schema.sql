-- 1. Add last_seen_at column to public.profiles if not exists
alter table public.profiles add column if not exists last_seen_at timestamp with time zone;
