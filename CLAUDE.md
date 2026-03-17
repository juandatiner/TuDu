# CLAUDE.md — ToDo Ecosystem
> Última revisión: 2026-03-17 — generado leyendo código fuente real, no el blueprint.

---

## 1. PROJECT IDENTITY

**ToDo** es un marketplace de servicios locales (Colombia) que conecta usuarios (clientes) con aliados (prestadores de servicios), gestionado por un panel de administración.
Stack: Flutter/Dart (frontend multi-plataforma) + Node.js/Express (backends) + SQLite3 (5 bases de datos separadas) + Socket.io (tiempo real en users backend) + Mailgun (OTP por email).
Contexto geográfico: los datos de departamentos y ciudades están pre-cargados para Colombia (33 departamentos, ~1000+ ciudades).

---

## 2. ARCHITECTURE

| App | Frontend | Backend | Archivo principal | Puerto real |
|-----|----------|---------|-------------------|-------------|
| Users | `todo_users/users/` | `todo_users/backend/` | `index.js` | **3000** |
| Allies | `todo_allies/allies/` | `todo_allies/backend/` | `index.js` | **3002** |
| Admin | `todo_admin/admin/` | `todo_admin/backend/` | `server.js` | **3003** |

> **El blueprint dice que Users usa 3002 — eso es incorrecto.** El `index.js` de users usa `PORT || 3000`, `config.dart` del admin apunta a 3000. Aliases y admin no comparten puerto.

### Conexiones de bases de datos por backend

| Backend | DBs que abre |
|---------|-------------|
| Users (`index.js`) | `users.db`, `allies.db`, `services.db`, `search.db` (4 DBs) |
| Allies (`index.js`) | `allies.db`, `services.db` (2 DBs) |
| Admin (`server.js`) | `admins.db` (1 DB) |

> **`allies.db` y `services.db` son escritas por dos procesos simultáneos** (users y allies backends). No tienen WAL mode activo — punto de contención real en concurrencia.
> **`search.db` ya tiene WAL mode** activado en el código de users backend (`PRAGMA journal_mode = WAL`).

### Config Flutter (`config.dart` — igual en las 3 apps)
- `localIpAddress = '10.150.102.86'` ← cambiar manualmente al cambiar de red
- Android emulador → `10.0.2.2:PORT`, iOS simulador → `localhost:PORT`, físico → IP local
- Admin app apunta a puerto 3000 (users backend), no a 3003 (admin backend) — el admin llama a ambos

---

## 3. DATABASES

**Ruta absoluta base:** `/Users/juanda/ToDo/databases/`
Los backends usan `path.join(__dirname, '../../databases')` — nunca rutas hardcodeadas.

---

### users.db
Abierta por: **users backend** (lectura/escritura)

#### Tabla `users`
```sql
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  nombre TEXT NOT NULL,        -- máx 20 chars, validado en backend
  apellido TEXT NOT NULL,      -- máx 20 chars, validado en backend
  role TEXT DEFAULT 'user',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
-- Columnas agregadas via ALTER TABLE (no están en el CREATE original):
-- avatar_color TEXT DEFAULT '#78BF32'
-- avatar_icon  TEXT DEFAULT 'person'
-- avatar_image TEXT                    ← base64, puede ser varios MB
-- phone        TEXT
-- genero       TEXT
-- fecha_nacimiento TEXT
-- dark_mode    INTEGER DEFAULT 0
-- language     TEXT DEFAULT 'es'
```

#### Tabla `user_phones`
```sql
CREATE TABLE IF NOT EXISTS user_phones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT NOT NULL,
  country_code TEXT NOT NULL,
  country_name TEXT,
  phone_number TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_email) REFERENCES users(email),
  UNIQUE(user_email)            -- un teléfono por usuario
)
```

#### Tabla `photo_change_requests`
```sql
CREATE TABLE IF NOT EXISTS photo_change_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT NOT NULL,
  new_avatar_image TEXT NOT NULL,  -- base64
  status TEXT DEFAULT 'pending',   -- 'pending' | 'approved' | 'rejected'
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_email) REFERENCES users(email)
)
```

