# 🌸 Xochiquetzal Database

Postgres self-hosted vía Docker para desarrollo local, sin depender de Supabase Cloud.

## ▶️ Uso
```bash
docker compose up -d               # levanta Postgres en :5432 con el esquema ya aplicado
```

Credenciales dev-only (ver `docker-compose.yml`): db `xochiquetzal`, user `xochiquetzal`, password `xochiquetzal`.

- El esquema se aplica una sola vez, al crear el volumen (`docker/init/01-schema.sql`). Si cambia el esquema: `docker compose down -v` y `docker compose up -d` para reaplicarlo.

## 📄 Esquema
`docker/init/01-schema.sql` está derivado de `migrations/20260903000000_init_sync_events.sql` (script original usado en Supabase Cloud), con la capa de RLS/auth de Supabase (`anon`/`authenticated`, `security definer`) omitida — documentado en el comentario al inicio del archivo. El script original queda intacto en `migrations/` como referencia si en el futuro se agrega PostgREST/Supabase Auth al stack.

## ⚠️ Pendiente de decidir
Este esquema solo cubre el log de eventos de sincronización (`sync_events` + `apply_sync_event()`). Al dejar Supabase, también quedan pendientes de rediseñar (fuera de esta carpeta):
- **Auth**: la app usaba Supabase Auth (email/password); necesita un mecanismo propio (JWT emitido por `xochiquetzal-backend`, similar a como lo resolvió `pehuame-backend`).
- **Transporte de sync**: `SupabaseSyncTransport` en el frontend llama a Supabase vía PostgREST (`.from()`/`.rpc()`); sin PostgREST, necesita hablar con una API REST propia en `xochiquetzal-backend`.
