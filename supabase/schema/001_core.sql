-- =====================================================
-- Loop Breaker v1 — Core Schema
-- Invariant: Daily deck must never be empty
-- =====================================================

create extension if not exists "pgcrypto";

-- =====================
-- User profile (auth via Supabase)
-- =====================
create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- =====================
-- Loops (habits)
-- =====================
create table if not exists public.loops (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,

  title text not null,
  description text,
  difficulty int not null default 1 check (difficulty >= 1),

  is_system boolean not null default false,
  is_active boolean not null default true,

  preferred_start_min int,
  preferred_end_min int,

  created_at timestamptz not null default now()
);

create index if not exists loops_user_active_idx
  on public.loops (user_id)
  where is_active = true;

-- =====================
-- Action history (data-only, no punishment)
-- =====================
create table if not exists public.action_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  loop_id uuid references public.loops(id) on delete cascade,

  action_type text not null check (action_type in ('complete','postpone','fail')),
  difficulty int not null,

  created_at timestamptz not null default now()
);

create index if not exists action_history_user_time_idx
  on public.action_history (user_id, created_at desc);

-- =====================
-- SYSTEM FALLBACK LOOP (NON-EMPTY INVARIANT)
-- =====================
insert into public.loops (
  id,
  user_id,
  title,
  description,
  difficulty,
  is_system,
  is_active
)
select
  '00000000-0000-0000-0000-000000000001',
  null,
  'Open Loop Breaker',
  'Showing up counts.',
  1,
  true,
  true
where not exists (
  select 1 from public.loops where is_system = true
);
