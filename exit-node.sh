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
    main_menu; read -r -p "Opción: " choice
    case $choice in
      1) prepare_node;; 2) create_connection;; 3) import_droplet_config;; 4) show_public_key;;
      5) register_droplet;; 6) tunnel_up;; 7) tunnel_down;; 8) tunnel_status;;
      9) choose_exit_interface;; 10) gateway_enable;; 11) gateway_disable;; 12) public_ip;;
      13) gateway_test;; 14) full_diagnostics;; 15) enable_autostart;; 16) disable_autostart;;
      17) export_droplet;; 18) create_backup;; 19) restore_backup;; 20) remove_configuration;;
      0) return 0;; *) warn "Opción inválida.";;
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
