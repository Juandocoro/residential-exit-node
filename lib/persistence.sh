#!/usr/bin/env bash

install_persistence_unit() {
  require_root; load_state; load_profile
  local source_root=${PROJECT_ROOT:?} unit="$SYSTEMD_DIR/residential-exit-gateway.service"
  [[ -e $unit ]] && backup_paths "$unit" >/dev/null
  sed -e "s|@PROJECT_ROOT@|$source_root|g" -e "s|@WG_INTERFACE@|$WG_INTERFACE|g" \
    "$source_root/systemd/residential-exit-gateway.service.in" >"$unit"
  chmod 644 "$unit"
  systemctl daemon-reload
}

enable_autostart() {
  install_persistence_unit
  systemctl enable "wg-quick@$WG_INTERFACE.service" residential-exit-gateway.service
  info "Inicio automático activado. Los servicios no bloquean el arranque si la Droplet no responde."
}

disable_autostart() {
  require_root; load_state; load_profile
  systemctl disable "wg-quick@$WG_INTERFACE.service" residential-exit-gateway.service 2>/dev/null || true
  info "Inicio automático desactivado."
}
