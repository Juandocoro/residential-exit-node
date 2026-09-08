#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$PROJECT_ROOT/lib/system.sh"
require_root
detect_distro

install_dependencies() {
  case "$DISTRO_ID $DISTRO_LIKE" in
    *arch*) pacman -Sy --needed --noconfirm wireguard-tools iproute2 nftables curl python ;;
    *debian*|*ubuntu*) apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard-tools iproute2 nftables curl python3 ;;
    *) die "Distribución no soportada automáticamente: $DISTRO_ID ($DISTRO_LIKE). Instale wireguard-tools, iproute2, nftables, curl y python3." ;;
  esac
}

install_dependencies
if ! modprobe wireguard 2>"${TMPDIR:-/tmp}/residential-exit-modprobe.err"; then
  warn "No se pudo cargar el módulo WireGuard: $(<"${TMPDIR:-/tmp}/residential-exit-modprobe.err")"
  warn "Puede que el kernel no incluya WireGuard o que ya se use una implementación userspace."
fi
command_exists wg || die "wg no quedó disponible después de instalar dependencias."
ensure_layout
chmod 755 "$PROJECT_ROOT/exit-node.sh" "$PROJECT_ROOT/install.sh" "$PROJECT_ROOT/uninstall.sh" "$PROJECT_ROOT/lib/"*.sh
info "Instalación lista. Ejecute: sudo $PROJECT_ROOT/exit-node.sh"
info "No se reinició el equipo."
