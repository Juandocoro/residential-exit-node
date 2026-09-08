#!/usr/bin/env bash

profile_path() { printf '%s/%s.conf' "$PROFILES_DIR" "$1"; }
load_profile() {
  local id=${1:-${ACTIVE_PROFILE:-}}
  [[ -n $id && -r $(profile_path "$id") ]] || die "Perfil no encontrado."
  # shellcheck disable=SC1090
  source "$(profile_path "$id")"
}

save_profile() {
  local path tmp; path=$(profile_path "$PROFILE_ID"); tmp=$(mktemp "$PROFILES_DIR/.profile.XXXXXX")
  {
    printf 'NODE_NAME=%q\nPROFILE_ID=%q\nWG_INTERFACE=%q\nLOCAL_WG_CIDR=%q\n' "$NODE_NAME" "$PROFILE_ID" "$WG_INTERFACE" "$LOCAL_WG_CIDR"
    printf 'DROPLET_WG_IP=%q\nDROPLET_PUBLIC_IP=%q\nDROPLET_PORT=%q\nDROPLET_PUBLIC_KEY=%q\n' "$DROPLET_WG_IP" "$DROPLET_PUBLIC_IP" "$DROPLET_PORT" "$DROPLET_PUBLIC_KEY"
  } >"$tmp"
  chmod 600 "$tmp"; mv -f "$tmp" "$path"
}

collect_profile() {
  ask "Nombre del nodo" "Casa Cali"; NODE_NAME=$REPLY
  PROFILE_ID=$(safe_id "$NODE_NAME"); [[ -n $PROFILE_ID ]] || die "Nombre inválido."
  ask "Nombre interfaz WireGuard" "wg-exit"; WG_INTERFACE=$REPLY; valid_interface "$WG_INTERFACE" || die "Interfaz inválida."
  ask "IP local WireGuard" "10.77.77.2/24"; LOCAL_WG_CIDR=$REPLY; valid_ipv4 "$LOCAL_WG_CIDR" || die "IP inválida."
  ask "IP WireGuard Droplet" "10.77.77.1"; DROPLET_WG_IP=${REPLY%/*}; valid_ipv4 "$DROPLET_WG_IP" || die "IP inválida."
  ask "IP pública o hostname Droplet"; DROPLET_PUBLIC_IP=$REPLY; [[ -n $DROPLET_PUBLIC_IP ]] || die "Endpoint requerido."
  ask "Puerto" "51820"; DROPLET_PORT=$REPLY; valid_port "$DROPLET_PORT" || die "Puerto inválido."
  ask "Clave pública Droplet"; DROPLET_PUBLIC_KEY=$REPLY; [[ $DROPLET_PUBLIC_KEY =~ ^[A-Za-z0-9+/]{42,43}=$ ]] || die "Clave pública inválida."
}

generate_keys() {
  local iface=$1 key="$WG_DIR/$iface.key" pub="$WG_DIR/$iface.pub" old_umask
  command_exists wg || die "WireGuard no está instalado."
  old_umask=$(umask); umask 077
  [[ -s $key ]] || wg genkey >"$key"
  wg pubkey <"$key" >"$pub"
  chmod 600 "$key" "$pub"; umask "$old_umask"
}

network_from_cidr() {
  command_exists python3 || die "python3 es necesario para calcular la red."
  python3 -c 'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' "$1"
}

write_wg_config() {
  load_profile "$1"; generate_keys "$WG_INTERFACE"
  local target="$WG_DIR/$WG_INTERFACE.conf" tmp
  [[ -e $target ]] && backup_paths "$target"
  tmp=$(mktemp "$WG_DIR/.wg.XXXXXX")
  {
    printf '[Interface]\nAddress = %s\nPrivateKey = ' "$LOCAL_WG_CIDR"
    cat "$WG_DIR/$WG_INTERFACE.key"
    printf '\n[Peer]\nPublicKey = %s\nEndpoint = %s:%s\nAllowedIPs = %s/32\nPersistentKeepalive = 25\n' \
      "$DROPLET_PUBLIC_KEY" "$DROPLET_PUBLIC_IP" "$DROPLET_PORT" "$DROPLET_WG_IP"
  } >"$tmp"
  chmod 600 "$tmp"; mv -f "$tmp" "$target"
  load_state; ACTIVE_PROFILE=$PROFILE_ID; save_state
  log_event "WireGuard config generated for profile $PROFILE_ID interface $WG_INTERFACE"
}

create_connection() { collect_profile; save_profile; write_wg_config "$PROFILE_ID"; info "Perfil $PROFILE_ID creado."; }

show_public_key() { load_state; load_profile; local f="$WG_DIR/$WG_INTERFACE.pub"; [[ -s $f ]] || generate_keys "$WG_INTERFACE"; cat "$f"; }
tunnel_up() { load_state; load_profile; wg-quick up "$WG_INTERFACE"; }
tunnel_down() { load_state; load_profile; wg-quick down "$WG_INTERFACE"; }
tunnel_status() { load_state; load_profile; wg show "$WG_INTERFACE"; }

import_droplet_config() {
  local source
  read -r -p "Ruta del archivo de perfil exportado: " source
  [[ -r $source ]] || die "No se puede leer el archivo."
  # Accept only known assignments; never eval arbitrary input.
  NODE_NAME=$(sed -n 's/^NODE_NAME="\([^"]*\)"$/\1/p' "$source" | head -1)
  WG_INTERFACE=$(sed -n 's/^WG_INTERFACE="\([^"]*\)"$/\1/p' "$source" | head -1)
  LOCAL_WG_CIDR=$(sed -n 's/^LOCAL_WG_CIDR="\([^"]*\)"$/\1/p' "$source" | head -1)
  DROPLET_WG_IP=$(sed -n 's/^DROPLET_WG_IP="\([^"]*\)"$/\1/p' "$source" | head -1)
  DROPLET_PUBLIC_IP=$(sed -n 's/^DROPLET_PUBLIC_IP="\([^"]*\)"$/\1/p' "$source" | head -1)
  DROPLET_PORT=$(sed -n 's/^DROPLET_PORT="\([^"]*\)"$/\1/p' "$source" | head -1)
  DROPLET_PUBLIC_KEY=$(sed -n 's/^DROPLET_PUBLIC_KEY="\([^"]*\)"$/\1/p' "$source" | head -1)
  PROFILE_ID=$(safe_id "$NODE_NAME")
  [[ -n $PROFILE_ID ]] && valid_interface "$WG_INTERFACE" && valid_ipv4 "$LOCAL_WG_CIDR" && valid_ipv4 "$DROPLET_WG_IP" && valid_port "$DROPLET_PORT" || die "Archivo inválido."
  save_profile; write_wg_config "$PROFILE_ID"
}

export_droplet() {
  load_state; load_profile; local pub network
  pub=$(show_public_key); network=$(network_from_cidr "$LOCAL_WG_CIDR")
  printf 'NODE_NAME="%s"\nNODE_ID="%s"\nNODE_PUBLIC_KEY="%s"\nNODE_WG_IP="%s"\nNODE_ENDPOINT_MODE="client"\nNODE_NETWORK="%s"\n\n' \
    "$NODE_NAME" "$PROFILE_ID" "$pub" "${LOCAL_WG_CIDR%/*}" "$network"
  printf '[Peer]\nPublicKey = %s\nAllowedIPs = 0.0.0.0/0\n\n' "$pub"
  printf 'NOTA: use 0.0.0.0/0 solamente del lado Droplet con policy routing y Table = off; no lo instale como ruta por defecto principal.\n'
}
