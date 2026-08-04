# Esquema de la base de datos — tudu

> Generado leyendo la base real el 2026-08-03. Es el inventario de columnas que
> existen hoy en Supabase, **no** un `CREATE TABLE` ejecutable: los tipos, las
> claves foráneas y las restricciones `UNIQUE` viven solo en el dashboard.
>
> Sirve para dos cosas: saber qué hay sin entrar al dashboard, y detectar
> desfases entre lo que el código escribe y lo que la tabla acepta — que es
> exactamente el error que rompía el registro de aliados (`updated_at` no
> existe en `allies`).

## Cómo mantenerlo

Regenerar el listado de columnas tras cualquier cambio de esquema:

```sh
cd tudu_users/backend && node -e "
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const s = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const tablas = ['users','user_phones','user_addresses','user_cards','search_history','device_sessions','photo_change_requests','allies','ally_service_profiles','ally_device_sessions','services','services_in_search','admins','departments','cities','countries'];
(async () => {
  for (const t of tablas) {
    const r = await s.from(t).select('*').limit(1);
    console.log(t + ': ' + Object.keys(r.data[0] || {}).join(', '));
  }
})();
"
```

Para el esquema completo con tipos y restricciones, en el SQL Editor:

```sql
select table_name, column_name, data_type, is_nullable, column_default
  from information_schema.columns
 where table_schema = 'public'
 order by table_name, ordinal_position;
```

---

## Usuarios

### `users`
`id`, `email`, `nombre`, `apellido`, `role`, `avatar_color`, `avatar_icon`,
`avatar_image`, `phone`, `genero`, `fecha_nacimiento`, `dark_mode`, `language`,
`created_at`

- `avatar_image` guarda base64 y puede pesar megas. `GET /users/profile/:email?lite=true` lo omite.
- `dark_mode` es entero 0/1, no booleano.

### `user_phones`
`id`, `user_email`, `country_code`, `country_name`, `phone_number`, `created_at`

- `user_email` es UNIQUE: el upsert usa `onConflict: 'user_email'`.

### `user_addresses`
`id`, `user_email`, `address_name`, `department_id`, `city_id`, `type_via`,
`number_principal`, `number_secondary`, `number_final`, `additional_info`,
`address_icon`, `created_at`

### `user_cards`
`id`, `user_email`, `card_number`, `card_holder`, `expiry_date`, `card_type`,
`document_type`, `document_number`, `card_mode`, `is_default`, `created_at`

- `card_number` se guarda **enmascarado**: `**** **** **** 1234`.

### `search_history`
`id`, `user_email`, `query`, `created_at`

- ⚠ La columna es `query`, pero la API la expone como `search_query`.

### `device_sessions`
`id`, `user_email`, `device_id`, `device_info`, `is_active`,
`requires_verification`, `last_activity`, `created_at`

- Restricción compuesta `(user_email, device_id)` — el upsert depende de ella.
- `requires_verification` no lo usa el código actual.

### `photo_change_requests`
`id`, `user_email`, `new_avatar_image`, `status`, `read_at`, `rejection_reason`,
`user_notified`, `created_at`, `updated_at`

- `status`: `pending` / `approved` / `rejected`.

---

## Aliados

### `allies`
`id`, `email`, `nombre`, `apellido`, `role`, `avatar_color`, `avatar_icon`,
`avatar_image`, `phone`, `genero`, `created_at`, `fecha_nacimiento`,
`kyc_status`, `kyc_cedula_frente`, `kyc_cedula_reverso`, `kyc_selfie`,
`kyc_submitted_at`, `kyc_reviewed_at`, `kyc_reviewer_note`

- **No tiene `updated_at`.** Escribirla hace fallar todo el upsert.
- `kyc_status`: `pending` → `submitted` → `approved` / `rejected`.
- Los tres campos `kyc_*` son base64 de documentos de identidad.

### `ally_service_profiles`
`ally_email`, `service_id`, `nombre_comercial`, `frase_presentacion`, `resumen`,
`created_at`

- Se relaciona por `ally_email`, **no** por `ally_id`.

### `ally_device_sessions`
`id`, `ally_email`, `device_id`, `device_info`, `is_active`, `last_activity`,
`created_at`

- `ally_email` tiene clave foránea contra `allies.email`: registrar una sesión
  de un aliado inexistente falla.

---

## Operación

### `services`
`id`, `name`, `description`, `icon`, `created_at`

### `services_in_search`
`id`, `user_email`, `title`, `description`, `time_quantity`, `time_unit`,
`budget`, `worker_info`, `status`, `assigned`, `ally_email`, `created_at`

- `status` en MAYÚSCULAS: `EN ESPERA`, `EN PROCESO`.
- `budget` es texto ya formateado con separador de miles.

### `admins`
`id`, `username`, `password`, `email`, `name`, `role`, `created_at`, `updated_at`

- `password` es un hash bcrypt (`$2a$…`).

---

## Catálogos

| Tabla | Columnas | Filas |
|---|---|---|
| `departments` | `id`, `name` | 33 |
| `cities` | `id`, `name`, `department_id` | 1103 |
| `countries` | `id`, `iso_code`, `name`, `dial_code`, `created_at` | 234 |

---

## Scripts SQL de este directorio

| Archivo | Qué hace | ¿Ya ejecutado? |
|---|---|---|
| `cron.sql` | Programa el mantenimiento horario con pg_cron | Sí |
| `fix_kyc_view.sql` | Corrige la vista expuesta con SECURITY DEFINER | Sí (la vista se borró) |
| `rls.sql` | Activa Row Level Security en todas las tablas | **Pendiente** |
| `borrar_cuenta.sql` | Borrado de cuenta en una sola transacción | **Pendiente** |
