# CLAUDE.md — tudu Ecosystem

> Última revisión: 2026-07-28 — generado leyendo el código fuente real (`index.js`, `server.js`, `config.dart`, `package.json`), no el blueprint.
>
> **Cambio mayor respecto a la revisión anterior (2026-03-17):** el backend migró de **SQLite local a Supabase (Postgres)**. Toda la sección de DBs fue reescrita. Ver §3.

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

Handshake: `auth.email` y `auth.device` (JSON string con `model` / `name` / `platform`).

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

> El schema vive en Supabase, no en el repo. No hay migraciones versionadas ni archivos SQL acá. Las columnas listadas abajo están **inferidas del uso en el código** — no de un `CREATE TABLE`. Para el schema autoritativo, mirar el dashboard de Supabase.

### `users`
Campos usados: `id`, `email` (único), `nombre`, `apellido`, `avatar_color` (default `#78BF32`), `avatar_icon` (default `person`), `avatar_image` (base64, puede ser varios MB), `phone`, `genero`, `fecha_nacimiento`, `dark_mode` (int 0/1), `language`, `created_at`.

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
`id`, `user_email`, `new_avatar_image` (base64), `status` (`pending` / `approved` / `rejected`), `rejection_reason`, `read_at`, `user_notified` (bool), `created_at`, `updated_at`.

Limpieza automática: `cleanupOldPhotoRequests()` borra las que tienen `user_notified = true`, al arrancar el server y luego **cada hora** (`setInterval`), más una limpieza inmediata al marcar como notificada.

### `search_history`
`user_email`, `query` (⚠ la columna se llama `query`, pero la API la expone como `search_query`), `created_at`. Se devuelven las últimas 10.

### `services`
`id`, `name`, `created_at`. Catálogo compartido. Los aliados pueden crear entradas nuevas vía `POST /services` (allies backend).

### `services_in_search`
`id`, `user_email`, `ally_email`, `title`, `description`, `time_quantity`, `time_unit`, `budget` (string ya formateado con comas), `worker_info`, `status`, `assigned` (int 0/1), `created_at`.

`budget` se normaliza en `POST /publish-service`: se parsea a número, se redondea a la centena más cercana y se re-formatea con separador de miles.

### `allies`
`id`, `email` (único), `nombre`, `apellido`, `fecha_nacimiento`, `kyc_cedula_frente`, `kyc_cedula_reverso`, `kyc_selfie` (los 3 base64), `kyc_status` (`submitted`), `kyc_submitted_at`, `updated_at`.

### `ally_service_profiles`
`ally_email`, `service_id`, `nombre_comercial`, `frase_presentacion`, `resumen`, `created_at`.

> ⚠ **Inconsistencia real:** `POST /ally-service-profile` inserta con `ally_email`, pero `POST /check-ally` consulta con `.eq('ally_id', ally.id)`. Uno de los dos está mal — `check-ally` nunca va a encontrar los perfiles creados. Ver §9.

### `admins`
`id`, `username` (único), `password` (**plain text**), `email` (único), `name`, `role` (default `admin`), `created_at`, `updated_at`.

### `departments`, `cities`, `countries`
Catálogos pre-cargados. `cities.department_id` → `departments.id`. `countries` incluye códigos de marcación.

### Código SQLite muerto (no ejecutar)
Quedaron archivos de la arquitectura anterior que **ya no se usan** y apuntan a `../../databases`, ruta que no existe:
- `tudu_allies/backend/index.js.old`, `tudu_allies/backend/index.sqlite.js`
- `tudu_admin/backend/server.sqlite.js`
- `tudu_admin/backend/init-db.js` (y su script `npm run init-db`) — requiere `sqlite3`, que ya no está en `package.json`

---

## 4. API ENDPOINTS

### Users Backend — puerto 3000 (`tudu_users/backend/index.js`)

