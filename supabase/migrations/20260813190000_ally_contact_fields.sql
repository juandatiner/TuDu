-- Teléfono del aliado guardado por partes, igual que el de un usuario.
--
-- `allies.phone` ya existía, pero como un texto suelto: para volver a pintar el
-- selector de país (bandera + prefijo) hay que saber qué prefijo eligió, y
-- deducirlo del número completo es adivinar — "+57" y "+571" son dos países
-- distintos con el mismo comienzo.
--
-- En users esto vive en la tabla `user_phones`; acá va en columnas de `allies`
-- porque un aliado tiene un solo teléfono y no hay historial que guardar.
--
-- `phone` se mantiene con el número completo (prefijo incluido), que es lo que
-- se usa para llamar o mandar el SMS de verificación cuando exista.

ALTER TABLE public.allies
  ADD COLUMN IF NOT EXISTS country_code text,
  ADD COLUMN IF NOT EXISTS country_name text,
  ADD COLUMN IF NOT EXISTS phone_number text;

COMMENT ON COLUMN public.allies.phone IS
  'Número completo con prefijo, ej: +573001234567';
COMMENT ON COLUMN public.allies.country_code IS
  'Prefijo de marcación elegido en el selector, ej: +57';
COMMENT ON COLUMN public.allies.phone_number IS
  'Número sin prefijo, tal como lo escribió el aliado';
