-- Spiritbound — client_events table (Docs/LAUNCH_READINESS.md Section 3)
-- Crash/error logging + minimal analytics, inserted by the Godot client over PostgREST.
--
-- Run this once in the Supabase SQL editor (or `supabase db execute -f Docs/sql/2026_client_events.sql`).
-- This CANNOT be created from the Godot client — the anon key has no DDL rights by design.
--
-- RLS shape, deliberately: INSERT-only for clients, and NO select/update/delete policy at all.
-- Nothing in the client ever needs to read its own past events back, so read access is denied
-- by default (RLS with no matching policy = the operation is refused). Whoever debugs this data
-- reads it from the Supabase dashboard / service-role, not from a shipped build.

create table if not exists public.client_events (
    id          bigint generated always as identity primary key,
    user_id     uuid        null,                                  -- null for guests / pre-sign-in events
    kind        text        not null check (kind in ('error', 'event')),
    name        text        not null,
    detail      jsonb       not null default '{}'::jsonb,
    app_version text        null,
    platform    text        null,
    created_at  timestamptz not null default now()
);

alter table public.client_events enable row level security;

-- Insert-only: anonymous and authenticated clients may append a row. `with check (true)` is
-- intentional — a guest has no user_id, and a client cannot be trusted to self-restrict anyway;
-- the table's own value is aggregate funnel/crash data, not user-owned rows.
drop policy if exists "client_events_insert_any" on public.client_events;
create policy "client_events_insert_any"
    on public.client_events
    for insert
    to anon, authenticated
    with check (true);

-- No SELECT / UPDATE / DELETE policies are defined on purpose: RLS denies those by default,
-- so no shipped build can read, rewrite, or wipe the event log.

create index if not exists client_events_created_at_idx on public.client_events (created_at desc);
create index if not exists client_events_name_idx       on public.client_events (name);
create index if not exists client_events_kind_idx       on public.client_events (kind);