#### Tabla `countries`
```sql
CREATE TABLE IF NOT EXISTS countries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  iso_code TEXT UNIQUE NOT NULL,   -- 'CO', 'US', etc.
  name TEXT NOT NULL,
  dial_code TEXT NOT NULL,         -- '+57', '+1', etc.
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
-- Seeded: ~200 países del mundo
```

#### Tabla `departments`
```sql
CREATE TABLE IF NOT EXISTS departments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL
)
-- Seeded: 33 departamentos de Colombia
```

#### Tabla `cities`
```sql
CREATE TABLE IF NOT EXISTS cities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  department_id INTEGER,
  FOREIGN KEY (department_id) REFERENCES departments(id),
  UNIQUE(name, department_id)
)
-- Seeded: ~1000+ ciudades de Colombia
-- NOTA: Hay errores en los datos — 'Cali' aparece bajo Antioquia,
--       'Barranquilla' aparece bajo Bolívar, 'Luruaco' aparece bajo Bolívar.
```

#### Tabla `user_addresses`
```sql
CREATE TABLE IF NOT EXISTS user_addresses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT NOT NULL,
  address_name TEXT NOT NULL,
  department_id INTEGER,   -- agregado via ALTER TABLE
  city_id INTEGER,         -- agregado via ALTER TABLE
  type_via TEXT,           -- agregado via ALTER TABLE
  number_principal TEXT,   -- agregado via ALTER TABLE (originalmente INTEGER)
  number_secondary TEXT,   -- agregado via ALTER TABLE
  number_final TEXT,       -- agregado via ALTER TABLE
  additional_info TEXT,    -- agregado via ALTER TABLE
  address_icon TEXT,       -- agregado via ALTER TABLE
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_email) REFERENCES users(email),
  FOREIGN KEY (department_id) REFERENCES departments(id),
  FOREIGN KEY (city_id) REFERENCES cities(id)
)
```

#### Tabla `device_sessions`
```sql
CREATE TABLE IF NOT EXISTS device_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT NOT NULL,
  device_id TEXT NOT NULL,
  device_info TEXT,                        -- JSON con modelo, SO, versión
  is_active INTEGER DEFAULT 1,
  requires_verification INTEGER DEFAULT 0,
  last_activity DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_email) REFERENCES users(email),
  UNIQUE(user_email, device_id)
)
```

#### Tabla `user_cards`
```sql
CREATE TABLE IF NOT EXISTS user_cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT NOT NULL,
  card_number TEXT NOT NULL,       -- plain text ← problema de seguridad
  card_holder TEXT NOT NULL,
  expiry_date TEXT NOT NULL,
  card_type TEXT DEFAULT 'visa',
  document_type TEXT DEFAULT 'C.C',
  document_number TEXT,            -- plain text ← problema de seguridad
  card_mode TEXT DEFAULT 'credit', -- agregado via ALTER TABLE
  is_default INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_email) REFERENCES users(email)
  -- CVV fue eliminado via ALTER TABLE DROP COLUMN (PCI-DSS)
)
```

---

### allies.db
Abierta por: **users backend** (R/W) y **allies backend** (R/W) — sin WAL mode

#### Tabla `allies`
```sql
CREATE TABLE IF NOT EXISTS allies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  nombre TEXT NOT NULL,    -- máx 20 chars, validado en ambos backends
  apellido TEXT NOT NULL,  -- máx 20 chars, validado en ambos backends
  role TEXT DEFAULT 'ally',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
```

---

### services.db
Abierta por: **users backend** (R/W) y **allies backend** (R/W) — sin WAL mode

#### Tabla `services`
```sql
CREATE TABLE IF NOT EXISTS services (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
-- Seeded: 10 servicios (Servicio de hogar, Reparaciones eléctricas, Limpieza, etc.)
```

