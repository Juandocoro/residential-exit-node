#!/usr/bin/env bash

CR='\033[0m'; CY='\033[1;36m'; GR='\033[1;32m'; RD='\033[0;31m'
YL='\033[0;33m'; WH='\033[1;37m'; DM='\033[2;37m'
SEP="${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CR}"

status_tag() { [[ $1 == 1 ]] && printf '%b' "${GR}[ ON  ]${CR}" || printf '%b' "${RD}[ OFF ]${CR}"; }

banner() {
  local commit='sin-git' branch='local' profile='ninguno' gateway=0 tunnel=0
  if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    commit=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || printf '?')
    branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || printf '?')
  fi
  load_state
  profile=${ACTIVE_PROFILE:-ninguno}
  [[ -n ${ACTIVE_PROFILE:-} && -f $(profile_path "$ACTIVE_PROFILE") ]] && {
    load_profile
    ip link show "$WG_INTERFACE" >/dev/null 2>&1 && tunnel=1
  }
  [[ $(sysctl -n net.ipv4.ip_forward 2>/dev/null || true) == 1 ]] && gateway=1
  printf '\n%b\n' "$SEP"
  printf '%b\n' "${CY}        RESIDENTIAL EXIT NODE MANAGER${CR}"
  printf '%b\n' "  ${DM}GitHub:${CR} ${WH}${commit}@${branch}${CR}  ${DM}│ Perfil:${CR} ${WH}${profile}${CR}"
  printf '%b\n' "  ${DM}Túnel:${CR} $(status_tag "$tunnel")  ${DM}Gateway:${CR} $(status_tag "$gateway")"
  printf '%b\n' "$SEP"
}

pause_ui() { read -r -p "Pulse Enter para continuar..." _; }
ask() { local prompt=$1 default=${2:-}; read -r -p "$prompt${default:+ [$default]}: " REPLY; REPLY=${REPLY:-$default}; }
confirm() { local answer; read -r -p "$1 [s/N]: " answer; [[ $answer =~ ^[sS]$ ]]; }

main_menu() {
  clear 2>/dev/null || true
  banner
  printf '%b\n' "  ${YL}-- CONFIGURACIÓN --${CR}"
  printf '%b\n' "  ${CY} 1)${CR} ${WH}Preparar equipo como nodo de salida${CR}"
  printf '%b\n' "  ${CY} 2)${CR} ${WH}Crear conexión WireGuard${CR}"
  printf '%b\n' "  ${CY} 3)${CR} ${WH}Importar configuración de Droplet${CR}"
  printf '%b\n' "  ${CY} 4)${CR} ${WH}Mostrar clave pública${CR}"
  printf '%b\n' "  ${CY} 5)${CR} ${WH}Registrar datos de Droplet${CR}"
  printf '%b\n' "  ${CY} 9)${CR} ${WH}Configurar interfaz de salida${CR}"
  printf '\n%b\n' "  ${YL}-- TÚNEL Y GATEWAY --${CR}"
  printf '%b\n' "  ${CY} 6)${CR} ${WH}Levantar túnel${CR}"
  printf '%b\n' "  ${CY} 7)${CR} ${WH}Detener túnel${CR}"
  printf '%b\n' "  ${CY} 8)${CR} ${WH}Estado del túnel${CR}"
  printf '%b\n' "  ${CY}10)${CR} ${WH}Activar modo gateway${CR}"
  printf '%b\n' "  ${CY}11)${CR} ${WH}Desactivar modo gateway${CR}"
  printf '%b\n' "  ${CY}12)${CR} ${WH}Ver IP pública${CR}"
  printf '%b\n' "  ${CY}13)${CR} ${WH}Probar salida desde WireGuard${CR}"
  printf '%b\n' "  ${CY}14)${CR} ${WH}Diagnóstico completo${CR}"
  printf '\n%b\n' "  ${YL}-- SISTEMA --${CR}"
  printf '%b\n' "  ${CY}15)${CR} ${WH}Activar inicio automático${CR}"
  printf '%b\n' "  ${CY}16)${CR} ${WH}Desactivar inicio automático${CR}"
  printf '%b\n' "  ${CY}17)${CR} ${WH}Exportar configuración para la Droplet${CR}"
  printf '%b\n' "  ${CY}18)${CR} ${WH}Crear backup${CR}"
  printf '%b\n' "  ${CY}19)${CR} ${WH}Restaurar backup${CR}"
  printf '%b\n' "  ${CY}20)${CR} ${RD}Eliminar configuración${CR}"
  printf '%b\n' "  ${CY}21)${CR} ${WH}Actualizar desde GitHub${CR}"
  printf '%b\n' "  ${CY} 0)${CR} ${WH}Salir${CR}"
  printf '%b\n' "$SEP"
}
