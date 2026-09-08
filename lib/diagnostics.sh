#!/usr/bin/env bash

check_line() { local label=$1; shift; if "$@" >/dev/null 2>&1; then printf '[OK] %s\n' "$label"; else printf '[FALLO] %s\n' "$label"; fi; }
wg_handshake_ok() {
  local latest now; latest=$(wg show "$WG_INTERFACE" latest-handshakes 2>/dev/null | awk 'NR==1{print $2}')
  [[ ${latest:-0} -gt 0 ]] || return 1; now=$(date +%s); ((now - latest < 180))
}
internet_ok() { ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || curl -4fsS --max-time 5 https://api.ipify.org >/dev/null; }

diagnostics_summary() {
  load_state; load_profile
  check_line "WireGuard instalado" command_exists wg
  check_line "interfaz $WG_INTERFACE" ip link show "$WG_INTERFACE"
  check_line "handshake reciente" wg_handshake_ok
  check_line "IP forwarding" test "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = 1
  check_line "salida seleccionada ($EXIT_INTERFACE)" ip link show "$EXIT_INTERFACE"
  check_line "NAT y forwarding" firewall_has_rules "${FIREWALL_BACKEND:-$(detect_firewall)}"
  check_line "conexión Droplet" ping -c 1 -W 2 "$DROPLET_WG_IP"
  check_line "Internet" internet_ok
  printf '[INFO] IP pública: '; public_ip || printf 'no disponible\n'
}

full_diagnostics() {
  diagnostics_summary
  printf '\n--- wg show ---\n'; wg show 2>&1 || true
  printf '\n--- ip addr ---\n'; ip -brief addr 2>&1 || true
  printf '\n--- ip route ---\n'; ip route 2>&1 || true
  printf '\n--- sysctl ---\n'; sysctl net.ipv4.ip_forward 2>&1 || true
  printf '\n--- firewall (%s) ---\n' "${FIREWALL_BACKEND:-desconocido}"
  case ${FIREWALL_BACKEND:-} in
    nftables) nft list table ip residential_exit_node 2>&1 || true ;;
    firewalld) firewall-cmd --permanent --direct --get-all-rules 2>&1 | grep "$RULE_TAG" || true ;;
    ufw|iptables) iptables-save 2>/dev/null | grep "$RULE_TAG" || true ;;
  esac
  printf '\n--- RX/TX y handshake ---\n'
  wg show "$WG_INTERFACE" transfer 2>&1 || true
  wg show "$WG_INTERFACE" latest-handshakes 2>&1 || true
}