#### Tabla `services_in_search`
```sql
CREATE TABLE IF NOT EXISTS services_in_search (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,           -- FK manual → users.id en users.db
  title TEXT NOT NULL,
  description TEXT,
  time_quantity INTEGER,
  time_unit TEXT,
  budget TEXT,               -- formateado a centenas con comas (ej: "1,200")
  worker_info TEXT,
  status TEXT DEFAULT 'EN ESPERA',  -- 'EN ESPERA' | 'EN PROCESO' | 'COMPLETADO'
  assigned INTEGER DEFAULT 0,
  ally_id INTEGER,           -- FK manual → allies.id en allies.db
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
-- NOTA: NO tiene campo additional_info — el blueprint estaba equivocado.
-- BUG CONOCIDO: users backend /assign pone status='En Proceso' (mixed case),
--              allies backend /assign pone status='EN PROCESO' (correcto).
```

#### Tabla `ally_services`
```sql
CREATE TABLE IF NOT EXISTS ally_services (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ally_id INTEGER NOT NULL,
  service_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(ally_id, service_id)
)
```

---

### search.db
Abierta por: **users backend** — ya tiene WAL mode activo

#### Tabla `search_history`
```sql
CREATE TABLE IF NOT EXISTS search_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT NOT NULL,
  search_query TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
```

> **La tabla `messages` del blueprint NO existe en el código de creación de search.db.**
> El schema de messages fue documentado en el blueprint pero nunca implementado en código.

---

### admins.db
Abierta por: **admin backend** únicamente

#### Tabla `admins`
```sql
CREATE TABLE IF NOT EXISTS admins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,    -- plain text ← crítico
  email TEXT UNIQUE,
  name TEXT NOT NULL,
  role TEXT DEFAULT 'admin',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
-- Default admin: username='admin', password='123', email='admin@todoapp.com'
```

---

### Relaciones cross-database (sin FK real, join manual en código)
- `services_in_search.user_id` → `users.id` (users.db)
- `services_in_search.ally_id` → `allies.id` (allies.db)
- `ally_services.ally_id` → `allies.id` (allies.db)
- `ally_services.service_id` → `services.id` (services.db)
- `photo_change_requests.user_email` → `users.email` (misma DB)

---

## 4. API ENDPOINTS

### Users Backend — port 3000 (`todo_users/backend/index.js`)

**Autenticación**
```
POST /send-otp                          { email }
POST /verify-otp                        { email, otp } — backdoor '123456' hardcodeado
POST /check-user                        { email } → { exists, user }
POST /check-ally                        { email } → { exists, ally }  ← en users backend
POST /register-user                     { email, nombre, apellido }
POST /register-ally                     { email, nombre, apellido }   ← en users backend
```

**Servicios**
```
GET  /services                          → catálogo completo
POST /publish-service                   { user_email, title, description, time_quantity,
                                          time_unit, budget, worker_info }
GET  /services-in-search                query: ?user_email= (opcional, filtra por usuario)
PUT  /services-in-search/:id/assign     (sin body) → assigned=1, status='En Proceso' ← BUG DE CASE
PUT  /services-in-search/:id/status     { status }
DELETE /services-in-search/:id          query: ?user_email= (requerido para verificar ownership)
```

**Búsqueda**
```
POST /search-history                    { user_email, search_query }
GET  /search-history                    query: ?email=
DELETE /search-history/:id
GET  /search-services                   query: ?q=
```

**Perfil de usuario**
```
GET  /users/profile/:email
PUT  /users/profile/avatar              { email, avatar_image } o { email, avatar_color, avatar_icon }
PUT  /users/profile/data                { email, nombre, apellido, genero, fecha_nacimiento, phone }
GET  /users/profile/phone/:email
GET  /users/theme/:email
PUT  /users/theme                       { email, dark_mode }
GET  /users/language/:email
PUT  /users/language                    { email, language }
DELETE /users/:email                    — elimina user + addresses + phones (sin transacción)
```

**Direcciones**
```
GET  /user-addresses                    query: ?email=
POST /user-addresses                    { user_email, address_name, department_id, city_id, ... }
PUT  /user-addresses/:id
DELETE /user-addresses/:id
GET  /departments
GET  /cities                            query: ?department_id=
```

