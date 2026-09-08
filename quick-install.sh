#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY_URL="${REPOSITORY_URL:-https://github.com/Juandocoro/residential-exit-node.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/residential-exit-node}"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Ejecute este instalador como root mediante sudo."

install_git() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y git ca-certificates
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --needed --noconfirm git ca-certificates
  else
    die "No se encontró apt ni pacman. Instale git y vuelva a ejecutar el comando."
  fi
}

command -v git >/dev/null 2>&1 || install_git

if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Actualizando instalación existente en $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull --ff-only
elif [[ -e "$INSTALL_DIR" ]]; then
  die "$INSTALL_DIR ya existe y no es un repositorio Git. No se modificó."
else
  info "Descargando Residential Exit Node Manager..."
  git clone --depth 1 "$REPOSITORY_URL" "$INSTALL_DIR"
fi

chmod 755 "$INSTALL_DIR/exit-node.sh" "$INSTALL_DIR/install.sh" \
  "$INSTALL_DIR/uninstall.sh" "$INSTALL_DIR/quick-install.sh" "$INSTALL_DIR/lib/"*.sh

"$INSTALL_DIR/install.sh"

info ""
info "Instalación completada. Abra el administrador con:"
info "  sudo $INSTALL_DIR/exit-node.sh"
