# CLAUDE.md — tudu Ecosystem

> Última revisión: 2026-08-05 — generado leyendo el código fuente real (`index.js`, `server.js`, `auth.js`, `rate_limit.js`, `cors_config.js`, `sms_otp.js`, `storage.js`, `config.dart`, `package.json`), no el blueprint.
>
> **Cambio mayor de esta revisión:** la pasada anterior (2026-07-28) quedó desactualizada casi de inmediato — el backend recibió una ronda de hardening real (commit "OTP por SMS, validación uniforme...") que la sección 9 todavía describía como pendiente. Se verificó **contra el código, no de memoria**: JWT propio con auth/refresh (§5), rate limiting, bcrypt, CORS por allowlist, imágenes ya migradas a Supabase Storage, y casi todos los "bugs activos" y "backdoors" antes documentados **ya no existen**. Además, el schema de Supabase quedó versionado con el Supabase CLI (`supabase/migrations/` + `supabase/seed.sql`, proyecto linkeado). Ver §3.1 y §9.
>
> Revisión anterior (2026-03-17): el backend migró de **SQLite local a Supabase (Postgres)**. Toda la sección de DBs fue reescrita. Ver §3.

---

## 1. PROJECT IDENTITY

**tudu** es un marketplace de servicios locales (Colombia) que conecta usuarios (clientes) con aliados (prestadores de servicios), gestionado por un panel de administración.

Stack: Flutter/Dart (frontend multiplataforma) + Node.js/Express (3 backends) + **Supabase (Postgres + Supabase Auth)** + Socket.io (tiempo real en users y allies) + `compression` (gzip para los JSON con base64).

Contexto geográfico: los datos de departamentos y ciudades están pre-cargados para Colombia (33 departamentos, ~1000+ ciudades) en las tablas `departments` / `cities` de Supabase.

---

## 2. ARCHITECTURE

| App | Frontend | Backend | Archivo principal | Puerto |
|-----|----------|---------|-------------------|--------|
| Users | `tudu_users/users/` | `tudu_users/backend/` | `index.js` | **3000** |
| Allies | `tudu_allies/allies/` | `tudu_allies/backend/` | `index.js` | **3002** |
| Admin | `tudu_admin/admin/` | `tudu_admin/backend/` | `server.js` | **3003** |

Los 3 backends escuchan en `0.0.0.0` (accesibles desde dispositivo físico en la misma red).

### Módulos compartidos por backend

Cada backend (`tudu_users`, `tudu_allies`, `tudu_admin`) tiene su propia copia de estos archivos — no es un paquete compartido, es el mismo código pegado en los 3:

| Archivo | Qué hace |
|---|---|
| `auth.js` | Firma y verifica JWT (access + refresh), middleware `requireAuth`, handler de `/auth/refresh`, auth de sockets |
| `rate_limit.js` | Límites de `express-rate-limit` por correo (OTP) o IP (login admin) |
| `cors_config.js` | CORS por allowlist si `CORS_ORIGINS` está seteada, comodín `*` si no |
| `storage.js` | Sube imágenes a Supabase Storage; si falla, cae a guardar base64 (users y allies) |
| `sms_otp.js` | Solo en `tudu_users` — OTP por SMS vía Twilio, códigos en memoria (TTL 5 min) |

Ver §5 (auth) y §9 (qué de esto es nuevo respecto a la revisión anterior).

### Acceso a datos

Los 3 backends hablan con **la misma instancia de Supabase** vía `@supabase/supabase-js` usando la **service role key** (bypassa RLS). No hay separación de bases por backend: es un solo Postgres compartido.

| Backend | Tablas que toca |
|---------|-----------------|
| Users (`index.js`) | `users`, `user_phones`, `user_addresses`, `user_cards`, `device_sessions`, `photo_change_requests`, `search_history`, `services`, `services_in_search`, `departments`, `cities`, `countries`, `allies` |
| Allies (`index.js`) | `allies`, `ally_service_profiles`, `ally_device_sessions`, `services`, `services_in_search` |
| Admin (`server.js`) | `admins` |

> `allies`, `services` y `services_in_search` son escritas por **dos procesos** (users backend y allies backend). Postgres maneja la concurrencia — ya no aplica el problema de `SQLITE_BUSY` de la arquitectura anterior.

### Socket.io

- **Users backend (3000)** — emite `newPhotoChangeRequest` y `photoRequestUpdated`. El admin Flutter se conecta acá, no al admin backend.
- **Allies backend (3002)** — solo loguea conexiones/desconexiones para monitoreo. No emite eventos de negocio.
- **Admin backend (3003)** — no tiene Socket.io.

Handshake: `auth.token` (el mismo JWT de acceso de la API REST — `io.use(authenticateSocket)` lo exige y de ahí sale `socket.data.auth.email`) + `auth.device` (JSON string con `model` / `name` / `platform`) + `auth.device_id`. Sin token válido, la conexión se rechaza (`unauthorized`).

