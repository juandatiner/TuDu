# tudu_users/backend — API endpoints (puerto 3000)

> Detalle de rutas de `index.js`. Contexto general (roles, auth, tablas) en `@CLAUDE.md` de la raíz.

**Auth y registro**
| Método | Ruta | Notas |
|--------|------|-------|
| POST | `/send-otp` | Rate limit por correo. Supabase Auth `signInWithOtp`. Con `DEV_MODE=true` se salta el envío para **cualquier** correo |
| POST | `/verify-otp` | Rate limit por correo. Supabase Auth `verifyOtp`. Con `DEV_MODE=true`, código maestro `DEV_OTP` (default `123456`) para cualquier correo — apagado por completo si `DEV_MODE` no está en `true`. Responde `signSession()`: `{ token, refresh_token, expires_in }` |
| POST | `/users/phone/send-otp` | Rate limit por correo. OTP por SMS real vía Twilio (`sms_otp.js`) si hay credenciales; si no, error explícito (ya no finge el envío) |
| POST | `/users/phone/verify-otp` | Rate limit por correo. Contra el código emitido por `sms_otp.js` |
| POST | `/auth/refresh` | Canjea `refresh_token` por una sesión nueva. Revoca si la sesión ya no está activa en `device_sessions` |
| POST | `/check-user` | `{exists, user}` — pública |
| POST | `/register-user` | |

> `/check-ally` y `/register-ally` **ya no existen en este backend** (fueron borrados, no solo dejados de documentar — verificado por `grep`). Los aliados se gestionan enteramente en el backend de allies (3002); esas copias quedaban desactualizadas y dejaban aliados en un estado inconsistente que el otro backend no reconocía.
>
> Fuera de las rutas listadas como públicas (más `/departments`, `/cities`, `/countries`, `/services`, `/search-services`, `/categories`, `/category-offers`, `/device-session/check`), **todo el resto exige `Authorization: Bearer <token>`** válido, y el dueño del token solo puede operar sobre su propio email/fila (ver §5 de la raíz).

**Perfil**
| Método | Ruta | Notas |
|--------|------|-------|
| GET | `/users/profile/:email` | `?lite=true` omite `avatar_image` |
| PUT | `/users/profile/avatar` | `avatar_image: null` vuelve a color+icono; con imagen resetea color a `#78BF32` |
| PUT | `/users/profile/data` | upsert de `user_phones` si vienen `country_code` + `phone_number` |
| DELETE | `/users/:email` | Llama al RPC `tudu_borrar_cuenta(email)` — borrado transaccional en Postgres, no deletes secuenciales desde Node. Exige token y que el email coincida con el dueño (o rol admin) |

**Fotos (usuario ↔ admin)**
| Método | Ruta |
|--------|------|
| POST | `/api/user/photo-change-request` |
| GET | `/api/user/photo-change-request/pending` |
| GET | `/api/user/photo-change-request/unnotified` |
| PUT | `/api/user/photo-change-request/mark-notified/:id` |
| GET | `/api/admin/photo-change-requests` |
| PUT | `/api/admin/photo-change-requests/:id` |
| PUT | `/api/admin/photo-change-requests/:id/read` |

`PUT /api/admin/photo-change-requests/:id` con `status: 'approved'` copia `new_avatar_image` a `users.avatar_image` y emite `photoRequestUpdated` por socket **incluyendo `new_avatar_image`** — el Provider de Flutter depende de ese campo.

**Ubicaciones y direcciones**
`GET /departments` · `GET /cities?department_id=` · `GET /countries` · `GET /user-addresses?user_email=` · `POST /user-addresses` · `PUT /user-addresses/:id` · `DELETE /user-addresses/:id`

Validación: `number_principal` debe contener al menos un dígito; `address_name` único por usuario.

**Tarjetas**
`GET /users/cards/:userEmail` · `POST /users/cards` · `DELETE /users/cards/:id` · `PUT /users/cards/:id/default`

**Servicios y búsqueda**
`GET /services` · `POST /publish-service` · `GET /services-in-search?user_email=` · `PUT /services-in-search/:id/assign` · `PUT /services-in-search/:id/status` · `DELETE /services-in-search/:id?user_email=` · `GET /search-services?query=` (ilike) · `POST /search-history` · `GET /search-history?user_email=` · `DELETE /search-history/:id`

**Sesiones de dispositivo**
`POST /device-session/check` · `POST /device-session/register` · `GET /device-session/status` · `POST /device-session/logout` · `GET /device-session/list` · `POST /device-session/close-others`
