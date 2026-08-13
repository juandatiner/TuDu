-- El nombre de un servicio deja de ser único.
--
-- `services` nació como catálogo cerrado y compartido, donde "Instalación de
-- puertas" era una sola fila para todos. El modelo actual es otro: cada aliado
-- crea su propia entrada dentro de una categoría y la nombra a su manera, así
-- que dos aliados con el mismo oficio chocan siempre — el segundo recibía
-- `duplicate key value violates unique constraint "services_name_key"` y no
-- podía terminar el registro.
--
-- Tampoco tenía sentido dentro de una misma cuenta: el mismo aliado no podía
-- usar un nombre parecido en dos categorías distintas.
--
-- Lo que sí sigue valiendo: la revisión del admin, que es donde se detectan
-- nombres repetidos a propósito o mal escritos, y que puede corregirlos o
-- reubicar el servicio antes de aprobarlo.

ALTER TABLE public.services
  DROP CONSTRAINT IF EXISTS services_name_key;

-- Índice no único: las búsquedas por nombre siguen resueltas sin el constraint.
CREATE INDEX IF NOT EXISTS idx_services_name ON public.services (name);