### Config Flutter (`config.dart` — una por app)

La IP **ya no está hardcodeada**. Se inyecta en compilación:

```dart
static const String _dartDefineIp = String.fromEnvironment('LOCAL_IP');

static String get baseUrl {
  if (_dartDefineIp.isNotEmpty) return 'http://$_dartDefineIp:$port';
  if (Platform.isAndroid) return 'http://10.0.2.2:$port';  // emulador Android
  return 'http://localhost:$port';                          // simulador iOS / web / macOS
}
```

| App | `Config.port` |
|-----|---------------|
| users | 3000 |
| allies | 3002 |
| admin | **3000** — el admin Flutter consume el users backend (photo_change_requests); el admin backend 3003 se usa solo para login y CRUD de admins |

`run-dev.sh` detecta la IP local (`ipconfig getifaddr en0`) y la pasa con `--dart-define=LOCAL_IP=<ip>`. Sin ese flag, los emuladores igual funcionan por el fallback.

---

## 3. DATA MODEL (Supabase / Postgres)

> **Actualizado 2026-08-05:** el schema ahora está versionado con el Supabase CLI (`supabase/migrations/`, proyecto linkeado a `msrxypywserfumscvnel`). El schema autoritativo es `supabase/migrations/20260805171636_remote_schema.sql` (baseline generado con `supabase db pull`), no el dashboard. Las columnas listadas abajo siguen siendo una referencia de lectura rápida — para el detalle exacto, mirar las migrations. Ver §3.1.

### 3.1 Migrations (Supabase CLI)

```
supabase/
├── config.toml              # config del CLI, sin secretos (todo env(...))
├── migrations/               # versionadas, orden cronológico por filename
│   ├── 20260805171636_remote_schema.sql   # baseline completo (tablas, funciones, grants, RLS)
│   ├── 20260805172127_storage_policies.sql # policies de storage.objects
│   ├── 20260805172144_storage_buckets.sql  # buckets avatars/kyc/portfolio
│   └── 20260805172201_cron_jobs.sql        # 3 jobs de pg_cron
├── seed.sql                  # catálogo: departments, cities, countries, services, categories
│                              # (NO admins — tiene password en texto plano; NO datos de usuarios)
└── archive/                   # scripts .sql corridos a mano antes de tener CLI — ya aplicados,
                                # se guardan solo por el comentario "por qué" de cada uno
```

Comandos:
- `supabase db push` — aplica migrations pendientes al remoto (requiere `SUPABASE_ACCESS_TOKEN` y `--password` de la DB, o `supabase login`)
- `supabase migration new <nombre>` — nueva migration vacía con timestamp
- `supabase db pull` — trae cambios hechos a mano en el dashboard (requiere Docker/Colima corriendo, usa un shadow DB)
- `supabase migration list` — compara historial local vs remoto

> **Limitación conocida del CLI:** `db pull` no capturó las policies de `storage.objects` (bug del engine `pg-delta` con ese schema) ni los buckets/cron jobs (son datos, no schema) — hubo que escribirlos a mano comparando contra `pg_policies` / `storage.buckets` / `cron.job` en vivo. Si se agregan buckets o cron jobs nuevos por el dashboard, van a necesitar el mismo tratamiento manual, no un `db pull` limpio.

> Requiere Docker corriendo para `db pull` / `db reset` local (usa un shadow Postgres). En esta máquina se instaló Colima (`brew install colima docker`, `colima start`) en vez de Docker Desktop.

### `users`
Campos usados: `id`, `email` (único), `nombre`, `apellido`, `avatar_color` (default `#78BF32`), `avatar_icon` (default `person`), `avatar_image` (**URL de Supabase Storage**, bucket `avatars` — ver nota de imágenes más abajo), `phone`, `genero`, `fecha_nacimiento`, `dark_mode` (int 0/1), `language`, `created_at`.

`GET /users/profile/:email?lite=true` omite `avatar_image` del select — usar siempre que no se necesite la foto.

### `user_phones`
`user_email` (UNIQUE — hay upsert con `onConflict: 'user_email'`), `country_code`, `country_name`, `phone_number`.

### `user_addresses`
`user_email`, `address_name`, `department_id` → `departments`, `city_id` → `cities`, `type_via`, `number_principal`, `number_secondary`, `number_final`, `additional_info`, `address_icon`, `created_at`.

El join a `departments(name)` / `cities(name)` se hace con la sintaxis anidada de Supabase y se aplana a `department_name` / `city_name` antes de responder.

### `user_cards`
`user_email`, `card_number` (**guardado enmascarado**: `**** **** **** 1234`), `card_holder`, `expiry_date`, `card_type`, `document_type`, `document_number`, `card_mode`, `is_default` (int 0/1), `created_at`.

