#!/usr/bin/env bash

list_exit_interfaces() {
  local dev ip gateway n=0
  while read -r dev; do
    [[ $dev == lo || $dev == wg* ]] && continue
    ip=$(ip -4 -o addr show dev "$dev" scope global 2>/dev/null | awk 'NR==1{print $4}')
    gateway=$(ip -4 route show default dev "$dev" 2>/dev/null | awk 'NR==1{print $3}')
    [[ -n $ip ]] || continue
    ((++n)); printf '%s) %s\n   Gateway: %s\n   IP: %s\n' "$n" "$dev" "${gateway:-N/D}" "$ip"
    EXIT_CANDIDATES[n]=$dev
  done < <(ip -o link show | awk -F': ' '{print $2}' | cut -d@ -f1)
  ((n > 0))
}

choose_exit_interface() {
  local choice
  EXIT_CANDIDATES=()
  printf 'Interfaces disponibles:\n\n'
  list_exit_interfaces || die "No se encontraron interfaces IPv4 de salida."
  read -r -p "Seleccione interfaz: " choice
  [[ $choice =~ ^[0-9]+$ && -n ${EXIT_CANDIDATES[choice]:-} ]] || die "Selección inválida."
  load_state; EXIT_INTERFACE=${EXIT_CANDIDATES[choice]}; save_state
  log_event "exit interface set to $EXIT_INTERFACE"
  info "Interfaz de salida: $EXIT_INTERFACE"
}

public_ip() {
  local value=""
  if command_exists curl; then value=$(curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)
  elif command_exists wget; then value=$(wget -4qO- --timeout=8 https://api.ipify.org 2>/dev/null || true); fi
  [[ -n $value ]] && printf '%s\n' "$value" || { warn "No se pudo consultar la IP pública."; return 1; }
}