**Auth y registro**
| Método | Ruta | Notas |
|--------|------|-------|
| POST | `/send-otp` | Supabase Auth `signInWithOtp`. Bypass si `DEV_MODE=true` y email = `cosmodavid2009@gmail.com` |
| POST | `/verify-otp` | Supabase Auth `verifyOtp`. Backdoor: `otp === '123456'` **solo** con email `cosmodavid2009@gmail.com` |
| POST | `/check-user` | `{exists, user}` |
| POST | `/check-ally` | `{exists, ally}` |
| POST | `/register-user` | |
| POST | `/register-ally` | |

**Perfil**
| Método | Ruta | Notas |
|--------|------|-------|
| GET | `/users/profile/:email` | `?lite=true` omite `avatar_image` |
| PUT | `/users/profile/avatar` | `avatar_image: null` vuelve a color+icono; con imagen resetea color a `#78BF32` |
| PUT | `/users/profile/data` | upsert de `user_phones` si vienen `country_code` + `phone_number` |
| DELETE | `/users/:email` | Borra en cascada manual sobre 6 tablas. **Sin auth, sin transacción** |

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
| POST | `/send-otp` | Igual que users |
| POST | `/verify-otp` | ⚠ Backdoor `'123456'` **para cualquier email** (a diferencia de users) |
| POST | `/check-ally` | Devuelve `partial: 'personal'` o `partial: 'service'` según qué falte |
| POST | `/register-ally` | upsert con `onConflict: 'email'` |
| POST | `/ally-kyc` | Sube 3 imágenes base64, marca `kyc_status = 'submitted'` |
| POST | `/ally-service-profile` | |
| GET | `/services` | |
| POST | `/services` | Crea servicio nuevo (mín. 2 chars) |
| GET | `/services-in-search` | Solo `assigned = 0` |
| PUT | `/services-in-search/:id/assign` | Requiere `ally_email`; pone `status: 'EN PROCESO'` |
| PUT | `/services-in-search/:id/status` | |
| GET | `/my-services?ally_email=` | |
| — | `/ally-device-session/*` | check · register · status · logout · list · close-others |

`POST /ally-device-session/check` fuerza `requires_verification: true` para `cosmodavid2009@gmail.com`.

### Admin Backend — puerto 3003 (`tudu_admin/backend/server.js`)

`GET /` (health) · `POST /api/admin/login` · `GET /api/admins` · `POST /api/admins` · `PUT /api/admins/:id` · `DELETE /api/admins/:id` · `PUT /api/admins/:id/change-password`

El login compara `password` en plain text con `.eq('password', password)`. Código Postgres `23505` (unique violation) se traduce a "Username or email already exists".

---

## 5. AUTH FLOW

### OTP (users y allies) — Supabase Auth

1. Cliente → `POST /send-otp { email }`
2. Backend → `supabase.auth.signInWithOtp({ email })` — **Supabase envía el correo**, no Mailgun
3. Cliente → `POST /verify-otp { email, otp }`
4. Backend → `supabase.auth.verifyOtp({ email, token: otp, type: 'email' })`
5. Backend responde `{ message }` — **no devuelve token ni sesión al cliente**

> El backend descarta la sesión que devuelve Supabase. El cliente queda "autenticado" solo por convención: guarda el email en `SharedPreferences` y lo manda en cada request. **No hay JWT en el resto de la API.**

**Mailgun ya no se usa para OTP.** El allies backend todavía inicializa el cliente (`mg`) si hay credenciales, pero la variable nunca se vuelve a usar — es código muerto. Ya **no** crashea sin credenciales (a diferencia de la versión SQLite).

### Admin — username + password plain text
`POST /api/admin/login` → select directo por `username` + `password`. Sin hashing, sin sesión, sin token. La app guarda los datos del admin en local.

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

**`tudu_users/backend/.env`**
```env
PORT=3000
SUPABASE_URL=                 # REQUERIDO — process.exit(1) si falta
SUPABASE_SERVICE_ROLE_KEY=    # REQUERIDO — process.exit(1) si falta
DEV_MODE=true                 # bypass de /send-otp solo para cosmodavid2009@gmail.com
```

