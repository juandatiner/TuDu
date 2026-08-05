# CLAUDE.md — tudu Ecosystem

> Última revisión: 2026-08-05 — generado leyendo el código fuente real (`index.js`, `server.js`, `auth.js`, `rate_limit.js`, `cors_config.js`, `sms_otp.js`, `storage.js`, `config.dart`, `package.json`), no el blueprint.
>
> **Cambio mayor de esta revisión:** la pasada anterior (2026-07-28) quedó desactualizada casi de inmediato — el backend recibió una ronda de hardening real (commit "OTP por SMS, validación uniforme...") que la sección 9 todavía describía como pendiente. Se verificó **contra el código, no de memoria**: JWT propio con auth/refresh (§5), rate limiting, bcrypt, CORS por allowlist, imágenes ya migradas a Supabase Storage, y casi todos los "bugs activos" y "backdoors" antes documentados **ya no existen**. Además, el schema de Supabase quedó versionado con el Supabase CLI (`supabase/migrations/` + `supabase/seed.sql`, proyecto linkeado — detalle en `@supabase/CLAUDE.md`). Ver §9.
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

> El schema autoritativo es `supabase/migrations/20260805171636_remote_schema.sql`, no el dashboard. Las columnas listadas abajo son referencia rápida — para detalle exacto o trabajar con migrations, ver `@supabase/CLAUDE.md`.

### `users`
Columnas exactas: ver migrations. Gotchas: `avatar_color`/`avatar_icon` tienen default (`#78BF32`/`person`); `avatar_image` es URL de Storage, no base64.

`GET /users/profile/:email?lite=true` omite `avatar_image` del select — usar siempre que no se necesite la foto.

### `user_phones`
`user_email` es UNIQUE — hay upsert con `onConflict: 'user_email'`.

### `user_addresses`
El join a `departments(name)` / `cities(name)` se hace con la sintaxis anidada de Supabase y se aplana a `department_name` / `city_name` antes de responder.

### `user_cards`
`card_number` se guarda enmascarado (`**** **** **** 1234`), nunca completo. La primera tarjeta de un usuario se marca `is_default` automáticamente.

### `device_sessions` / `ally_device_sessions`
`device_sessions` tiene constraint compuesta `(user_email, device_id)` — el users backend hace upsert con `onConflict: 'user_email,device_id'`. El allies backend **no** usa upsert; hace select-then-insert-or-update manual.

Regla de negocio: registrar un dispositivo desactiva todos los demás del mismo email (sesión única).

### `photo_change_requests`
Limpieza automática: `cleanupOldPhotoRequests()` borra las que tienen `user_notified = true`. **Ya no es un `setInterval` en producción** — el job real vive en `pg_cron` (`supabase/migrations/20260805172201_cron_jobs.sql`, cada hora, corre dentro de Postgres). El `setInterval` en Node sigue en el código como respaldo para desarrollo local, pero solo se activa con `MANTENIMIENTO_EN_PROCESO=true` — apagado por defecto.

### `search_history`
⚠ La columna se llama `query`, pero la API la expone como `search_query` (regla #11). Se devuelven las últimas 10.

### `services`
Catálogo compartido. Los aliados pueden crear entradas nuevas vía `POST /services` (allies backend).

### `services_in_search`
`budget` se normaliza en `POST /publish-service`: se parsea a número, se redondea a la centena más cercana y se re-formatea con separador de miles.

### `allies`
Campos `kyc_*` son URLs/rutas del bucket privado `kyc` — leídas con URL firmada, ver `storage.js`. KYC tiene flujo de revisión completo: `GET/PUT /api/admin/kyc*` en el backend de allies, más `kyc_review_screen.dart` en el panel admin.

### `ally_service_profiles`
Clave es `ally_email` (no `ally_id`) — el mismatch viejo que hacía que `check-ally` nunca encontrara los perfiles ya está corregido.

### `admins`
`password` es bcrypt; filas heredadas en texto plano se migran a hash automáticamente en su próximo login exitoso (`passwordCoincide` en `tudu_admin/backend/server.js`).

### `departments`, `cities`, `countries`
Catálogos pre-cargados. `cities.department_id` → `departments.id`. `countries` incluye códigos de marcación. Los datos incorrectos que había antes (Cali bajo Antioquia, Barranquilla/Luruaco bajo Bolívar) **ya están corregidos** — verificado contra `supabase/seed.sql`.

### Imágenes: Storage, no base64

`avatar_image`, `new_avatar_image` y los 3 campos `kyc_*` guardan **URLs de Supabase Storage** (bucket `avatars` público, `kyc` privado con URL firmada — ver `@supabase/CLAUDE.md` buckets), no base64 dentro de Postgres. La subida pasa por `subirImagen()` en `storage.js`: si el bucket falla o no existe, cae a guardar el base64 tal cual para no romper la funcionalidad — así que en teoría puede aparecer una fila vieja con base64 crudo si la subida falló en su momento, pero el camino normal ya no pasa por Postgres.

---

## 4. API ENDPOINTS

Detalle de rutas por backend — cada uno carga solo cuando se trabaja en esa carpeta:
- Users (3000): `@tudu_users/backend/CLAUDE.md`
- Allies (3002): `@tudu_allies/backend/CLAUDE.md`
- Admin (3003): `@tudu_admin/backend/CLAUDE.md`

Regla transversal (aplica a users y allies): fuera de rutas públicas (OTP, catálogos de solo lectura, búsqueda, `/auth/refresh`), **todo exige `Authorization: Bearer <token>`** válido, y el dueño del token solo puede operar sobre su propio email/fila (ver §5).

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

Lista completa de variables por backend (requeridas/opcionales/defaults): skill `env-setup` — se carga cuando hace falta, no acá.

> `SUPABASE_SERVICE_ROLE_KEY` **bypassa RLS**. Nunca exponerla al cliente ni commitearla.
>
> `JWT_SECRET` **debe ser el mismo valor en los 3 backends** — un token firmado por uno se valida en los otros dos (así el rol `admin` funciona cruzado). Si no está seteado, cada backend hace `process.exit(1)` al arrancar.

### Toolchain de desarrollo (macOS)

Versiones exactas: `flutter --version`, `node --version`, etc. — re-verificar en vez de confiar en un snapshot viejo.

Variables en `~/.zshrc`:
```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
```

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

> Historial de bugs/backdoors ya resueltos: ver `git log`, no repetido acá. Lo que queda genuinamente abierto:

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
