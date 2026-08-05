# supabase/ — Migrations (Supabase CLI)

> Movido acá desde la raíz el 2026-08-05 (carga solo cuando se trabaja en esta carpeta). El schema autoritativo es `migrations/20260805171636_remote_schema.sql` (baseline generado con `supabase db pull`), no el dashboard. Proyecto linkeado a `msrxypywserfumscvnel`.

```
supabase/
├── config.toml              # config del CLI, sin secretos (todo env(...))
├── migrations/               # versionadas, orden cronológico por filename
│   ├── 20260805171636_remote_schema.sql   # baseline completo (tablas, funciones, grants, RLS)
│   ├── 20260805172127_storage_policies.sql # policies de storage.objects
│   ├── 20260805172144_storage_buckets.sql  # buckets avatars/kyc/portfolio
│   └── 20260805172201_cron_jobs.sql        # 3 jobs de pg_cron
├── seed.sql                  # catálogo: departments, cities, countries, services, categories
│                              # (NO admins — tiene password en texto plano; NO datos de usuarios)
└── archive/                   # scripts .sql corridos a mano antes de tener CLI — ya aplicados,
                                # se guardan solo por el comentario "por qué" de cada uno
```

Comandos:
- `supabase db push` — aplica migrations pendientes al remoto (requiere `SUPABASE_ACCESS_TOKEN` y `--password` de la DB, o `supabase login`)
- `supabase migration new <nombre>` — nueva migration vacía con timestamp
- `supabase db pull` — trae cambios hechos a mano en el dashboard (requiere Docker/Colima corriendo, usa un shadow DB)
- `supabase migration list` — compara historial local vs remoto

> **Limitación conocida del CLI:** `db pull` no capturó las policies de `storage.objects` (bug del engine `pg-delta` con ese schema) ni los buckets/cron jobs (son datos, no schema) — hubo que escribirlos a mano comparando contra `pg_policies` / `storage.buckets` / `cron.job` en vivo. Si se agregan buckets o cron jobs nuevos por el dashboard, van a necesitar el mismo tratamiento manual, no un `db pull` limpio.

> Requiere Docker corriendo para `db pull` / `db reset` local (usa un shadow Postgres). En esta máquina se instaló Colima (`brew install colima docker`, `colima start`) en vez de Docker Desktop.
