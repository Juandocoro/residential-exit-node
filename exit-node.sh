#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export PROJECT_ROOT
# shellcheck source=lib/system.sh
source "$PROJECT_ROOT/lib/system.sh"
source "$PROJECT_ROOT/lib/ui.sh"
source "$PROJECT_ROOT/lib/network.sh"
source "$PROJECT_ROOT/lib/backup.sh"
source "$PROJECT_ROOT/lib/wireguard.sh"
source "$PROJECT_ROOT/lib/firewall.sh"
source "$PROJECT_ROOT/lib/routing.sh"
source "$PROJECT_ROOT/lib/persistence.sh"
source "$PROJECT_ROOT/lib/diagnostics.sh"
source "$PROJECT_ROOT/lib/update.sh"

trap 'printf "\nSaliendo...\n"; exit 130' INT TERM

run_menu_action() {
  if ! ("$@"); then
    warn "La operación no se completó. El menú continúa disponible."
  fi
}

prepare_node() { require_root; ensure_layout; "$PROJECT_ROOT/install.sh" --dependencies-only; choose_exit_interface; create_connection; gateway_enable; }
register_droplet() { create_connection; }
remove_configuration() {
  require_root; load_state
  confirm "Esto eliminará únicamente la configuración administrada por este proyecto. ¿Continuar?" || return 0
  if [[ -n ${ACTIVE_PROFILE:-} && -f $(profile_path "$ACTIVE_PROFILE") ]]; then
    load_profile; gateway_disable || true; wg-quick down "$WG_INTERFACE" 2>/dev/null || true
    rm -f "$WG_DIR/$WG_INTERFACE.conf" "$WG_DIR/$WG_INTERFACE.key" "$WG_DIR/$WG_INTERFACE.pub"
  fi
  rm -rf "$CONFIG_DIR"
  log_event "managed configuration removed"
}

dispatch_menu() {
  local choice
  while true; do
    main_menu
    read -r -p "Digita una acción [0-21]: " choice || return 0
    case $choice in
      1) run_menu_action prepare_node;; 2) run_menu_action create_connection;; 3) run_menu_action import_droplet_config;; 4) run_menu_action show_public_key;;
      5) run_menu_action register_droplet;; 6) run_menu_action tunnel_up;; 7) run_menu_action tunnel_down;; 8) run_menu_action tunnel_status;;
      9) run_menu_action choose_exit_interface;; 10) run_menu_action gateway_enable;; 11) run_menu_action gateway_disable;; 12) run_menu_action public_ip;;
      13) run_menu_action gateway_test;; 14) run_menu_action full_diagnostics;; 15) run_menu_action enable_autostart;; 16) run_menu_action disable_autostart;;
      17) run_menu_action export_droplet;; 18) run_menu_action create_backup;; 19) run_menu_action restore_backup;; 20) run_menu_action remove_configuration;;
      21) if update_project && [[ $UPDATE_APPLIED == 1 ]]; then exec "$PROJECT_ROOT/exit-node.sh"; fi;;
      0) clear 2>/dev/null || true; info "Saliendo..."; return 0;;
      *) warn "Opción inválida.";;
    esac
    pause_ui
  done
}

case ${1:-} in
  --gateway-enable) gateway_enable;;
  --gateway-disable) gateway_disable;;
  --diagnostics) full_diagnostics;;
  --help) printf 'Uso: sudo %s [--gateway-enable|--gateway-disable|--diagnostics]\n' "$0";;
  '') require_root; ensure_layout; dispatch_menu;;
  *) die "Argumento no reconocido: $1";;
esac
