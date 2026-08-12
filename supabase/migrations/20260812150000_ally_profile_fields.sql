-- Perfil comercial del aliado: se pide una sola vez, tras el KYC y antes del
-- primer servicio.
--
-- Estos tres campos ya existían en `ally_service_profiles`, o sea una copia por
-- cada servicio que el aliado creara — y el formulario se los volvía a pedir
-- cada vez aunque la respuesta fuera siempre la misma. Describen al aliado, no
-- al servicio, así que su lugar es `allies`.
--
-- `ally_service_profiles` conserva sus columnas a propósito: el backend copia
-- estos valores al crear cada perfil de servicio, así la búsqueda de users
-- (`/category-offers`) sigue leyendo de donde siempre leyó.
--
-- La foto de perfil usa `allies.avatar_image`, que ya existía sin llenarse.
-- Nada que ver con `kyc_selfie`: esa vive en el bucket privado y solo la ve el
-- admin durante la revisión.

ALTER TABLE public.allies
  ADD COLUMN IF NOT EXISTS nombre_comercial   text,
  ADD COLUMN IF NOT EXISTS frase_presentacion text,
  ADD COLUMN IF NOT EXISTS resumen            text;

COMMENT ON COLUMN public.allies.nombre_comercial IS
  'Nombre con el que se presenta al usuario. Se copia a ally_service_profiles al crear cada servicio';
COMMENT ON COLUMN public.allies.frase_presentacion IS
  'Frase corta de presentación del aliado';
COMMENT ON COLUMN public.allies.resumen IS
  'Resumen de experiencia del aliado';