**`tudu_allies/backend/.env`**
```env
PORT=3002
SUPABASE_URL=                 # REQUERIDO
SUPABASE_SERVICE_ROLE_KEY=    # REQUERIDO
MAILGUN_API_KEY=              # opcional — código muerto, ya no se usa para OTP
MAILGUN_DOMAIN=               # opcional — ídem
DEV_MODE=true
```

**`tudu_admin/backend/.env`**
```env
PORT=3003
SUPABASE_URL=                 # REQUERIDO
SUPABASE_SERVICE_ROLE_KEY=    # REQUERIDO
```

> `SUPABASE_SERVICE_ROLE_KEY` **bypassa RLS**. Nunca exponerla al cliente ni commitearla.

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

5. **Estados de servicio — strings exactos:** `'EN ESPERA'`, `'EN PROCESO'`. **BUG ACTIVO:** users `/services-in-search/:id/assign` escribe `'En Proceso'` (mixed case); allies escribe `'EN PROCESO'`. Ver §9.

6. **Socket.io de negocio vive solo en el users backend (3000).** El admin Flutter se conecta ahí. El allies backend tiene Socket.io pero solo para logging.

7. **`photoRequestUpdated` debe incluir `new_avatar_image`** cuando el status es `approved` — el Provider de Flutter depende de ese campo para refrescar el avatar sin recargar.

8. **No hay JWT.** Fuera del flujo OTP y del login de admin, ningún endpoint valida identidad: aceptan cualquier email en body o query.

9. **`error.code === 'PGRST116'` significa "no encontrado"**, no un fallo. Tratarlo como caso normal, igual que hace `check-user` / `check-ally`.

10. **`user_phones` y `device_sessions` dependen de constraints UNIQUE en Supabase** (`user_email` y `(user_email, device_id)`). Si se borran, los upsert con `onConflict` fallan.

11. **`search_history` guarda la columna `query`** pero la API la expone como `search_query`. No unificar sin tocar el cliente.

---

## 9. KNOWN ISSUES — DEUDA TÉCNICA

### Seguridad (crítico — bloquea producción)
- **Backdoor OTP en allies** (`tudu_allies/backend/index.js:122`): `if (otp === '123456') return ...` — **cualquier email** entra sin verificar. El equivalente en users (`index.js:94`) está acotado a `cosmodavid2009@gmail.com`, pero igual debe salir antes de producción.
- **Passwords de admin en plain text** (`admins.password`) — sin hashing, comparados con `.eq()`.
- **Service role key en los 3 backends** — bypassa RLS por completo. No hay políticas de fila efectivas.
- **Sin JWT ni middleware de auth** — quien conozca un email puede leer y modificar ese perfil.
- **CORS abierto** (`origin: "*"`) en los 3 backends y en Socket.io.
- **Sin rate limiting** en `/send-otp` — abierto a spam contra la cuota de Supabase Auth.
- **`DELETE /users/:email` sin auth** — cualquiera borra la cuenta de cualquiera.
- **El backend descarta la sesión de Supabase Auth** y no la devuelve al cliente, así que no hay forma de verificar identidad después del OTP.

### Bugs activos
- **`ally_service_profiles` con clave inconsistente:** `POST /ally-service-profile` inserta usando `ally_email` (`index.js:218`), pero `POST /check-ally` busca con `.eq('ally_id', ally.id)` (`index.js:152`). El check nunca encuentra los perfiles → el aliado queda atrapado en `partial: 'service'`.
- **Status case inconsistency:** users `/assign` escribe `'En Proceso'` (`index.js:484`), allies escribe `'EN PROCESO'` (`index.js:271`). Rompe cualquier filtro que compare por igualdad exacta.
- **`POST /users/cards` detecta duplicados con `.like('%1234')`** sobre los últimos 4 dígitos — falsos positivos entre tarjetas distintas del mismo usuario.
- **`DELETE /users/:email` sin transacción** — 7 deletes secuenciales; si uno falla quedan datos huérfanos.
- **`GET /api/user/photo-change-request/unnotified` ignora el error** de Supabase y siempre responde `success: true`.
- **`cities` con datos incorrectos** (heredado): 'Cali' bajo Antioquia, 'Barranquilla' y 'Luruaco' bajo Bolívar.

