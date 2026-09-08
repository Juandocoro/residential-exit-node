#!/usr/bin/env bash

backup_paths() {
  local stamp dest path
  stamp=$(date +%Y%m%d-%H%M%S); dest="$BACKUP_DIR/$stamp"
  install -d -m 700 "$dest"
  for path in "$@"; do
    [[ -e $path ]] || continue
    cp -a --parents "$path" "$dest"
  done
  printf '%s\n' "$dest"
}

backup_firewall_snapshot() {
  local stamp dest
  stamp=$(date +%Y%m%d-%H%M%S); dest="$BACKUP_DIR/$stamp/firewall"
  install -d -m 700 "$dest"
  command_exists nft && nft list ruleset >"$dest/nft-ruleset.txt" 2>/dev/null || true
  command_exists iptables-save && iptables-save >"$dest/iptables.rules" 2>/dev/null || true
  command_exists firewall-cmd && firewall-cmd --list-all-zones >"$dest/firewalld-zones.txt" 2>/dev/null || true
  command_exists ufw && ufw status numbered >"$dest/ufw-status.txt" 2>/dev/null || true
  printf '%s\n' "$dest"
}

create_backup() {
  ensure_layout
  local items=("$CONFIG_DIR" "$SYSCTL_FILE" "$SYSTEMD_DIR/residential-exit-gateway.service") path
  load_state
  if [[ -n ${ACTIVE_PROFILE:-} ]]; then
    load_profile
    items+=("$WG_DIR/$WG_INTERFACE.conf" "$WG_DIR/$WG_INTERFACE.key" "$WG_DIR/$WG_INTERFACE.pub")
  fi
  path=$(backup_paths "${items[@]}")
  log_event "backup created at $path"
  info "Backup creado: $path"
}

restore_backup() {
  local source=${1:-}
  [[ -n $source ]] || read -r -p "Directorio de backup: " source
  [[ -d $source && $source == "$BACKUP_DIR"/* ]] || die "Backup inválido o fuera de $BACKUP_DIR."
  confirm "Se restaurarán los archivos de $source. ¿Continuar?" || return 0
  cp -a "$source"/. /
  command_exists systemctl && systemctl daemon-reload || true
  log_event "backup restored from $source"
}
