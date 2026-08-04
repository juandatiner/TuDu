-- ============================================================================
--  tudu — Buckets de Storage para imágenes
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase.
--  (Crear buckets desde la API falla con "new row violates row-level security
--  policy": storage.buckets tiene sus propias políticas.)
--
--  POR QUÉ
--  Hoy `users.avatar_image`, `photo_change_requests.new_avatar_image` y los tres
--  campos `kyc_*` de `allies` guardan la imagen en base64 DENTRO de Postgres.
--  Cada foto puede pesar megas, y eso:
--    - infla cada consulta que haga `select *` sobre esas tablas,
--    - engorda las copias de seguridad,
--    - gasta ancho de banda aunque solo se quiera el nombre del usuario.
--
--  Con Storage, la tabla guarda una URL de ~100 bytes y el archivo vive donde
--  corresponde, servido por CDN.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Buckets
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Fotos de perfil: públicas. Se muestran en la app y no revelan nada sensible.
  ('avatars', 'avatars', true, 5242880,
   array['image/jpeg','image/png','image/webp']),

  -- Documentos de identidad: PRIVADO, sin excepción. Solo se acceden mediante
  -- URL firmada y con caducidad, generada por el backend.
  ('kyc', 'kyc', false, 10485760,
   array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 2. Políticas de acceso
--    Los backends usan la service role, que se salta estas políticas. Esto es
--    para los roles públicos de la API.
-- ----------------------------------------------------------------------------

-- Lectura pública SOLO del bucket de avatares.
drop policy if exists "avatars lectura publica" on storage.objects;
create policy "avatars lectura publica"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- El backend necesita política explícita para escribir.
--
-- `storage.objects` tiene RLS activo y, a diferencia de las tablas del esquema
-- public, la service role NO la esquiva por sí sola en la API de Storage: sin
-- estas dos políticas, subir un archivo falla con
-- "new row violates row-level security policy".
drop policy if exists "backend gestiona avatars" on storage.objects;
create policy "backend gestiona avatars"
  on storage.objects for all
  to service_role
  using (bucket_id = 'avatars')
  with check (bucket_id = 'avatars');

drop policy if exists "backend gestiona kyc" on storage.objects;
create policy "backend gestiona kyc"
  on storage.objects for all
  to service_role
  using (bucket_id = 'kyc')
  with check (bucket_id = 'kyc');

-- El bucket `kyc` no tiene ninguna política para anon ni authenticated, a
-- propósito: solo el backend llega a esos documentos, y los sirve mediante URL
-- firmada con caducidad.
--
-- Tampoco hay política de escritura para roles públicos en `avatars`: subir una
-- foto pasa siempre por el backend, que valida el token y el tamaño.

-- ----------------------------------------------------------------------------
--  COMPROBACIÓN
-- ----------------------------------------------------------------------------
select id, public, file_size_limit from storage.buckets where id in ('avatars','kyc');