La primera tarjeta de un usuario se marca `is_default` automáticamente.

### `device_sessions` / `ally_device_sessions`
`user_email` / `ally_email`, `device_id`, `device_info`, `is_active` (int 0/1), `last_activity`.

`device_sessions` tiene constraint compuesta `(user_email, device_id)` — el users backend hace upsert con `onConflict: 'user_email,device_id'`. El allies backend **no** usa upsert; hace select-then-insert-or-update manual.

Regla de negocio: registrar un dispositivo desactiva todos los demás del mismo email (sesión única).

### `photo_change_requests`
`id`, `user_email`, `new_avatar_image` (URL de Storage, bucket `avatars`), `status` (`pending` / `approved` / `rejected`), `rejection_reason`, `read_at`, `user_notified` (bool), `created_at`, `updated_at`.

Limpieza automática: `cleanupOldPhotoRequests()` borra las que tienen `user_notified = true`. **Ya no es un `setInterval` en producción** — el job real vive en `pg_cron` (`supabase/migrations/20260805172201_cron_jobs.sql`, cada hora, corre dentro de Postgres). El `setInterval` en Node sigue en el código como respaldo para desarrollo local, pero solo se activa con `MANTENIMIENTO_EN_PROCESO=true` — apagado por defecto.

### `search_history`
`user_email`, `query` (⚠ la columna se llama `query`, pero la API la expone como `search_query`), `created_at`. Se devuelven las últimas 10.

### `services`
`id`, `name`, `created_at`. Catálogo compartido. Los aliados pueden crear entradas nuevas vía `POST /services` (allies backend).

### `services_in_search`
`id`, `user_email`, `ally_email`, `title`, `description`, `time_quantity`, `time_unit`, `budget` (string ya formateado con comas), `worker_info`, `status`, `assigned` (int 0/1), `created_at`.

`budget` se normaliza en `POST /publish-service`: se parsea a número, se redondea a la centena más cercana y se re-formatea con separador de miles.

### `allies`
`id`, `email` (único), `nombre`, `apellido`, `fecha_nacimiento`, `kyc_cedula_frente`, `kyc_cedula_reverso`, `kyc_selfie` (URLs/rutas del bucket privado `kyc` — leídas con URL firmada, ver `storage.js`), `kyc_status` (`submitted` / `approved` / `rejected`), `kyc_submitted_at`, `updated_at`.

KYC ya tiene flujo de revisión completo: `GET /api/admin/kyc`, `GET /api/admin/kyc/:email`, `PUT /api/admin/kyc/:email` (aprobar/rechazar con motivo) en el backend de allies, más `kyc_review_screen.dart` en el panel admin.

### `ally_service_profiles`
`ally_email`, `service_id`, `nombre_comercial`, `frase_presentacion`, `resumen`, `created_at`.

> El mismatch `ally_email` / `ally_id` que hacía que `check-ally` nunca encontrara los perfiles **ya está corregido** — ambos lados usan `ally_email`.

### `admins`
`id`, `username` (único), `password` (**bcrypt**; filas heredadas en texto plano se migran a hash automáticamente en su próximo login exitoso — ver `tudu_admin/backend/server.js`, función `passwordCoincide`), `email` (único), `name`, `role` (default `admin`), `created_at`, `updated_at`.

### `departments`, `cities`, `countries`
Catálogos pre-cargados. `cities.department_id` → `departments.id`. `countries` incluye códigos de marcación. Los datos incorrectos que había antes (Cali bajo Antioquia, Barranquilla/Luruaco bajo Bolívar) **ya están corregidos** — verificado contra `supabase/seed.sql`.

### Imágenes: Storage, no base64

`avatar_image`, `new_avatar_image` y los 3 campos `kyc_*` guardan **URLs de Supabase Storage** (bucket `avatars` público, `kyc` privado con URL firmada — ver §3.1 buckets), no base64 dentro de Postgres. La subida pasa por `subirImagen()` en `storage.js`: si el bucket falla o no existe, cae a guardar el base64 tal cual para no romper la funcionalidad — así que en teoría puede aparecer una fila vieja con base64 crudo si la subida falló en su momento, pero el camino normal ya no pasa por Postgres.

### Código SQLite muerto — ya no existe
Los archivos de la arquitectura SQLite anterior (`index.js.old`, `index.sqlite.js`, `server.sqlite.js`, `init-db.js`) **fueron borrados**. Verificado: no quedan en el repo.

---

## 4. API ENDPOINTS

### Users Backend — puerto 3000 (`tudu_users/backend/index.js`)

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
> Fuera de las rutas listadas como públicas (más `/departments`, `/cities`, `/countries`, `/services`, `/search-services`, `/categories`, `/category-offers`, `/device-session/check`), **todo el resto exige `Authorization: Bearer <token>`** válido, y el dueño del token solo puede operar sobre su propio email/fila (ver §5).

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

