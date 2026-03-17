# TASKS.md — ToDo Ecosystem
> Última actualización: 2026-03-17
> Generado leyendo código fuente real. Ordenado por riesgo.
> Ver CLAUDE.md para contexto completo del proyecto.

---

## SEGURIDAD CRÍTICA

### TASK-001: Eliminar backdoor '123456' en /verify-otp (users backend)
- **App**: users
- **Prioridad**: CRÍTICA
- **Estimado**: 30min
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En `todo_users/backend/index.js` línea 1499, eliminar el bloque `if (otp === '123456') { return res.json(...) }`. Este código hace que cualquier persona con acceso a la red pueda autenticarse con cualquier email usando el código fijo, sin necesidad de acceso al correo.

---

### TASK-002: Hashear contraseñas de admins con bcrypt
- **App**: admin
- **Prioridad**: CRÍTICA
- **Estimado**: 3h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Instalar `bcrypt` en `todo_admin/backend`. Reemplazar comparación plain text en `POST /api/admin/login` por `bcrypt.compare()`. En `POST /api/admins` y `PUT /api/admins/:id/change-password` hashear con `bcrypt.hash(password, 10)` antes de insertar. Migrar admin por defecto en `init-db.js` para que su password se guarde hasheado.

---

### TASK-003: Implementar JWT en todos los endpoints protegidos
- **App**: users, allies, admin
- **Prioridad**: CRÍTICA
- **Estimado**: 6h
- **Depende de**: TASK-002
- **Estado**: PENDIENTE
- **Qué hacer**: Instalar `jsonwebtoken`. Emitir JWT al finalizar `/verify-otp` (users/allies) y `/api/admin/login`. Crear middleware `authenticateToken(req, res, next)` y aplicarlo a todos los endpoints que operan datos de usuario específico (perfil, direcciones, tarjetas, servicios propios). El cliente Flutter almacena el token en SharedPreferences y lo envía en `Authorization: Bearer`.

---

### TASK-004: Restringir CORS a orígenes conocidos
- **App**: users, allies, admin
- **Prioridad**: CRÍTICA
- **Estimado**: 1h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En los 3 backends, reemplazar `app.use(cors())` por `app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost'] }))`. Agregar `ALLOWED_ORIGINS` a los `.env`. Restringir también el Socket.io en users backend: `new Server(server, { cors: { origin: process.env.ALLOWED_ORIGINS } })`.

---

### TASK-005: Agregar rate limiting a /send-otp
- **App**: users, allies
- **Prioridad**: CRÍTICA
- **Estimado**: 1h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Instalar `express-rate-limit` en ambos backends. Crear limiter de máx 3 requests por IP + email cada 10 minutos solo para `POST /send-otp`. Sin esto, cualquiera puede usar el endpoint para enviar miles de emails via Mailgun a cualquier dirección.

---

### TASK-006: Persistir OTPs en SQLite en lugar de Map en memoria
- **App**: users, allies
- **Prioridad**: CRÍTICA
- **Estimado**: 2h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Crear tabla `otp_codes (email TEXT PRIMARY KEY, code TEXT NOT NULL, expires_at DATETIME NOT NULL)` en `users.db` y en `allies.db`. Reemplazar el `const otpStore = new Map()` por INSERT/SELECT en esa tabla. Agregar limpieza de expirados en cada `/send-otp`. Sin esto, cada reinicio del servidor invalida todos los OTPs activos silenciosamente.

---

### TASK-007: Proteger DELETE /users/:email contra borrado cruzado
- **App**: users
- **Prioridad**: CRÍTICA
- **Estimado**: 30min
- **Depende de**: TASK-003
- **Estado**: PENDIENTE
- **Qué hacer**: Una vez implementado JWT (TASK-003), en `DELETE /users/:email` agregar: `if (req.user.email !== req.params.email) return res.status(403).json({ error: 'Forbidden' })`. Sin esto, cualquier usuario autenticado puede eliminar la cuenta de otro pasando el email como path param.

---

### TASK-008: Enmascarar número de tarjeta antes de persistir en BD
- **App**: users
- **Prioridad**: CRÍTICA
- **Estimado**: 2h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En `POST /users/cards` (línea 2150), antes del INSERT, guardar solo los últimos 4 dígitos: `const maskedCard = '*'.repeat(12) + normalizedCardNumber.slice(-4)`. Actualizar `GET /users/cards/:userEmail` para que nunca devuelva el número completo. Evaluar si `document_number` también debe enmascararse o eliminarse.

---

