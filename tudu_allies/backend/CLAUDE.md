# tudu_allies/backend — API endpoints (puerto 3002)

> Detalle de rutas de `index.js`. Contexto general (roles, auth, tablas) en `@CLAUDE.md` de la raíz.

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
| GET | `/api/admin/services` | Servicios propuestos + categoría, aliado y pruebas. `?estado=pending` por defecto |
| PUT | `/api/admin/services/:id` | Aprobar/rechazar/corregir. **Responde 409 `CATEGORIA_PENDIENTE`** si se aprueba con la categoría sin aprobar — quedaría invisible en `GET /categories` de users |
| PUT | `/api/admin/categories/:id` | Aprobar/rechazar una categoría propuesta. Decisión independiente de la del servicio |
| POST | `/api/admin/categories` | El admin la crea ya aprobada |
| DELETE | `/api/admin/portfolio-items/:id` | Borra una prueba puntual (fila + archivo del bucket `portfolio`) sin rechazar el servicio entero |
| POST | `/ally-service-profile` | |
| GET | `/services` | |
| POST | `/services` | Crea servicio nuevo (mín. 2 chars) |
| GET | `/services-in-search` | Solo `assigned = 0` |
| PUT | `/services-in-search/:id/assign` | Requiere `ally_email`; pone `status: 'EN PROCESO'` (igual que users ahora — ver §8 de la raíz) |
| PUT | `/services-in-search/:id/status` | |
| GET | `/my-services?ally_email=` | |
| — | `/ally-device-session/*` | check · register · status · logout · list · close-others |

El caso especial que forzaba `requires_verification: true` para `cosmodavid2009@gmail.com` **ya no existe** — verificado, no aparece ninguna referencia a ese correo en el código.