### Allies Backend — puerto 3002 (`tudu_allies/backend/index.js`)

| Método | Ruta | Notas |
|--------|------|-------|
| POST | `/send-otp` | Igual que users: rate limit por correo |
| POST | `/verify-otp` | Igual que users: `DEV_OTP` maestro solo con `DEV_MODE=true`, ya no es un backdoor sin condición. Responde `signSession()` |
| POST | `/auth/refresh` | Igual mecanismo que users |
| POST | `/check-ally` | Devuelve `partial: 'personal'` / `'kyc'` / `'service'` / `'kyc_pending'` según qué falte. Consulta `ally_service_profiles` por `ally_email` (el mismatch con `ally_id` está corregido) |
| POST | `/register-ally` | upsert con `onConflict: 'email'` |
| POST | `/ally-kyc` | Sube 3 imágenes a Storage (bucket `kyc`, privado), marca `kyc_status = 'submitted'` |
| GET | `/api/admin/kyc` | Lista aliados con KYC pendiente de revisión |
| GET | `/api/admin/kyc/:email` | Detalle con URLs firmadas de los 3 documentos |
| PUT | `/api/admin/kyc/:email` | Aprobar/rechazar (rol admin, `/api/admin/*` exige `req.auth.role === 'admin'`) |
| POST | `/ally-service-profile` | |
| GET | `/services` | |
| POST | `/services` | Crea servicio nuevo (mín. 2 chars) |
| GET | `/services-in-search` | Solo `assigned = 0` |
| PUT | `/services-in-search/:id/assign` | Requiere `ally_email`; pone `status: 'EN PROCESO'` (igual que users ahora — ver §8) |
| PUT | `/services-in-search/:id/status` | |
| GET | `/my-services?ally_email=` | |
| — | `/ally-device-session/*` | check · register · status · logout · list · close-others |

El caso especial que forzaba `requires_verification: true` para `cosmodavid2009@gmail.com` **ya no existe** — verificado, no aparece ninguna referencia a ese correo en el código.

### Admin Backend — puerto 3003 (`tudu_admin/backend/server.js`)

`GET /` (health) · `POST /api/admin/login` · `POST /auth/refresh` · `GET /api/admins` · `POST /api/admins` · `PUT /api/admins/:id` · `DELETE /api/admins/:id` · `PUT /api/admins/:id/change-password`

`POST /api/admin/login` trae la fila por `username` y compara el hash en memoria con bcrypt (`passwordCoincide`) — ya no filtra por `.eq('password', password)`. Si la fila todavía tiene la contraseña en texto plano y el login es correcto, se migra a hash automáticamente en ese mismo request. Responde `signSession({ role: 'admin' })`. Todo `/api/admins/*` exige token con `role: 'admin'`. Código Postgres `23505` (unique violation) se traduce a "Username or email already exists".

---

## 5. AUTH FLOW

> Reescrito 2026-08-05 contra el código real de `auth.js`, `rate_limit.js`, `sms_otp.js`. La versión anterior de este documento decía "no hay JWT" — ya no es cierto.

### OTP → JWT propio (users y allies)

1. Cliente → `POST /send-otp { email }` (rate limit: 5 cada 15 min por correo)
2. Backend → `supabase.auth.signInWithOtp({ email })` — Supabase envía el correo, no Mailgun
3. Cliente → `POST /verify-otp { email, otp, device_id }` (rate limit: 10 cada 15 min por correo)
4. Backend → `supabase.auth.verifyOtp(...)` y, si es válido, **firma su propia sesión** con `signSession()`
5. Backend responde `{ token, refresh_token, expires_in }` — el cliente guarda ambos

**Dos tokens, a propósito:**
- **`token` (acceso):** JWT corto, `ACCESS_TOKEN_TTL` (default `30m`). Va en `Authorization: Bearer <token>` en cada request y en el handshake de Socket.io (`auth.token`).
- **`refresh_token`:** JWT largo, `REFRESH_TOKEN_TTL` (default `180d`). Solo sirve contra `POST /auth/refresh`.

**Revocación real:** `/auth/refresh` no solo valida la firma del refresh token — comprueba contra `device_sessions` (o `ally_device_sessions`) que esa sesión siga activa. Cerrar sesión en un dispositivo hace que su próximo refresh falle con `SESSION_REVOKED`, aunque el token siga siendo válido criptográficamente. Cada refresh rota también el refresh token.

**Autorización, no solo autenticación:** un middleware global (antes de resolver rutas) rechaza con `403 FORBIDDEN` cualquier intento de operar sobre un email que no sea el propio — comparando `req.auth.email` contra `email`/`user_email`/`ally_email` en query, body, y contra segmentos con `@` en la URL. Para recursos por `:id` (tarjetas, direcciones, historial) hay un segundo chequeo (`requireOwnRow`) que confirma que la fila le pertenece antes de dejar pasar `GET`/`PUT`/`DELETE`. El rol `admin` se salta ambos, porque gestiona cuentas ajenas por definición.