## CONFLICTOS DE ARQUITECTURA

### TASK-009: Habilitar WAL mode en allies.db y services.db
- **App**: users, allies
- **Prioridad**: ALTA
- **Estimado**: 1h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En users backend y allies backend, inmediatamente después de abrir `allies.db` y `services.db`, ejecutar `db.run('PRAGMA journal_mode=WAL')`. `search.db` ya tiene WAL activo — no tocar. Sin WAL, escrituras concurrentes desde ambos backends causan `SQLITE_BUSY` en producción.

---

### TASK-010: Resolver duplicidad de endpoints de aliados en users backend
- **App**: users, allies
- **Prioridad**: ALTA
- **Estimado**: 2h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: El users backend tiene `POST /check-ally` (línea 1555) y `POST /register-ally` (línea 1603) porque necesita acceder a `allies.db` para `publish-service`. Documentar explícitamente este diseño en los comentarios del código. Los clientes Flutter de allies deben usar el allies backend (3002) para auth, y el users backend (3000) solo los necesita internamente para joins.

---

### TASK-011: Crear script de inicio unificado para los 3 backends
- **App**: all
- **Prioridad**: ALTA
- **Estimado**: 1h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Crear `package.json` raíz con `"dev": "concurrently \"cd todo_users/backend && node index.js\" \"cd todo_allies/backend && node index.js\" \"cd todo_admin/backend && node server.js\""`. Instalar `concurrently` como devDependency raíz. Actualmente no hay forma de iniciar el ecosistema completo con un comando.

---

### TASK-012: Corregir inicialización incondicional de Mailgun en allies backend
- **App**: allies
- **Prioridad**: ALTA
- **Estimado**: 30min
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En `todo_allies/backend/index.js` líneas 12-15, `mailgun({...})` se llama incondicionalmente aunque no haya credenciales. Replicar el guard del users backend: inicializar Mailgun solo si `MAILGUN_API_KEY` existe y no es el valor placeholder. Sin esto, el proceso crashea al arrancar en cualquier entorno sin `.env` configurado.

---

### TASK-013: Separar Socket.io a módulo propio en users backend
- **App**: users
- **Prioridad**: MEDIA
- **Estimado**: 2h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Extraer la inicialización de Socket.io de `index.js` a `socket.js` que exporte `{ io, server }`. Importarlos en `index.js`. Esto separa responsabilidades y permite reusar `io` para emitir eventos desde cualquier módulo sin crear dependencias circulares.

---

## DEUDA TÉCNICA REAL

### TASK-014: Crear sistema formal de migraciones de base de datos
- **App**: users
- **Prioridad**: ALTA
- **Estimado**: 4h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: El users `index.js` acumula +15 `ALTER TABLE ADD COLUMN` en el callback de apertura de DB (líneas 86-130, 1236-1254, 1302-1316), ignorando silenciosamente `'duplicate column'`. Crear `migrations.js` con array ordenado de migraciones + tabla `schema_migrations (version INTEGER PRIMARY KEY)`. Al arrancar, ejecutar solo las versiones mayores al máximo registrado.

---

### TASK-015: Reemplazar almacenamiento de imágenes base64 por archivos
- **App**: users
- **Prioridad**: MEDIA
- **Estimado**: 6h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: `avatar_image` en `users` y `new_avatar_image` en `photo_change_requests` pueden ser strings base64 de varios MB. Activar `multer` (ya instalado, comentado en línea ~6). Cambiar `PUT /users/profile/avatar` y `POST /api/user/photo-change-request` para aceptar `multipart/form-data`, guardar en `uploads/avatars/`, devolver URL. Actualizar Flutter para enviar `MultipartRequest` en lugar de base64.

---

### TASK-016: Eliminar código comentado de Firebase del users backend
- **App**: users
- **Prioridad**: BAJA
- **Estimado**: 30min
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Eliminar el bloque comentado de Firebase Admin (líneas 13-18 de `index.js`) y el `require('./firebase-admin.json')` comentado. Si se decide implementar FCM (ver TASK-023), hacerlo desde cero con las dependencias correctas. El código muerto aumenta la confusión al leer el archivo.

---

### TASK-017: Extraer lógica HTTP de widgets Flutter a capa de servicios
- **App**: users
- **Prioridad**: MEDIA
- **Estimado**: 6h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: La mayoría de screens en `todo_users/users/lib/screens/` hacen `http.get/post` directamente en `initState`. La excepción es `session_service.dart` que ya es un servicio correcto. Crear `lib/services/api_service.dart` con métodos tipados. Migrar al menos `profile_screen.dart`, `user_addresses_screen.dart` y `user_services_screen.dart` como punto de partida.