### Deuda de arquitectura
- **Imágenes base64 en columnas de Postgres** — `avatar_image`, `new_avatar_image`, y los 3 campos KYC pueden pesar varios MB por fila. Deberían ir a Supabase Storage.
- **Sin migraciones versionadas** — el schema solo existe en el dashboard de Supabase; no hay SQL en el repo ni forma de recrear el entorno desde cero.
- **Código SQLite muerto sin borrar** — `index.js.old`, `index.sqlite.js`, `server.sqlite.js`, `init-db.js` y el script `npm run init-db` (que ni siquiera tiene ya la dependencia `sqlite3`).
- **Mailgun muerto en allies** — se inicializa `mg` y nunca se usa; `mailgun-js` sigue en `package.json`.
- **`users` backend duplica endpoints de allies** (`/check-ally`, `/register-ally`) con lógica más simple que la del allies backend.
- **Limpieza de fotos por `setInterval`** — se pierde si el proceso reinicia; debería ser un cron o una función de Supabase.

### Deuda de frontend
- **Lógica HTTP en widgets** — la mayoría de screens hacen `http.get/post` directo, sin capa de servicios.
- **Sin expiración de sesión** — `SharedPreferences` persiste indefinidamente.
- **`config.dart` divergente entre las 3 apps** — misma lógica copiada con imports y comentarios distintos.

---

## 10. CURRENT STATE

### Implementado y funcional
- [x] Auth OTP vía Supabase Auth (users y allies)
- [x] Auth admin (username/password)
- [x] Registro de usuarios y aliados
- [x] Catálogo de servicios + creación de servicios nuevos desde allies
- [x] Publicar y buscar servicios (`services_in_search`)
- [x] Asignación de servicios a aliados y cambio de estado
- [x] Historial de búsquedas (últimas 10)
- [x] Perfil de usuario (datos, avatar color/icono/foto)
- [x] Direcciones (33 departamentos, ~1000 ciudades)
- [x] Tarjetas de pago (enmascaradas, sin procesador real)
- [x] Solicitudes de cambio de foto con aprobación de admin + limpieza automática
- [x] Socket.io en tiempo real para photo_change_requests
- [x] Panel admin: login, CRUD de admins, cambio de contraseña
- [x] Sesiones por dispositivo (users y allies, sesión única)
- [x] Carga de documentos KYC de aliados
- [x] i18n, dark mode y selector de idioma en app Users
- [x] Países con códigos de marcación

### Incompleto o placeholder
- [ ] **Revisión de KYC:** los documentos se suben y quedan en `submitted`; no hay endpoint ni UI de admin para aprobar/rechazar
- [ ] **`ally_service_profiles`:** roto por el mismatch `ally_email` / `ally_id` (ver §9)
- [ ] **Mensajería:** sin tabla, sin endpoints, sin UI
- [ ] **Reviews/ratings:** mencionados en el blueprint, no existen
- [ ] **Notificaciones push (FCM):** no implementadas
- [ ] **Pagos reales:** tarjetas guardadas, sin procesador
- [ ] **Admin tab "Usuarios":** muestra solicitudes de foto, no lista de usuarios
- [ ] **Admin tab "Aliados":** "Funcionalidad en construcción"
- [ ] **App Allies:** sin pantallas de perfil, configuración ni dirección
- [ ] **Filtros por ubicación:** no implementados

### Backlog activo
Ver `TASKS.md`. ⚠ `TASKS.md`, `APPLICATION_BLUEPRINT.md`, `backend_structure.txt` e `informe_normalizacion.md` **no fueron revisados en esta pasada** y todavía describen la arquitectura SQLite. Tratarlos como desactualizados hasta verificarlos contra el código.