**Rutas públicas** (sin token): OTP, catálogos de solo lectura (`/departments`, `/cities`, `/countries`, `/services`, `/categories`), búsqueda, y `/auth/refresh` (que se autentica con el refresh token, no con el access token).

**Modo desarrollo:** con `DEV_MODE=true`, `DEV_OTP` (default `123456`) sirve como código maestro para **cualquier correo** — antes esto solo estaba acotado a una cuenta específica en el backend de users y era un backdoor sin condición en el de allies; ahora el gate es el mismo (`DEV_MODE`) en los dos y nunca debe estar en `true` en producción.

### SMS OTP (solo users)
`POST /users/phone/send-otp` y `/verify-otp` — código real vía Twilio (`sms_otp.js`), guardado en memoria (Map, TTL 5 min, máx. 5 intentos). Antes esto no existía: el endpoint simulaba el envío y en producción respondía `501`.

**Mailgun ya no se usa para OTP** en ningún backend — ni siquiera queda referenciado en el código (antes el cliente `mg` de allies se inicializaba sin usarse; ahora no existe ni eso).

### Admin — bcrypt + JWT
`POST /api/admin/login` trae la fila por `username`, compara con bcrypt (con fallback a texto plano solo para filas heredadas, migradas a hash en su primer login correcto) y responde `signSession({ role: 'admin' })`. El JWT del admin se firma con el **mismo secreto** que users/allies, así que un token de rol `admin` sirve también para llamar `/api/admin/*` en esos dos backends (por ejemplo, para revisar KYC o fotos).

---

## 6. DEV CONVENTIONS

### Naming
| Elemento | Convención | Ejemplo |
|----------|-----------|---------|
| Archivos Dart | `snake_case.dart` | `dashboard_screen.dart` |
| Clases Dart | `PascalCase` | `DashboardScreen` |
| State classes Dart | `_PascalCaseState` | `_DashboardScreenState` |
| Variables privadas Dart | `_camelCase` | `_isLoading` |
| Endpoints REST | `kebab-case` | `/services-in-search` |
| Prefijo admin/user | `/api/admin/` o `/api/user/` | solo para gestión de fotos y admins |
| Campos de BD | `snake_case` | `created_at`, `dark_mode` |
| Roles en BD | inglés, minúsculas | `'user'`, `'ally'`, `'admin'` |
| Estados de servicio | español, MAYÚSCULAS | `'EN ESPERA'`, `'EN PROCESO'` |
| Estados de photo_request | inglés, minúsculas | `'pending'`, `'approved'`, `'rejected'` |

### Estructura Flutter
```
lib/
├── main.dart        # MaterialApp, MultiProvider, rutas
├── config.dart      # Config: baseUrl vía --dart-define=LOCAL_IP, colores, helpers
├── screens/         # Un archivo por pantalla; StatefulWidget por defecto
├── models/          # Data classes simples (users, allies)
├── providers/       # ChangeNotifier: theme, language (solo users)
├── services/        # Sesiones y lógica de negocio (users, allies)
└── l10n/            # Localizaciones (solo users)
```
`tudu_admin/admin/lib/` solo tiene `config.dart`, `main.dart` y `screens/`.

### Patrones de código observados
- **Backend:** `async/await` con el patrón `const { data, error } = await supabase...`. Ya no hay callback hell — eso era SQLite.
- **Errores backend:** se chequea `error` y se responde `res.status(4xx/5xx).json({ error })`. `error.code === 'PGRST116'` = "no rows", se trata como "no existe", no como fallo.
- **HTTP en widgets:** la mayoría de screens llaman `http.get/post` directo en `initState` o en handlers de botón; solo la capa `services/` está separada correctamente.
- **Estado Flutter:** `setState()` en StatefulWidgets; `ChangeNotifier` para theme y language. No hay BLoC ni Riverpod.
- **URLs Flutter:** siempre `${Config.baseUrl}/ruta` — nunca URLs hardcodeadas en screens.
- **Socket.io Flutter:** `socket_io_client` — conecta en `initState()`, desconecta en `dispose()`.
- **JSON body:** `express.json({ limit: '50mb' })` en users y admin — necesario para base64.
- **`compression()`** activo en users y allies: reduce ~80% los JSON con base64.

### Colores (siempre vía `Config`, nunca hex hardcodeado en widgets)
```dart
Config.primaryColor    // Color(0xFF78BF32) — verde tudu
Config.secondaryColor  // Color(0xFF595959) — gris
Config.backgroundColor // Color(0xFFF4F2F2) — fondo claro
Config.whiteColor      // Color(0xFFFFFFFF)
Config.blackColor      // Color(0xFF000000)
Config.redColor        // Color(0xFFF44336)
Config.textColor       // Color(0xFF78BF32) — igual que primary
```

