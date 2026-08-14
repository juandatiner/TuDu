-- Marca de cuándo el aliado demostró que controla su teléfono.
--
-- El número se guarda igual aunque no esté verificado (hoy se puede editar sin
-- código), pero para contactarlo o mandarle avisos hace falta saber si alguien
-- comprobó que es suyo. `NULL` = sin verificar.
--
-- En users el equivalente es implícito: el teléfono solo llega a `user_phones`
-- pasando por `/users/phone/verify-otp`. Acá la columna es explícita porque el
-- aliado puede guardar el número antes de verificarlo.

ALTER TABLE public.allies
  ADD COLUMN IF NOT EXISTS phone_verified_at timestamptz;

COMMENT ON COLUMN public.allies.phone_verified_at IS
  'Cuándo se verificó el teléfono por SMS. NULL = guardado pero sin verificar';
