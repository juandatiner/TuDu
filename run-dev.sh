#!/usr/bin/env bash
# =============================================================================
#  TuDu — Script de arranque de desarrollo
#  Detecta la IP local automáticamente y lanza la(s) app(s) indicadas.
#
#  USO:
#    ./run-dev.sh              → muestra ayuda
#    ./run-dev.sh users        → inicia backend + Flutter de tudu_users
#    ./run-dev.sh allies       → inicia backend + Flutter de tudu_allies
#    ./run-dev.sh all          → inicia ambos backends + ambas apps
#    ./run-dev.sh backend      → solo los dos backends (sin Flutter)
# =============================================================================

set -euo pipefail

# ─── Colores ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Rutas ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERS_BACKEND="$SCRIPT_DIR/tudu_users/backend"
USERS_FLUTTER="$SCRIPT_DIR/tudu_users/users"
ALLIES_BACKEND="$SCRIPT_DIR/tudu_allies/backend"
ALLIES_FLUTTER="$SCRIPT_DIR/tudu_allies/allies"
ADMIN_BACKEND="$SCRIPT_DIR/tudu_admin/backend"
ADMIN_FLUTTER="$SCRIPT_DIR/tudu_admin/admin"

# ─── Detectar IP local automáticamente ───────────────────────────────────────
detect_local_ip() {
  local ip=""

  # 1. Intentar con en0 (Wi-Fi en Mac)
  ip=$(ipconfig getifaddr en0 2>/dev/null || true)

  # 2. Si falla, intentar con en1 (segunda interfaz)
  if [[ -z "$ip" ]]; then
    ip=$(ipconfig getifaddr en1 2>/dev/null || true)
  fi

  # 3. Fallback: primera IP no-loopback con ifconfig
  if [[ -z "$ip" ]]; then
    ip=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
  fi

  # 4. Si sigue vacío, error claro
  if [[ -z "$ip" ]]; then
    echo -e "${RED}✗ No se pudo detectar la IP local.${NC}"
    echo -e "  Asegúrate de estar conectado a Wi-Fi o red LAN."
    exit 1
  fi

  echo "$ip"
}

# ─── Iniciar backend ──────────────────────────────────────────────────────────
start_backend() {
  local name="$1"
  local dir="$2"
  local port="$3"
  local entrypoint="${4:-index.js}" # por defecto index.js, admin usa server.js

  echo -e "${CYAN}▶ Iniciando backend ${BOLD}$name${NC}${CYAN} en puerto $port...${NC}"
  (cd "$dir" && node "$entrypoint" &)
  sleep 1
  echo -e "${GREEN}✓ Backend $name corriendo en http://localhost:$port${NC}"
}

# ─── Iniciar Flutter ─────────────────────────────────────────────────────────
start_flutter() {
  local name="$1"
  local dir="$2"
  local ip="$3"

  echo ""
  echo -e "${CYAN}▶ Lanzando Flutter ${BOLD}$name${NC}${CYAN} con LOCAL_IP=$ip ...${NC}"
  echo -e "  (Se abrirá el selector de dispositivo de Flutter)"
  echo ""
  (cd "$dir" && flutter run --dart-define=LOCAL_IP="$ip")
}