**Tarjetas**
```
GET  /users/cards/:userEmail
POST /users/cards                       { user_email, card_number, card_holder, expiry_date,
                                          card_type, document_type, document_number, card_mode }
PUT  /users/cards/:id/default
DELETE /users/cards/:id
```

**Países**
```
GET  /countries
GET  /countries/by-dial/:dialCode
GET  /countries/by-iso/:isoCode
```

**Sesiones de dispositivo**
```
POST /device-session/check              { email, device_id, device_info }
POST /device-session/register           { email, device_id, device_info }
GET  /device-session/status             query: ?email=&device_id=
POST /device-session/logout             { email, device_id }
GET  /device-session/list               query: ?email=
POST /device-session/close-others       { email, device_id }
```

**Foto de perfil (interfaz users ↔ admin)**
```
POST /api/user/photo-change-request     { user_email, new_avatar_image }
GET  /api/user/photo-change-request/pending  query: ?user_email=
GET  /api/admin/photo-change-requests   → todas las solicitudes (para admin panel)
PUT  /api/admin/photo-change-requests/:id    { status: 'approved'|'rejected' }
```

> Socket.io emite `newPhotoChangeRequest` al crear una solicitud.
> El admin Flutter llama a estos endpoints en el backend de users (puerto 3000).

---

### Allies Backend — port 3002 (`todo_allies/backend/index.js`)

> Endpoints confirmados leyendo el código real (no el blueprint).

```
POST /send-otp                          { email } — SIN backdoor '123456'
POST /verify-otp                        { email, otp } — DEV_MODE acepta cualquier código
POST /check-ally                        { email } → { exists, ally }
POST /register-ally                     { email, nombre, apellido }
GET  /services                          → catálogo
GET  /services-in-search                → servicios con assigned=0
PUT  /services-in-search/:id/assign     { ally_email } → assigned=1, status='EN PROCESO' (correcto)
PUT  /services-in-search/:id/status     { status }
GET  /my-services                       query: ?ally_email=
```

> El allies backend NO tiene Socket.io, ni endpoints de perfil, ni tarjetas, ni direcciones.
> `PUT /services-in-search/:id/assign` recibe `ally_email` (no `ally_id`) y hace join con allies.db para resolver el ID.

---

### Admin Backend — port 3003 (`todo_admin/backend/server.js`)

```
POST /api/admin/login                   { username, password } → plain text compare
GET  /api/admins                        → lista sin passwords
POST /api/admins                        { username, password, email, name, role }
PUT  /api/admins/:id                    { username, email, name, role } — NO cambia password
DELETE /api/admins/:id                  — sin protección del último admin
PUT  /api/admins/:id/change-password    { currentPassword, newPassword }
```

> El admin backend NO tiene Socket.io. Usa `app.listen` directo.
> El admin Flutter también llama endpoints del users backend (puerto 3000) para photo_change_requests.

---

## 5. AUTH FLOW

### OTP — Users backend (port 3000)
```
1. POST /send-otp { email }
   → genera OTP 6 dígitos (Math.random)
   → almacena en Map<email, { otp, timestamp }> — en memoria, se pierde al reiniciar
   → DEV_MODE=true: loguea en consola, no envía email
   → Mailgun activo solo si MAILGUN_API_KEY !== 'tu_api_key_de_mailgun' y no vacío
   → responde 200

2. POST /verify-otp { email, otp }
   → SI otp === '123456' → PASA siempre (backdoor hardcodeado, línea 1499)
   → SI DEV_MODE=true → acepta cualquier código
   → producción: verifica Map, comprueba expiración 10min, borra entrada
   → responde 200 o 400

3. POST /check-user { email }   (o /check-ally para el flujo de aliados)
   → { exists: true, user/ally: {...} } → ir a home
   → { exists: false } → ir a registro

4. POST /register-user { email, nombre, apellido }
   → valida nombre/apellido ≤ 20 chars
   → INSERT en users.db, devuelve { id }
```