---

## 7. ENVIRONMENT

### Variables (los `.env` están gitignored)

> ⚠ Los `.env.example` versionados en el repo están desactualizados (todavía piden `MAILGUN_*`, les falta `SUPABASE_URL`/`JWT_SECRET`). La lista de abajo sale de `grep process.env` sobre el código real, no de esos archivos — no confiar en los `.example` hasta que se actualicen.

**`tudu_users/backend/.env`**
```env
PORT=3000
SUPABASE_URL=                 # REQUERIDO — process.exit(1) si falta
SUPABASE_SERVICE_ROLE_KEY=    # REQUERIDO — process.exit(1) si falta
JWT_SECRET=                   # REQUERIDO — process.exit(1) si falta. Compartido con allies y admin
ACCESS_TOKEN_TTL=30m          # opcional, default 30m
REFRESH_TOKEN_TTL=180d        # opcional, default 180d
CORS_ORIGINS=                 # opcional, lista separada por comas. Vacío = CORS abierto (*)
DEV_MODE=true                 # habilita DEV_OTP para cualquier correo — NUNCA en producción
DEV_OTP=123456                # opcional, default 123456
MANTENIMIENTO_EN_PROCESO=false # opcional — respaldo de limpieza en Node para desarrollo local sin pg_cron
TWILIO_ACCOUNT_SID=           # opcional — con las 3 puestas, /users/phone/send-otp manda SMS real
TWILIO_AUTH_TOKEN=
TWILIO_FROM=                  # número emisor en formato E.164 (+57...)
```

**`tudu_allies/backend/.env`**
```env
PORT=3002
SUPABASE_URL=                 # REQUERIDO
SUPABASE_SERVICE_ROLE_KEY=    # REQUERIDO
JWT_SECRET=                   # REQUERIDO — mismo valor que users y admin
ACCESS_TOKEN_TTL=30m
REFRESH_TOKEN_TTL=180d
CORS_ORIGINS=
DEV_MODE=true
DEV_OTP=123456
MANTENIMIENTO_EN_PROCESO=false
```

**`tudu_admin/backend/.env`**
```env
PORT=3003
SUPABASE_URL=                 # REQUERIDO
SUPABASE_SERVICE_ROLE_KEY=    # REQUERIDO
JWT_SECRET=                   # REQUERIDO — mismo valor que users y allies
ACCESS_TOKEN_TTL=30m
REFRESH_TOKEN_TTL=180d
CORS_ORIGINS=
```

> `SUPABASE_SERVICE_ROLE_KEY` **bypassa RLS**. Nunca exponerla al cliente ni commitearla.
>
> `JWT_SECRET` **debe ser el mismo valor en los 3 backends** — un token firmado por uno se valida en los otros dos (así el rol `admin` funciona cruzado). Si no está seteado, cada backend hace `process.exit(1)` al arrancar.

### Toolchain de desarrollo (macOS, verificado 2026-07-28)

| Componente | Versión |
|---|---|
| Flutter | 3.44.8 (stable) · Dart 3.12.2 |
| Node / npm | 26.5.0 / 11.17.0 |
| Xcode | 26.6 + runtime iOS 26.5 |
| CocoaPods | 1.17.0 |
| Android SDK | 36.1.0 (platform android-36.1, build-tools 36.1.0/37.0.0) |
| JDK | 21 (el bundled de Android Studio) |

Variables en `~/.zshrc`:
```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
```

Emuladores configurados: `Pixel_8_API_36` (Android 16, arm64) · iPhone 17 Pro · iPhone 17 Pro Max · iPad Pro 13-inch (M5) · iPad mini (A17 Pro).

### Arranque

```sh
./run-dev.sh users     # backend 3000 + Flutter users
./run-dev.sh allies    # backend 3002 + Flutter allies
./run-dev.sh admin     # backend 3003 + Flutter admin
./run-dev.sh all       # los 3 backends, imprime los comandos Flutter
./run-dev.sh backend   # solo los 3 backends
./run-dev.sh ip        # imprime la IP local detectada
```

El script detecta la IP con `ipconfig getifaddr en0` y la pasa como `--dart-define=LOCAL_IP=<ip>`. **Ya no hay que editar `config.dart` al cambiar de red.**

---

## 8. CRITICAL RULES — NUNCA ROMPER

1. **Puertos:** users `3000`, allies `3002`, admin `3003`. El **Flutter del admin apunta a 3000**, no a 3003 — usa el users backend para `photo_change_requests` y el 3003 solo para login/CRUD de admins.

2. **No hay bases de datos locales.** Todo vive en Supabase. `path.join(__dirname, '../../databases')` solo aparece en archivos muertos (`init-db.js`, `*.sqlite.js`, `index.js.old`). No revivirlos.