# ─── Ayuda ────────────────────────────────────────────────────────────────────
show_help() {
  echo ""
  echo -e "${BOLD}TuDu — Script de arranque${NC}"
  echo ""
  echo "  Detecta tu IP local automáticamente y lanza las apps."
  echo "  Ya no necesitas cambiar la IP a mano. 🎉"
  echo ""
  echo -e "${BOLD}Uso:${NC}"
  echo "  ./run-dev.sh <comando>"
  echo ""
  echo -e "${BOLD}Comandos:${NC}"
  echo "  users     Inicia backend de users (puerto 3000) + app Flutter users"
  echo "  allies    Inicia backend de allies (puerto 3002) + app Flutter allies"
  echo "  admin     Inicia backend de admin (puerto 3003) + app Flutter admin"
  echo "  all       Inicia los 3 backends + muestra comandos Flutter"
  echo "  backend   Solo inicia los 3 backends (sin Flutter)"
  echo "  ip        Solo muestra tu IP local actual"
  echo ""
  echo -e "${BOLD}Ejemplos:${NC}"
  echo "  ./run-dev.sh users"
  echo "  ./run-dev.sh allies"
  echo "  ./run-dev.sh admin"
  echo "  ./run-dev.sh all"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
CMD="${1:-help}"

# Mostrar IP actual siempre (excepto en help)
if [[ "$CMD" != "help" && "$CMD" != "--help" && "$CMD" != "-h" ]]; then
  LOCAL_IP=$(detect_local_ip)
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════${NC}"
  echo -e "  TuDu Dev  |  IP local: ${GREEN}${BOLD}$LOCAL_IP${NC}"
  echo -e "${BOLD}═══════════════════════════════════════${NC}"
  echo ""
fi

case "$CMD" in

  users)
    start_backend "tudu_users" "$USERS_BACKEND" "3000"
    start_flutter "tudu_users" "$USERS_FLUTTER" "$LOCAL_IP"
    ;;

  allies)
    start_backend "tudu_allies" "$ALLIES_BACKEND" "3002"
    start_flutter "tudu_allies" "$ALLIES_FLUTTER" "$LOCAL_IP"
    ;;

  admin)
    start_backend "tudu_admin" "$ADMIN_BACKEND" "3003" "server.js"
    start_flutter "tudu_admin" "$ADMIN_FLUTTER" "$LOCAL_IP"
    ;;

  all)
    start_backend "tudu_users"  "$USERS_BACKEND"  "3000"
    start_backend "tudu_allies" "$ALLIES_BACKEND" "3002"
    start_backend "tudu_admin"  "$ADMIN_BACKEND"  "3003" "server.js"
    echo ""
    echo -e "${YELLOW}⚠  Backends activos. Abre terminales separadas para cada app Flutter:${NC}"
    echo -e "   Terminal 1: ${CYAN}./run-dev.sh users${NC}"
    echo -e "   Terminal 2: ${CYAN}./run-dev.sh allies${NC}"
    echo -e "   Terminal 3: ${CYAN}./run-dev.sh admin${NC}"
    echo ""
    echo -e "O usa los comandos directamente:"
    echo -e "  ${CYAN}cd $USERS_FLUTTER  && flutter run --dart-define=LOCAL_IP=$LOCAL_IP${NC}"
    echo -e "  ${CYAN}cd $ALLIES_FLUTTER && flutter run --dart-define=LOCAL_IP=$LOCAL_IP${NC}"
    echo -e "  ${CYAN}cd $ADMIN_FLUTTER  && flutter run --dart-define=LOCAL_IP=$LOCAL_IP${NC}"
    ;;

  backend)
    start_backend "tudu_users"  "$USERS_BACKEND"  "3000"
    start_backend "tudu_allies" "$ALLIES_BACKEND" "3002"
    start_backend "tudu_admin"  "$ADMIN_BACKEND"  "3003" "server.js"
    echo ""
    echo -e "${GREEN}✓ Los 3 backends corriendo. Presiona Ctrl+C para detenerlos.${NC}"
    wait
    ;;

  ip)
    LOCAL_IP=$(detect_local_ip)
    echo -e "Tu IP local actual: ${GREEN}${BOLD}$LOCAL_IP${NC}"
    echo ""
    echo "Comandos Flutter equivalentes:"
    echo -e "  ${CYAN}flutter run --dart-define=LOCAL_IP=$LOCAL_IP${NC}"
    ;;

  help|--help|-h|"")
    show_help
    ;;

  *)
    echo -e "${RED}Comando desconocido: '$CMD'${NC}"
    show_help
    exit 1
    ;;

esac
