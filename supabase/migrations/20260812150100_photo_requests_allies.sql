-- Solicitudes de cambio de foto también para aliados.
--
-- La tabla nació solo para usuarios: `user_email` tiene FK contra `users`, así
-- que un aliado no puede tener una fila acá — su correo no existe en esa tabla.
-- Como la foto del aliado la ven los usuarios igual que la de un cliente, pasa
-- por la misma revisión del admin, con la misma pantalla.
--
-- Se elige generalizar en vez de crear `ally_photo_change_requests`: la cola del
-- admin es una sola, y duplicar la tabla obligaba a duplicar los 6 endpoints,
-- la pantalla y el evento de socket.
--
-- `owner_role` default 'user' deja intactas las filas que ya existen.

ALTER TABLE public.photo_change_requests
  DROP CONSTRAINT IF EXISTS photo_change_requests_user_email_fkey;

ALTER TABLE public.photo_change_requests
  ADD COLUMN IF NOT EXISTS owner_role text NOT NULL DEFAULT 'user';

COMMENT ON COLUMN public.photo_change_requests.owner_role IS
  'Dueño de la solicitud: user | ally. Decide en qué tabla buscar el correo';
COMMENT ON COLUMN public.photo_change_requests.user_email IS
  'Correo del dueño. Sin FK a propósito: apunta a users o a allies según owner_role';

-- La integridad que daba la FK se mantiene por índice + validación en el
-- backend, que ya comprueba que el dueño exista antes de insertar.
CREATE INDEX IF NOT EXISTS idx_photo_requests_owner
  ON public.photo_change_requests (owner_role, user_email);
