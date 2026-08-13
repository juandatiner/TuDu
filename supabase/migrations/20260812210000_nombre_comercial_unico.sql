-- El nombre comercial del aliado es único entre todos los aliados.
--
-- Al revés que `services.name`, que sí puede repetirse: dos plomeros distintos
-- pueden ofrecer "Instalación de puertas", pero no pueden llamarse los dos
-- "Electricidad López" — es el nombre con el que el usuario los distingue y
-- los elige.
--
-- Índice sobre `lower(trim(...))` y no un UNIQUE simple: "Electricidad López",
-- "electricidad lópez" y "Electricidad López " son el mismo negocio para
-- cualquiera que los lea, y un UNIQUE normal los dejaría convivir.
--
-- Los NULL no chocan entre sí en Postgres, así que los aliados que todavía no
-- llenaron el perfil no se estorban.

CREATE UNIQUE INDEX IF NOT EXISTS idx_allies_nombre_comercial_unico
  ON public.allies (lower(trim(nombre_comercial)))
  WHERE nombre_comercial IS NOT NULL;
