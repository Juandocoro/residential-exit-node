#!/usr/bin/env bash

enable_forwarding() {
  [[ -e $SYSCTL_FILE ]] && backup_paths "$SYSCTL_FILE"
  install -d -m 755 "$(dirname "$SYSCTL_FILE")"
  printf '# Managed by Residential Exit Node Manager\nnet.ipv4.ip_forward=1\n' >"$SYSCTL_FILE"
  chmod 644 "$SYSCTL_FILE"
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
}

disable_forwarding() {
  [[ -f $SYSCTL_FILE ]] && rm -f "$SYSCTL_FILE"
  # Do not force runtime forwarding off: another service may require it.
  warn "Se retiró la configuración persistente. No se desactivó ip_forward en runtime para no afectar otros servicios."
}

gateway_enable() {
  require_root; ensure_layout; load_state; load_profile
  [[ -n ${EXIT_INTERFACE:-} ]] || die "Seleccione primero la interfaz de salida."
  ip link show "$EXIT_INTERFACE" >/dev/null 2>&1 || die "La interfaz $EXIT_INTERFACE no existe."
  local network backend
  network=$(network_from_cidr "$LOCAL_WG_CIDR")
  backend=${FIREWALL_BACKEND:-$(detect_firewall)} || die "No hay backend de firewall disponible."
  backup_paths "$SYSCTL_FILE" "$SYSTEMD_DIR/residential-exit-gateway.service" >/dev/null
  backup_firewall_snapshot >/dev/null
  enable_forwarding
  apply_firewall "$backend" "$WG_INTERFACE" "$EXIT_INTERFACE" "$network"
  FIREWALL_BACKEND=$backend; save_state
  log_event "gateway enabled backend=$backend wg=$WG_INTERFACE exit=$EXIT_INTERFACE network=$network"
  info "Gateway activo mediante $backend."
}

gateway_disable() {
  require_root; load_state; load_profile
  local network; network=$(network_from_cidr "$LOCAL_WG_CIDR")
  remove_firewall "${FIREWALL_BACKEND:-$(detect_firewall)}" "$WG_INTERFACE" "$EXIT_INTERFACE" "$network"
  disable_forwarding
  log_event "gateway disabled"
  info "Reglas exclusivas del proyecto retiradas."
}

gateway_test() {
  load_state; load_profile
  local network failures=0
  network=$(network_from_cidr "$LOCAL_WG_CIDR")
  [[ $(sysctl -n net.ipv4.ip_forward 2>/dev/null) == 1 ]] || { warn "ip_forward no está activo"; ((failures++)); }
  firewall_has_rules "${FIREWALL_BACKEND:-$(detect_firewall)}" || { warn "No se detectan reglas del proyecto"; ((failures++)); }
  ip route get 1.1.1.1 oif "$EXIT_INTERFACE" >/dev/null 2>&1 || { warn "Sin ruta de salida por $EXIT_INTERFACE"; ((failures++)); }
  info "Prueba no destructiva: red $network -> $EXIT_INTERFACE; fallos=$failures"
  ((failures == 0))
}
