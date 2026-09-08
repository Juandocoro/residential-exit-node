#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
export REN_CONFIG_DIR="$TEST_TMP/etc/residential-exit-node"
export REN_WG_DIR="$TEST_TMP/etc/wireguard"
export REN_BACKUP_DIR="$TEST_TMP/backups"
export REN_LOG_FILE="$TEST_TMP/residential.log"
export REN_SYSCTL_FILE="$TEST_TMP/99-residential-exit.conf"
export REN_SYSTEMD_DIR="$TEST_TMP/systemd"
source "$ROOT/lib/system.sh"
source "$ROOT/lib/wireguard.sh"

failures=0
assert_ok() { "$@" || { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }; }
assert_eq() { [[ $1 == "$2" ]] || { printf 'FAIL: esperado=%s obtenido=%s\n' "$2" "$1"; failures=$((failures + 1)); }; }

assert_ok valid_ipv4 10.77.77.2/24
assert_ok valid_ipv4 192.168.1.1
! valid_ipv4 999.1.1.1 || failures=$((failures + 1))
assert_ok valid_port 51820
! valid_port 70000 || failures=$((failures + 1))
assert_ok valid_interface wg-exit
assert_eq "$(safe_id 'Casa Cali')" "casa-cali"
if command_exists python3; then assert_eq "$(network_from_cidr 10.77.77.2/24)" "10.77.77.0/24"; fi

ensure_layout
ACTIVE_PROFILE=pruebas; EXIT_INTERFACE=enp1s0; FIREWALL_BACKEND=nftables; save_state
ACTIVE_PROFILE=''; EXIT_INTERFACE=''; FIREWALL_BACKEND=''; load_state
assert_eq "$ACTIVE_PROFILE" pruebas
assert_eq "$EXIT_INTERFACE" enp1s0
assert_eq "$FIREWALL_BACKEND" nftables

if ((failures)); then printf '%s prueba(s) fallaron\n' "$failures"; exit 1; fi
printf 'Todas las pruebas críticas pasaron.\n'
