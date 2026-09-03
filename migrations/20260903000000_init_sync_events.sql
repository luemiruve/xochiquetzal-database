-- Global append-only event log for the offline-first sync engine.
-- See docs/superpowers/specs/2026-08-10-fundacion-tecnica-app-ios-design.md.

create table if not exists public.sync_events (
  event_id uuid primary key,
  entity_type text not null,
  entity_id uuid not null,
  operation text not null check (operation in ('insert', 'update', 'delete')),
  payload jsonb not null,
  created_at timestamptz not null,
  device_id text not null
);

-- Supports the client's keyset pull cursor: WHERE created_at >= ? ordered by (created_at, event_id).
create index if not exists sync_events_created_at_event_id_idx
  on public.sync_events (created_at, event_id);

alter table public.sync_events enable row level security;

-- Single admin user for now (Emilio) — any authenticated user may read/write the log.
-- Revisit when a 'cliente' role is introduced in a later phase.
create policy "authenticated_full_access"
  on public.sync_events
  for all
  to authenticated
  using (true)
  with check (true);

-- Records an incoming event idempotently. Routing the event into its domain table
-- (per entity_type) is added module by module starting in Phase 1 — see
-- docs/superpowers/specs/2026-08-10-product-domain-architecture-spec.md. For now this
-- function only appends to the global log, which is already enough to push/pull and
-- test idempotency and cursor advancement end to end.
create or replace function public.apply_sync_event(
  p_event_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_operation text,
  p_payload jsonb,
  p_created_at timestamptz,
  p_device_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.sync_events (event_id, entity_type, entity_id, operation, payload, created_at, device_id)
  values (p_event_id, p_entity_type, p_entity_id, p_operation, p_payload, p_created_at, p_device_id)
  on conflict (event_id) do nothing;
end;
$$;

-- Postgres grants EXECUTE on new functions to PUBLIC by default. Without an explicit
-- revoke, the `grant ... to authenticated` below is additive, not restrictive — the
-- anon (unauthenticated) role could still call this SECURITY DEFINER function via
-- PostgREST and write arbitrary sync_events rows, bypassing RLS entirely (a SECURITY
-- DEFINER function runs as its owner, not the caller, so authenticated_full_access
-- never even applies to this function's internal insert).
revoke execute on function public.apply_sync_event(uuid, text, uuid, text, jsonb, timestamptz, text) from public;
grant execute on function public.apply_sync_event(uuid, text, uuid, text, jsonb, timestamptz, text) to authenticated;
