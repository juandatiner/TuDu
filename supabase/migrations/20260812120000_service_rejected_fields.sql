-- Campos señalados por el admin al rechazar un servicio propuesto.
--
-- `admin_note` ya guardaba el motivo en prosa, pero el aliado tenía que
-- adivinar a qué parte se refería: ¿el nombre, la descripción, las fotos? Con
-- esto el panel marca los campos concretos y la app de aliados los resalta en
-- el formulario de corrección.
--
-- Valores usados por la app: 'name' | 'description' | 'portfolio' | 'category'.
-- Se deja como text[] sin CHECK a propósito: agregar un campo nuevo al
-- formulario no debería exigir una migration.

ALTER TABLE public.services
  ADD COLUMN IF NOT EXISTS rejected_fields text[];

COMMENT ON COLUMN public.services.rejected_fields IS
  'Campos que el admin marcó como problema al rechazar: name | description | portfolio | category';