### OTP — Allies backend (port 3002)
```
Igual que arriba EXCEPTO:
- NO tiene el backdoor '123456'
- Mailgun se inicializa SIN verificar credenciales — crash en arranque si MAILGUN_API_KEY no está definida
- DEV_MODE=true acepta cualquier código igualmente
```

### Admin — username + password plain text
```
POST /api/admin/login { username, password }
→ SELECT * FROM admins WHERE username=? AND password=?  (plain text, sin hash)
→ 200 { success: true, data: { id, username, email, name, role } }  (password no se devuelve)
→ 401 si no coincide
→ cliente guarda objeto admin en SharedPreferences
```

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
| Prefijo admin/user en endpoints | `/api/admin/` o `/api/user/` | solo para photo/admin mgmt |
| Campos de BD | `snake_case` | `created_at`, `dark_mode` |
| Roles en BD | inglés, minúsculas | `'user'`, `'ally'`, `'admin'` |
| Estados de servicio | español, MAYÚSCULAS | `'EN ESPERA'`, `'EN PROCESO'`, `'COMPLETADO'` |
| Estados de photo_request | inglés, minúsculas | `'pending'`, `'approved'`, `'rejected'` |

### Estructura Flutter (igual en las 3 apps)
```
lib/
├── main.dart        # MaterialApp, MultiProvider, rutas
├── config.dart      # Config class: URL, colores, IP, helpers de onboarding/UI
├── screens/         # Un archivo por pantalla; StatefulWidget por defecto
├── models/          # Data classes simples (sin ChangeNotifier)
├── providers/       # ChangeNotifier para estado global (theme, language)
├── services/        # Lógica de negocio, sesiones (solo en todo_users)
└── l10n/            # Localizaciones (solo en todo_users)
```

### Patrones de código observados
- **HTTP en widgets:** la mayoría de screens llaman `http.get/post` directamente en `initState` o botones — solo `session_service.dart` tiene capa de servicio correctamente separada
- **Error handling Flutter:** `try/catch` → `setState(() { _isLoading = false; })`, el error se loguea con `print()` o `debugPrint()`
- **Estado Flutter:** `setState()` en StatefulWidgets; `ChangeNotifier` para theme y language; no hay BLoC ni Riverpod
- **URLs Flutter:** siempre `${Config.baseUrl}/ruta` — nunca URLs hardcodeadas en screens
- **Socket.io Flutter:** `socket_io_client` — `initState()` conecta, `dispose()` desconecta; las dos screens admin que lo usan duplican el código de conexión
- **SQLite backend:** callbacks anidados (callback hell), no async/await — `db.run/get/all(sql, params, (err, row) => {...})`
- **Migraciones:** `ALTER TABLE ADD COLUMN` en el callback de apertura de DB; error `'duplicate column'` se ignora silenciosamente — sin sistema de versiones
- **JSON body:** `express.json({ limit: '50mb' })` — necesario para base64 de imágenes
- **Budget formatting:** presupuesto se redondea a centenas y se formatea con comas en `POST /publish-service`

### Colores (siempre vía `Config`, nunca hex hardcodeado en widgets)
```dart
Config.primaryColor    // Color(0xFF78BF32) — verde ToDo
Config.secondaryColor  // Color(0xFF595959) — gris
Config.backgroundColor // Color(0xFFF4F2F2) — fondo claro
Config.whiteColor      // Color(0xFFFFFFFF)
Config.blackColor      // Color(0xFF000000)
Config.redColor        // Color(0xFFF44336)
Config.textColor       // Color(0xFF78BF32) — igual que primary
```

---

## 7. ENVIRONMENT

### Users Backend — `todo_users/backend/.env`
```env
PORT=3000
MAILGUN_API_KEY=          # vacío o 'tu_api_key_de_mailgun' → Mailgun deshabilitado, modo desarrollo
MAILGUN_DOMAIN=           # dominio verificado en Mailgun
DEV_MODE=true             # true = OTP en consola, verify-otp acepta cualquier código
```

