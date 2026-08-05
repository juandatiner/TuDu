-- Políticas RLS de storage.objects para los backends (service_role).
-- No capturadas por `supabase db pull` (limitación conocida del CLI con el schema storage).

drop policy if exists "backend gestiona avatars" on storage.objects;
create policy "backend gestiona avatars"
  on storage.objects
  as permissive
  for all
  to service_role
  using (bucket_id = 'avatars')
  with check (bucket_id = 'avatars');

drop policy if exists "backend gestiona kyc" on storage.objects;
create policy "backend gestiona kyc"
  on storage.objects
  as permissive
  for all
  to service_role
  using (bucket_id = 'kyc')
  with check (bucket_id = 'kyc');

drop policy if exists "backend gestiona portfolio" on storage.objects;
create policy "backend gestiona portfolio"
  on storage.objects
  as permissive
  for all
  to service_role
  using (bucket_id = 'portfolio')
  with check (bucket_id = 'portfolio');
