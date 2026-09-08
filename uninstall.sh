#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$PROJECT_ROOT/lib/system.sh"
source "$PROJECT_ROOT/lib/backup.sh"
source "$PROJECT_ROOT/lib/wireguard.sh"
source "$PROJECT_ROOT/lib/firewall.sh"
source "$PROJECT_ROOT/lib/routing.sh"
require_root
load_state
read -r -p "¿Desinstalar la configuración de Residential Exit Node Manager? [s/N]: " answer
[[ $answer =~ ^[sS]$ ]] || exit 0
create_backup || true
if [[ -n ${ACTIVE_PROFILE:-} && -f $(profile_path "$ACTIVE_PROFILE") ]]; then
  load_profile
  systemctl disable --now residential-exit-gateway.service "wg-quick@$WG_INTERFACE.service" 2>/dev/null || true
  gateway_disable || true
  rm -f "$WG_DIR/$WG_INTERFACE.conf" "$WG_DIR/$WG_INTERFACE.key" "$WG_DIR/$WG_INTERFACE.pub"
fi
rm -f "$SYSTEMD_DIR/residential-exit-gateway.service" "$SYSCTL_FILE"
rm -rf "$CONFIG_DIR"
systemctl daemon-reload 2>/dev/null || true
info "Configuración eliminada. Dependencias del sistema y backups conservados en $BACKUP_DIR."
