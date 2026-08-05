# Archive

Scripts sueltos que se corrieron a mano en el SQL Editor del dashboard de
Supabase antes de que existiera `supabase/migrations/`. Su efecto ya está
100% capturado ahí:

- `borrar_cuenta.sql`, `categorias_servicios.sql`, `cron.sql`, `fix_kyc_view.sql`,
  `fix_lint_warnings.sql`, `rls.sql`, `rls_politicas.sql`, `storage.sql`,
  `storage_portfolio.sql` → schema en `supabase/migrations/20260805171636_remote_schema.sql`
  (baseline pulido de `supabase db pull`) + `20260805172127_storage_policies.sql` +
  `20260805172144_storage_buckets.sql` + `20260805172201_cron_jobs.sql`.
- `fix_services_sequence.sql` → el `setval` de las secuencias queda cubierto
  automáticamente al recargar `supabase/seed.sql` (dump con `pg_dump`, incluye
  el valor de secuencia de cada tabla con datos).

Se conservan acá (no se borran) porque el comentario de cada uno explica el
**por qué** de la decisión — el `security_invoker` en la vista, el motivo de
usar `pg_cron` en vez de `setInterval`, etc. — contexto que una migration por
sí sola no cuenta. No ejecutar de nuevo: ya están aplicados.