### Allies Backend — `todo_allies/backend/.env`
```env
PORT=3002
MAILGUN_API_KEY=          # REQUERIDO — el backend crashea en arranque si está vacío
MAILGUN_DOMAIN=           # REQUERIDO — igual que arriba
DEV_MODE=true             # true = verify-otp acepta cualquier código
```

> **Diferencia crítica:** el users backend verifica si MAILGUN_API_KEY está configurado antes de inicializar Mailgun. El allies backend inicializa Mailgun incondicionalmente — sin credenciales, el proceso crashea al arrancar.

### Admin Backend — `todo_admin/backend/.env`
```env
PORT=3003
```

### Flutter — cambio de IP (obligatorio al cambiar de red)
```dart
// En config.dart de cada app:
static const String localIpAddress = '10.150.102.86'; // ← CAMBIAR POR TU IP LOCAL
// Mac: ipconfig getifaddr en0 | Windows: ipconfig
```

---

## 8. CRITICAL RULES — NUNCA ROMPER

1. **Puertos reales:**
   - Users backend: `3000` (no 3002 como dice el blueprint)
   - Allies backend: `3002`
   - Admin backend: `3003`
   - Admin Flutter llama a puerto `3000` (users) para photo_change_requests

2. **Rutas absolutas de las 5 DBs:**
   ```
   /Users/juanda/ToDo/databases/users.db
   /Users/juanda/ToDo/databases/allies.db
   /Users/juanda/ToDo/databases/services.db
   /Users/juanda/ToDo/databases/search.db
   /Users/juanda/ToDo/databases/admins.db
   ```

3. **Roles en BD — strings exactos:** `'user'`, `'ally'`, `'admin'` (minúsculas, en inglés). Cualquier variación rompe la lógica.

4. **Estados de servicio — strings exactos:** `'EN ESPERA'`, `'EN PROCESO'`, `'COMPLETADO'` (español, mayúsculas). BUG ACTIVO: users backend `/assign` pone `'En Proceso'` (mixed case) en lugar de `'EN PROCESO'`.

5. **`photo_change_requests` vive en `users.db`.** El admin backend accede a ella llamando HTTP al users backend (puerto 3000), no abre users.db directamente.

6. **No hay JWT.** El backend no valida identidad en la mayoría de endpoints — acepta cualquier email en el body/query. La autenticación real solo existe en el flujo OTP y en admin login.

7. **Socket.io está en el proceso de users backend** (puerto 3000, `http.createServer`). El admin Flutter se conecta al Socket.io del users backend, no al admin backend.

8. **`allies.db` y `services.db` son escritas por dos procesos.** Users backend escribe en `allies.db` (via `/register-ally`) y en `services.db` (via `/publish-service`, `/assign`). Allies backend también escribe en ambas. Sin WAL mode activo en estas DBs.

9. **Allies backend necesita credenciales Mailgun al arrancar.** A diferencia del users backend, no tiene guard de credenciales — arranca o crashea según exista `MAILGUN_API_KEY`.

10. **`services_in_search` NO tiene campo `additional_info`** en el schema real — el blueprint lo listaba pero no está en el `CREATE TABLE` del código.

---

## 9. KNOWN ISSUES — DEUDA TÉCNICA

### Seguridad (crítico — bloquea producción)
- **Backdoor `'123456'`** en users `/verify-otp` (línea 1499): acepta este código para cualquier email sin restricción
- **Passwords de admin en plain text** en `admins.db` — sin hashing
- **Sin JWT ni auth middleware** — cualquier cliente que conozca un email puede leer/modificar el perfil de ese usuario
- **CORS abierto** (`origin: "*"`) en los 3 backends y en Socket.io
- **Sin rate limiting** en `/send-otp` — abierto a spam de emails Mailgun
- **OTPs en memoria** (Map de Node.js) — se pierden en cada reinicio del servidor
- **Números de tarjeta en plain text** en `user_cards.card_number`
- **`DELETE /users/:email` sin auth** — cualquiera puede eliminar la cuenta de cualquier usuario

