# tudu_admin/backend — API endpoints (puerto 3003)

> Detalle de rutas de `server.js`. Contexto general (roles, auth, tablas) en `@CLAUDE.md` de la raíz.

`GET /` (health) · `POST /api/admin/login` · `POST /auth/refresh` · `GET /api/admins` · `POST /api/admins` · `PUT /api/admins/:id` · `DELETE /api/admins/:id` · `PUT /api/admins/:id/change-password`

`POST /api/admin/login` trae la fila por `username` y compara el hash en memoria con bcrypt (`passwordCoincide`) — ya no filtra por `.eq('password', password)`. Si la fila todavía tiene la contraseña en texto plano y el login es correcto, se migra a hash automáticamente en ese mismo request. Responde `signSession({ role: 'admin' })`. Todo `/api/admins/*` exige token con `role: 'admin'`. Código Postgres `23505` (unique violation) se traduce a "Username or email already exists".