---

### TASK-018: Corregir datos incorrectos en tabla cities
- **App**: users
- **Prioridad**: MEDIA
- **Estimado**: 2h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En `todo_users/backend/index.js`, en el seed de cities, corregir: 'Cali' está bajo 'Antioquia' (debe estar en 'Valle del Cauca'), 'Barranquilla' está bajo 'Bolívar' (debe estar en 'Atlántico'), 'Luruaco' está bajo 'Bolívar' (debe estar en 'Atlántico'). Agregar un script de corrección de datos que actualice department_id para estas ciudades en la DB existente.

---

### TASK-019: Corregir status case inconsistency en assign endpoint
- **App**: users
- **Prioridad**: ALTA
- **Estimado**: 30min
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En `todo_users/backend/index.js` línea 1725, cambiar `status = 'En Proceso'` por `status = 'EN PROCESO'`. El allies backend ya usa `'EN PROCESO'` correctamente. Este bug hace que servicios asignados desde el users backend no coincidan con filtros que buscan `'EN PROCESO'` en mayúsculas.

---

### TASK-020: Usar transacciones SQLite en DELETE /users/:email
- **App**: users
- **Prioridad**: ALTA
- **Estimado**: 2h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En `DELETE /users/:email` (líneas 2092-2112), los 3 DELETE secuenciales en `user_addresses`, `user_phones` y `users` no están en una transacción. Si falla el segundo, el usuario queda con datos huérfanos. Envolver en `usersDb.run('BEGIN', () => { ... usersDb.run('COMMIT') ... })` con `ROLLBACK` en cada catch. Aplicar el mismo patrón a `PUT /api/admin/photo-change-requests/:id` que actualiza 2 tablas.

---

## FEATURES FALTANTES

### TASK-021: Implementar pestaña "Usuarios" en dashboard admin
- **App**: admin
- **Prioridad**: ALTA
- **Estimado**: 5h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En `dashboard_screen.dart` el tab "Usuarios" muestra un grid de solicitudes de foto (incorrecto). Crear `UsersListScreen` que llame a un nuevo endpoint `GET /api/admin/users` en users backend (que ya tiene `users.db` abierta). Mostrar lista con nombre, email, fecha de registro y botón de detalle.

---

### TASK-022: Implementar pestaña "Aliados" en dashboard admin
- **App**: admin
- **Prioridad**: ALTA
- **Estimado**: 5h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: El tab "Aliados" muestra "Funcionalidad en construcción". Crear `AlliesListScreen` y endpoint `GET /api/admin/allies` en el admin backend (necesita abrir `allies.db`). Mostrar lista con nombre, email, servicios asignados.

---

### TASK-023: Reemplazar cards placeholder en dashboard admin
- **App**: admin
- **Prioridad**: ALTA
- **Estimado**: 3h
- **Depende de**: TASK-021, TASK-022
- **Estado**: PENDIENTE
- **Qué hacer**: En `dashboard_screen.dart` líneas 209-233, las cards "Solicitud 2/3/4" apuntan a `PhotoChangeRequestsScreen` — error de placeholder. Reemplazar por: card de Gestión de Usuarios (→ TASK-021), card de Gestión de Aliados (→ TASK-022), card de Gestión de Servicios (endpoint a crear), conservar solo la card de Cambio de Foto como solicitud real.

---

### TASK-024: Crear tabla messages y endpoints de mensajería
- **App**: users, allies
- **Prioridad**: ALTA
- **Estimado**: 10h
- **Depende de**: TASK-009
- **Estado**: PENDIENTE
- **Qué hacer**: La tabla `messages` existe en el blueprint pero NO en el código de search.db. Crearla: `(id, sender_id, receiver_id, sender_role, receiver_role, service_in_search_id FK→services_in_search CASCADE, message, read=0, created_at)`. Crear endpoints `POST /messages`, `GET /messages/:serviceId`, `PUT /messages/:id/read`. Emitir evento Socket.io `newMessage`. Crear `MessageScreen` en Flutter para users y allies.

---

### TASK-025: Agregar pantallas de perfil a la app de Allies
- **App**: allies
- **Prioridad**: MEDIA
- **Estimado**: 5h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: La app allies solo tiene login, OTP, registro y dashboard. Crear `ally_profile_screen.dart` con nombre, email, servicios ofrecidos (usando `ally_services` table) y opción de logout. El allies backend ya tiene acceso a `allies.db` y `services.db`. Agregar tab de perfil al `DashboardScreen` de allies.