### Bugs activos
- **Status case inconsistency:** users `/services-in-search/:id/assign` pone `'En Proceso'` pero el valor correcto es `'EN PROCESO'` — breaks filtros que comparan por estado
- **`DELETE /users/:email` sin transacción** — 3 deletes secuenciales sin BEGIN/COMMIT; usuario puede quedar con datos huérfanos si falla uno
- **`cities` con datos incorrectos** — 'Cali' aparece bajo Antioquia, 'Barranquilla' bajo Bolívar, 'Luruaco' bajo Bolívar (están en departamentos equivocados)
- **Mailgun en allies crashea sin credenciales** — se inicializa incondicionalmente, sin guard

### Deuda de arquitectura
- **`allies.db` y `services.db` sin WAL mode** — escrituras concurrentes de dos procesos pueden causar `SQLITE_BUSY`
- **Sin sistema de migraciones** — ALTER TABLE acumulados en el callback de apertura, ignorando `duplicate column`; no hay versión de schema
- **Imágenes base64 en SQLite** — `avatar_image` y `new_avatar_image` pueden ser varios MB por registro; `multer` está instalado pero comentado
- **Socket.io duplicado en Flutter** — `dashboard_screen.dart` y `photo_change_requests_screen.dart` replican el mismo código de conexión
- **Firebase comentado** — import y init comentados en users backend (líneas 13-18); `firebase-admin.json` no existe

### Deuda de frontend
- **IP hardcodeada** en `config.dart` de las 3 apps — no hay `--dart-define` ni `.env`
- **Lógica HTTP en widgets** — la mayoría de screens hacen `http.get/post` directamente, sin capa de servicios
- **Sin expiración de sesión** — `SharedPreferences` persiste indefinidamente

---

## 10. CURRENT STATE

### Implementado y funcional
- [x] Auth OTP completo (users y allies)
- [x] Auth admin (username/password)
- [x] Registro de usuarios y aliados (con validación de 20 chars)
- [x] Catálogo de 10 servicios (seeded)
- [x] Publicar y buscar servicios (`services_in_search`)
- [x] Asignación de servicios a aliados (`PUT /assign`)
- [x] Actualización de estado de servicios
- [x] Historial de búsquedas
- [x] Perfil de usuario (datos personales, avatar color/icono/foto)
- [x] Gestión de direcciones (con 33 departamentos y ~1000 ciudades de Colombia)
- [x] Gestión de tarjetas de pago (guardado, sin procesador real)
- [x] Solicitudes de cambio de foto con aprobación de admin
- [x] Socket.io para notificaciones en tiempo real (photo_change_requests)
- [x] Panel admin: login, CRUD de admins, cambio de contraseña
- [x] Pantalla admin de photo_change_requests
- [x] Sistema de sesiones por dispositivo (device_sessions completo)
- [x] i18n en app Users (l10n/)
- [x] Dark mode y selector de idioma en app Users
- [x] Países del mundo con códigos de marcación (seeded)

### Incompleto o placeholder
- [ ] **`messages` table:** en el blueprint, no implementada en código (search.db no la crea)
- [ ] **Admin tab "Usuarios":** muestra solicitudes de foto, no lista de usuarios
- [ ] **Admin tab "Aliados":** "Funcionalidad en construcción"
- [ ] **Admin cards "Solicitud 2/3/4":** placeholders que navegan a `PhotoChangeRequestsScreen`
- [ ] **Mensajería:** sin endpoints ni UI
- [ ] **Reviews/ratings:** mencionados en blueprint, no existen en código
- [ ] **Notificaciones push (FCM):** Firebase comentado
- [ ] **Pagos reales:** tarjetas guardadas, sin procesador de pagos
- [ ] **App Allies:** sin pantallas de perfil, configuración ni dirección
- [ ] **Filtros por ubicación:** mencionados en blueprint, no implementados

### Backlog activo
Ver `TASKS.md` — 37 tareas priorizadas, ~120h estimadas.
Secuencia recomendada: TASK-001 → TASK-033 → TASK-032 → TASK-036 → TASK-006 → TASK-037 → TASK-002 → TASK-003
