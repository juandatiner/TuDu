-- Verificación de identidad también para los clientes.
--
-- Hasta ahora solo el aliado subía cédula y selfie, porque es quien entra a la
-- casa de alguien. Ahora el cliente pasa por lo mismo al crear la cuenta: del
-- otro lado también hay una persona que recibe a un desconocido.
--
-- Mismas columnas que en `allies`, con los mismos estados
-- (pending | submitted | approved | rejected), para que el panel de
-- administración pueda revisar las dos colas con la misma pantalla.
--
-- Las tres columnas de documentos guardan la RUTA dentro del bucket privado
-- `kyc`, nunca el base64: el archivo se lee con URL firmada.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS kyc_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS kyc_cedula_frente text,
  ADD COLUMN IF NOT EXISTS kyc_cedula_reverso text,
  ADD COLUMN IF NOT EXISTS kyc_selfie text,
  ADD COLUMN IF NOT EXISTS kyc_submitted_at timestamptz,
  ADD COLUMN IF NOT EXISTS kyc_reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS kyc_reviewer_note text;

COMMENT ON COLUMN public.users.kyc_status IS
  'Estados: pending | submitted | approved | rejected';
COMMENT ON COLUMN public.users.kyc_cedula_frente IS
  'Ruta dentro del bucket privado kyc, no base64';

-- La cola del admin se lee por estado y por orden de llegada.
CREATE INDEX IF NOT EXISTS idx_users_kyc_estado
  ON public.users (kyc_status, kyc_submitted_at);