---

### TASK-026: Implementar notificaciones push con Firebase Cloud Messaging
- **App**: users, allies
- **Prioridad**: MEDIA
- **Estimado**: 8h
- **Depende de**: TASK-003
- **Estado**: PENDIENTE
- **Qué hacer**: Crear proyecto Firebase, generar `firebase-admin.json`. En users backend, implementar Firebase Admin SDK para enviar push notifications en 3 eventos: (1) aliado acepta un servicio, (2) admin aprueba/rechaza foto, (3) nuevo mensaje. En Flutter, configurar `firebase_messaging` y manejar notificaciones en foreground/background.

---

## MEJORAS DE BACKEND

### TASK-027: Agregar índices SQLite en columnas de búsqueda frecuente
- **App**: users, allies
- **Prioridad**: ALTA
- **Estimado**: 1h
- **Depende de**: TASK-014
- **Estado**: PENDIENTE
- **Qué hacer**: Agregar en el sistema de migraciones (TASK-014): `CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)`, `idx_sis_status ON services_in_search(status, assigned)`, `idx_sis_user ON services_in_search(user_id)`, `idx_sis_ally ON services_in_search(ally_id)`, `idx_search_email ON search_history(user_email)`, `idx_photo_status ON photo_change_requests(status)`, `idx_device_sessions ON device_sessions(user_email, is_active)`.

---

### TASK-028: Agregar validación de formato de email en endpoints clave
- **App**: users, allies
- **Prioridad**: ALTA
- **Estimado**: 1h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Los endpoints `/send-otp`, `/check-user`, `/register-user` y equivalentes en allies solo validan que `email` no esté vacío. Agregar regex de validación: `if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return res.status(400).json({ error: 'Email inválido' })`. Previene datos corruptos en BD y posibles inyecciones.

---

### TASK-029: Estandarizar formato de respuestas de API
- **App**: users, allies, admin
- **Prioridad**: MEDIA
- **Estimado**: 3h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Los backends mezclan 4 formatos distintos: `{ error }`, `{ message }`, `{ success, message }`, `{ success, data }`. Establecer convención: éxito → `{ success: true, data: ... }`, error → `{ success: false, error: { code: 'SNAKE_CASE', message: '...' } }`. Crear helper `sendSuccess(res, data)` y `sendError(res, status, code, message)`. Actualizar clientes Flutter.

---

### TASK-030: Validar campos en PUT /user-addresses/:id y PUT /users/profile/data
- **App**: users
- **Prioridad**: MEDIA
- **Estimado**: 1h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: `PUT /user-addresses/:id` (línea 1952) y `PUT /users/profile/data` (línea 2504) aceptan cualquier valor sin validar propiedad del recurso. Un usuario puede modificar la dirección de otro pasando cualquier `id`. Una vez implementado JWT (TASK-003), verificar que `user_email` del recurso coincide con `req.user.email`.

---

## TESTING

### TASK-031: Tests de integración para flujo OTP completo
- **App**: users
- **Prioridad**: ALTA
- **Estimado**: 4h
- **Depende de**: TASK-006
- **Estado**: PENDIENTE
- **Qué hacer**: Crear `todo_users/backend/tests/auth.test.js` con `jest` + `supertest`. Casos: (1) `/send-otp` con email válido devuelve 200, (2) `/verify-otp` con código correcto devuelve 200, (3) código expirado (+10min) devuelve 400, (4) código `'123456'` NO funciona (depende de TASK-001), (5) `/check-user` devuelve `exists: false` para email nuevo. Usar DB de test separada.

---

### TASK-032: Tests de integración para ciclo de vida de servicio
- **App**: users, allies
- **Prioridad**: ALTA
- **Estimado**: 4h
- **Depende de**: TASK-031
- **Estado**: PENDIENTE
- **Qué hacer**: Crear `tests/services.test.js`. Casos: (1) `POST /publish-service` crea servicio con status `'EN ESPERA'` y `assigned=0`, (2) allies `PUT /assign` pone `status='EN PROCESO'` y `assigned=1`, (3) users `PUT /assign` ahora pone `'EN PROCESO'` (depende de TASK-019), (4) `GET /services-in-search` no devuelve servicios con `assigned=1`, (5) `DELETE /services-in-search/:id` requiere user_email correcto.

---

