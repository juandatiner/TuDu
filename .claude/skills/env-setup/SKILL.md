---
name: env-setup
description: Variables de entorno (.env) de los 3 backends de tudu — qué es requerido/opcional y sus defaults. Usar cuando un backend no arranca, hay que configurar un .env nuevo, o se pregunta qué variables existen (los .env.example del repo están desactualizados, no confiar en ellos).
---

# Variables de entorno — tudu

Los `.env` están gitignored. Movido acá desde CLAUDE.md el 2026-08-05 (carga solo cuando hace falta, no en cada sesión).

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
