#!/usr/bin/env bash

PROJECT_NAME="residential-exit-node"
CONFIG_DIR="${REN_CONFIG_DIR:-/etc/residential-exit-node}"
PROFILES_DIR="$CONFIG_DIR/profiles"
STATE_FILE="$CONFIG_DIR/state.conf"
WG_DIR="${REN_WG_DIR:-/etc/wireguard}"
BACKUP_DIR="${REN_BACKUP_DIR:-/var/backups/residential-exit-node}"
LOG_FILE="${REN_LOG_FILE:-/var/log/residential-exit-node.log}"
SYSCTL_FILE="${REN_SYSCTL_FILE:-/etc/sysctl.d/99-residential-exit.conf}"
SYSTEMD_DIR="${REN_SYSTEMD_DIR:-/etc/systemd/system}"
RULE_TAG="RESIDENTIAL_EXIT_NODE"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'ADVERTENCIA: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Ejecute como root (sudo)."; }

ensure_layout() {
  install -d -m 700 "$CONFIG_DIR" "$PROFILES_DIR" "$WG_DIR"
  install -d -m 700 "$BACKUP_DIR"
  install -d -m 755 "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
}

log_event() {
  local message="$*"
  # Callers must never pass secret material here.
  printf '%s %s\n' "$(date -Is)" "$message" >>"$LOG_FILE" 2>/dev/null || true
}

safe_id() {
  printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//'
}

valid_interface() { [[ $1 =~ ^[a-zA-Z0-9_.-]{1,15}$ ]]; }
valid_port() { [[ $1 =~ ^[0-9]+$ ]] && ((1 <= 10#$1 && 10#$1 <= 65535)); }
valid_ipv4() {
  local ip=${1%/*} IFS=. octets
  read -r -a octets <<<"$ip"
  [[ ${#octets[@]} -eq 4 ]] || return 1
  local o; for o in "${octets[@]}"; do [[ $o =~ ^[0-9]+$ ]] && ((10#$o <= 255)) || return 1; done
  if [[ $1 == */* ]]; then local p=${1#*/}; [[ $p =~ ^[0-9]+$ ]] && ((10#$p <= 32)) || return 1; fi
}

load_state() {
  ACTIVE_PROFILE="" EXIT_INTERFACE="" FIREWALL_BACKEND=""
  [[ -f $STATE_FILE ]] || return 0
  # State is written by this program with shell-safe %q values.
  # shellcheck disable=SC1090
  source "$STATE_FILE"
}

save_state() {
  local tmp; tmp=$(mktemp "$CONFIG_DIR/.state.XXXXXX")
  {
    printf 'ACTIVE_PROFILE=%q\n' "${ACTIVE_PROFILE:-}"
    printf 'EXIT_INTERFACE=%q\n' "${EXIT_INTERFACE:-}"
    printf 'FIREWALL_BACKEND=%q\n' "${FIREWALL_BACKEND:-}"
  } >"$tmp"
  chmod 600 "$tmp"; mv -f "$tmp" "$STATE_FILE"
}

detect_distro() {
  DISTRO_ID=unknown DISTRO_LIKE=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID=${ID:-unknown}; DISTRO_LIKE=${ID_LIKE:-}
  fi
}