### TASK-033: Tests de integración para admin CRUD
- **App**: admin
- **Prioridad**: MEDIA
- **Estimado**: 3h
- **Depende de**: TASK-002
- **Estado**: PENDIENTE
- **Qué hacer**: Crear `todo_admin/backend/tests/admin.test.js`. Casos: (1) login con credenciales correctas devuelve 200 sin password en respuesta, (2) login incorrecto devuelve 401, (3) `POST /api/admins` guarda password hasheado (verificar que plain text !== stored), (4) `DELETE /api/admins/:id` no devuelve 200 cuando se intenta borrar el último admin existente.

---

## DEVOPS

### TASK-034: Crear .gitignore en la raíz del proyecto
- **App**: all
- **Prioridad**: CRÍTICA
- **Estimado**: 20min
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: Crear `/Users/juanda/ToDo/.gitignore` con: `*/backend/.env`, `*/backend/node_modules/`, `databases/*.db`, `*/backend/uploads/`, `**/firebase-admin.json`, `**/.dart_tool/`, `**/build/`, `**/.flutter-plugins`, `**/.flutter-plugins-dependencies`. Sin este archivo, credenciales Mailgun y bases de datos con datos reales pueden ser commiteadas.

---

### TASK-035: Crear .env.example para cada backend
- **App**: all
- **Prioridad**: ALTA
- **Estimado**: 30min
- **Depende de**: TASK-034
- **Estado**: PENDIENTE
- **Qué hacer**: Crear `todo_users/backend/.env.example`, `todo_allies/backend/.env.example`, `todo_admin/backend/.env.example` documentando cada variable con valores de ejemplo seguros. Nota especial: allies backend requiere `MAILGUN_API_KEY` real para arrancar (a diferencia de users), documentar esta diferencia explícitamente.

---

### TASK-036: Crear configuración PM2 para producción
- **App**: all
- **Prioridad**: MEDIA
- **Estimado**: 2h
- **Depende de**: TASK-011, TASK-035
- **Estado**: PENDIENTE
- **Qué hacer**: Crear `ecosystem.config.js` en la raíz con los 3 backends: `{ name, script, cwd, env_production: { NODE_ENV, PORT, ... } }`. Configurar `watch: false`, logs separados en `logs/users.log`, `logs/allies.log`, `logs/admin.log`. Documentar `pm2 start ecosystem.config.js --env production`.

---

### TASK-037: Implementar --dart-define para la IP del backend en Flutter
- **App**: users, allies, admin
- **Prioridad**: MEDIA
- **Estimado**: 2h
- **Depende de**: ninguna
- **Estado**: PENDIENTE
- **Qué hacer**: En los 3 `config.dart`, reemplazar `static const String localIpAddress = '10.150.102.86'` por `static const String localIpAddress = String.fromEnvironment('API_HOST', defaultValue: '10.150.102.86')`. Documentar uso: `flutter run --dart-define=API_HOST=192.168.1.10`. Crear scripts `run-dev.sh` y `run-prod.sh` para cada app con los valores correctos.

---

## RESUMEN

| Sección | Tareas | Horas estimadas |
|---------|--------|-----------------|
| Seguridad Crítica | 8 | ~16h |
| Conflictos de Arquitectura | 5 | ~7h |
| Deuda Técnica Real | 7 | ~21h |
| Features Faltantes | 6 | ~36h |
| Mejoras de Backend | 4 | ~6h |
| Testing | 3 | ~11h |
| DevOps | 4 | ~5h |
| **Total** | **37** | **~102h** |

### Tareas completadas en código existente
- **TASK-027 (validación nombre/apellido 20 chars):** ✅ Ya implementada en `register-user` (línea 1582) y `register-ally` (línea 1610) de users backend, y en `register-ally` de allies backend (línea 227).

### Secuencia de inicio recomendada (ordenada por riesgo/bloqueo)
```
TASK-034 → TASK-001 → TASK-019 → TASK-012 → TASK-009
→ TASK-035 → TASK-006 → TASK-002 → TASK-003 → TASK-005
```
1. `TASK-034` — gitignore primero, antes de cualquier commit
2. `TASK-001` — backdoor eliminado en 30 min, riesgo máximo
3. `TASK-019` — bug de case que rompe estados, 30 min
4. `TASK-012` — allies no crashea sin credenciales
5. `TASK-009` — WAL mode en DBs compartidas
6. `TASK-035` — .env.example documentados
7. `TASK-006` — OTPs persistentes
8. `TASK-002` — passwords hasheados
9. `TASK-003` — JWT (depende de TASK-002)
10. `TASK-005` — rate limiting
