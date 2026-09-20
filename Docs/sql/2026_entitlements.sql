-- Spiritbound — entitlements table (Docs/LAUNCH_READINESS.md Section 2)
-- Server-side record of verified real-money purchases, written ONLY by the verify-purchase Edge
-- Function with the service-role key. There is deliberately no client insert/update policy:
-- a client that could write here could grant itself the season pass, which is exactly the gap
-- the old unconditional `is_premium: true` default was.
--
-- Run once in the Supabase SQL editor (or `supabase db execute -f Docs/sql/2026_entitlements.sql`).

create table if not exists public.entitlements (
    id             bigint generated always as identity primary key,
    user_id        uuid        not null,
    product_id     text        not null,
    platform       text        null,          -- 'ios' | 'android'
    transaction_id text        null,          -- Apple originalTransactionId / Google orderId
    source         text        not null default 'purchase',  -- 'purchase' | 'restore'
    verified_at    timestamptz not null default now(),
    unique (user_id, product_id, transaction_id)
);

alter table public.entitlements enable row level security;

-- Read-your-own-row only, so the client can display "you own this" state without being able to
-- mint it. No insert/update/delete policy at all — only the service-role writes here (service
-- role bypasses RLS), and there is nothing a client legitimately needs to write.
drop policy if exists "entitlements_select_own" on public.entitlements;
create policy "entitlements_select_own"
    on public.entitlements
    for select
    to authenticated
    using (auth.uid() = user_id);

create index if not exists entitlements_user_product_idx on public.entitlements (user_id, product_id);