3. **`SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` son obligatorias.** Los 3 backends hacen `process.exit(1)` al arrancar si falta cualquiera.

4. **Roles en BD — strings exactos:** `'user'`, `'ally'`, `'admin'` (minúsculas, inglés).

5. **Estados de servicio — strings exactos:** `'EN ESPERA'`, `'EN PROCESO'`. El bug de case-sensitivity (`'En Proceso'` en users vs `'EN PROCESO'` en allies) **está corregido** — ambos backends escriben `'EN PROCESO'` ahora.

6. **Socket.io de negocio vive solo en el users backend (3000).** El admin Flutter se conecta ahí. El allies backend tiene Socket.io pero solo para logging.

7. **`photoRequestUpdated` debe incluir `new_avatar_image`** cuando el status es `approved` — el Provider de Flutter depende de ese campo para refrescar el avatar sin recargar.

8. **Sí hay JWT.** Todo endpoint fuera de la lista de rutas públicas exige `Authorization: Bearer <token>`, y el dueño del token solo puede operar sobre su propio email/fila (rol `admin` exceptuado). Ver §5. No revertir a "confiar en el email del body" — ese fue el modelo viejo, ya reemplazado a propósito.

9. **`error.code === 'PGRST116'` significa "no encontrado"**, no un fallo. Tratarlo como caso normal, igual que hace `check-user` / `check-ally`.

10. **`user_phones` y `device_sessions` dependen de constraints UNIQUE en Supabase** (`user_email` y `(user_email, device_id)`). Si se borran, los upsert con `onConflict` fallan.

11. **`search_history` guarda la columna `query`** pero la API la expone como `search_query`. No unificar sin tocar el cliente.

---

## 9. KNOWN ISSUES — DEUDA TÉCNICA

> **Toda esta sección se re-verificó línea por línea contra el código el 2026-08-05.** La revisión anterior (2026-07-28) documentaba una lista larga de backdoors, bugs y deuda de arquitectura — casi todo ya estaba resuelto en el código sin que este documento se hubiera actualizado. Abajo, lo que se confirmó **resuelto** (con evidencia) y lo poco que queda genuinamente abierto.

### Resuelto — verificado contra el código (ya no aplica)

**Seguridad:**
- ~~Backdoor OTP en allies para cualquier email~~ — ahora usa el mismo gate `DEV_MODE=true` que users, no un atajo incondicional.
- ~~Passwords de admin en texto plano~~ — bcrypt, con migración automática de filas heredadas en su primer login.
- ~~Sin JWT ni middleware de auth~~ — JWT propio (access+refresh) + autorización por dueño en los 3 backends. Ver §5.
- ~~Sin rate limiting en `/send-otp`~~ — `rate_limit.js`, límite por correo.
- ~~`DELETE /users/:email` sin auth~~ — exige token + dueño, y ahora es transaccional (RPC `tudu_borrar_cuenta`).
- ~~El backend descarta la sesión de Supabase Auth~~ — ahora emite su propia sesión JWT en `/verify-otp`.
- **CORS: parcialmente resuelto.** Ya existe `CORS_ORIGINS` para restringir por allowlist (`cors_config.js`), pero **el default sigue siendo abierto (`*`)** si la variable no está seteada — hay que setearla explícitamente antes de producción. Esto sigue siendo responsabilidad de quien despliegue, no del código.

**Bugs:**
- ~~`ally_service_profiles` con clave inconsistente~~ — `check-ally` ya consulta por `ally_email`, no por `ally_id`.
- ~~Status case inconsistency ('En Proceso' vs 'EN PROCESO')~~ — ambos backends escriben `'EN PROCESO'`.
- ~~`POST /users/cards` detecta duplicados con `.like('%1234')`~~ — ahora compara últimos 4 dígitos + titular + vencimiento exactos.
- ~~`DELETE /users/:email` sin transacción~~ — ver arriba, es un RPC transaccional.
- ~~`GET /api/user/photo-change-request/unnotified` ignora el error~~ — ahora responde `500` si Supabase falla.
- ~~`cities` con datos incorrectos (Cali/Antioquia, Barranquilla-Luruaco/Bolívar)~~ — corregido en `supabase/seed.sql`.

**Arquitectura:**
- ~~Imágenes base64 en columnas de Postgres~~ — migradas a Supabase Storage (`storage.js`), con fallback a base64 solo si la subida falla.
- ~~Sin migraciones versionadas~~ — `supabase/migrations/` + CLI linkeado, ver §3.1.
- ~~Código SQLite muerto sin borrar~~ — los archivos ya no existen.
- ~~Mailgun muerto en allies~~ — ni el cliente `mg` ni la dependencia quedan en el código.
- ~~`users` backend duplica endpoints de allies~~ — `/check-ally` y `/register-ally` fueron borrados de `tudu_users/backend`.
- ~~Limpieza de fotos por `setInterval` frágil~~ — el job real es `pg_cron` (§3.1); el `setInterval` en Node quedó como respaldo opcional de desarrollo (`MANTENIMIENTO_EN_PROCESO`), apagado por defecto.

