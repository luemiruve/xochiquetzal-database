-- =========================
-- Esquema Xochiquetzal para Postgres self-hosted (Docker)
--
-- Basado en migrations/20260903000000_init_sync_events.sql (script original
-- usado en Supabase Cloud), con un recorte deliberado:
--
--   1. Seccion de RLS/auth de Supabase (roles anon/authenticated, policy
--      authenticated_full_access, grant/revoke sobre esos roles) omitida:
--      esa capa depende de PostgREST poblando esos roles y de Supabase Auth
--      emitiendo el JWT que PostgREST traduce a "authenticated". Sin
--      PostgREST en el stack, esos roles no existen en este Postgres y el
--      grant/revoke fallaria al aplicar el script. El backend se conectara
--      con su propio esquema de autenticacion (a definir en
--      xochiquetzal-backend), sin pasar por PostgREST.
--   2. `security definer` / `set search_path` removidos de
--      apply_sync_event(): esos existian unicamente para blindar la funcion
--      contra el rol `anon` de Supabase llamandola via PostgREST sin
--      autenticarse. Sin PostgREST, esa superficie de ataque no existe.
--
--   El script original queda intacto en migrations/ como referencia si en
--   el futuro se agrega PostgREST/Supabase Auth al stack.
-- =========================

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
as $$
begin
  insert into public.sync_events (event_id, entity_type, entity_id, operation, payload, created_at, device_id)
  values (p_event_id, p_entity_type, p_entity_id, p_operation, p_payload, p_created_at, p_device_id)
  on conflict (event_id) do nothing;
end;
$$;
