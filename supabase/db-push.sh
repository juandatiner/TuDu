#!/usr/bin/env bash
# Aplica las migrations pendientes al proyecto remoto sin pedir nada por consola.
#
# El CLI de Supabase pide dos secretos y, si no los encuentra, abre un prompt
# interactivo — inservible desde un agente o desde CI. Los dos se pueden pasar
# por variable de entorno, así que se leen de `supabase/.env.local`, que ya está
# en el .gitignore del propio Supabase (`.env.local`).
#
# Uso:
#   ./supabase/db-push.sh            # aplica lo pendiente
#   ./supabase/db-push.sh --dry-run  # solo muestra qué aplicaría
#
# Para llenar las credenciales la primera vez, ver `.env.local.example`.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVO_ENV="$AQUI/.env.local"

if [[ ! -f "$ARCHIVO_ENV" ]]; then
  echo "✗ Falta $ARCHIVO_ENV — copiá .env.local.example y llenalo." >&2
  exit 1
fi

# `set -a` exporta todo lo que se defina mientras esté activo.
set -a
# shellcheck disable=SC1090
source "$ARCHIVO_ENV"
set +a

: "${SUPABASE_ACCESS_TOKEN:?falta SUPABASE_ACCESS_TOKEN en .env.local}"
: "${SUPABASE_DB_PASSWORD:?falta SUPABASE_DB_PASSWORD en .env.local}"

cd "$AQUI/.."

# `db push` necesita el proyecto linkeado; si el link se perdió, se rehace solo.
if [[ ! -f "$AQUI/.temp/project-ref" ]]; then
  echo "→ Proyecto no linkeado, linkeando ${SUPABASE_PROJECT_REF:-}..."
  supabase link --project-ref "${SUPABASE_PROJECT_REF:?falta SUPABASE_PROJECT_REF}"
fi

exec supabase db push "$@"