### Todavía abierto

- **Service role key en los 3 backends** — sigue bypasando RLS por completo (es el diseño: los backends necesitan acceso total). Sigue siendo crítico que la key nunca llegue al cliente ni se commitee.
- **CORS abierto por defecto** — ver arriba, es un flag de configuración pendiente de setear en producción, no un bug de código.
- **`.env.example` desactualizados** en los 3 backends — todavía piden `MAILGUN_*`, no mencionan `JWT_SECRET`/`SUPABASE_URL`/etc. Ver nota en §7.
- **`search_history` guarda la columna `query`** pero la API la expone como `search_query` — sigue así, es una decisión consciente (regla #11), no un bug.

### Deuda de frontend (no re-verificada en esta pasada — solo se revisó backend)
- **Lógica HTTP en widgets** — la mayoría de screens hacen `http.get/post` directo, sin capa de servicios. Estado sin confirmar en esta revisión.
- **Sesión en `SharedPreferences`** — ahora el backend expira el access token a los 30 min y lo puede revocar de verdad al refrescar (§5); falta confirmar si el cliente Flutter maneja el ciclo de refresh correctamente y si limpia la sesión local ante un `401`/`SESSION_REVOKED`. No verificado en esta pasada.
- **`config.dart` divergente entre las 3 apps** — misma lógica copiada con imports y comentarios distintos. Estado sin confirmar en esta revisión.

---

## 10. CURRENT STATE

### Implementado y funcional
- [x] Auth con JWT propio (access + refresh, revocable) sobre OTP por correo (Supabase Auth) o SMS (Twilio) — ver §5
- [x] Rate limiting, CORS por allowlist, bcrypt para admin
- [x] Auth admin (username/password + JWT)
- [x] Registro de usuarios y aliados
- [x] Catálogo de servicios + categorías, con moderación de admin (`categories_screen.dart`, `category_offers_screen.dart`, `services_catalog_screen.dart`, `services_review_screen.dart` — propuestas de aliados quedan `pending` hasta que un admin las aprueba/rechaza/corrige)
- [x] Publicar y buscar servicios (`services_in_search`)
- [x] Asignación de servicios a aliados y cambio de estado
- [x] Historial de búsquedas (últimas 10)
- [x] Perfil de usuario (datos, avatar color/icono/foto vía Supabase Storage)
- [x] Direcciones (33 departamentos, ~1000 ciudades, datos corregidos)
- [x] Tarjetas de pago (enmascaradas, sin procesador real)
- [x] Solicitudes de cambio de foto con aprobación de admin + limpieza vía `pg_cron`
- [x] Socket.io en tiempo real para photo_change_requests, autenticado con el mismo JWT
- [x] Panel admin: login, CRUD de admins, cambio de contraseña
- [x] **Revisión de KYC:** endpoints `/api/admin/kyc*` + `kyc_review_screen.dart` — aprobar/rechazar con motivo
- [x] Portafolio de trabajos de aliados (`ally_portfolio_items`, bucket `portfolio`, `camera_capture_mixin.dart`)
- [x] Sesiones por dispositivo (users y allies, sesión única, expiración por inactividad vía `pg_cron`)
- [x] Carga de documentos KYC de aliados (a Storage, no base64)
- [x] i18n, dark mode y selector de idioma en app Users
- [x] Países con códigos de marcación
- [x] Schema de Supabase versionado (`supabase/migrations/`, GitHub Integration aplica en cada merge a `main`)

### Incompleto o placeholder
- [ ] **Mensajería:** sin tabla, sin endpoints, sin UI
- [ ] **Reviews/ratings:** mencionados en el blueprint, no existen
- [ ] **Notificaciones push (FCM):** no implementadas
- [ ] **Pagos reales:** tarjetas guardadas, sin procesador
- [ ] **Admin tab "Usuarios":** no re-verificado en esta pasada — antes mostraba solicitudes de foto, no lista de usuarios
- [ ] **Admin tab "Aliados":** no re-verificado en esta pasada
- [ ] **App Allies:** pantallas de perfil/configuración/dirección — no re-verificado en esta pasada
- [ ] **Filtros de búsqueda por ubicación:** no implementados

### Backlog activo
Ver `TASKS.md`. ⚠ `TASKS.md`, `APPLICATION_BLUEPRINT.md`, `backend_structure.txt` e `informe_normalizacion.md` **no fueron revisados en esta pasada** y todavía describen la arquitectura SQLite. Tratarlos como desactualizados hasta verificarlos contra el código.
