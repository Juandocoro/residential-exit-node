#!/usr/bin/env bash

banner() {
  printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n RESIDENTIAL EXIT NODE MANAGER\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}

pause_ui() { read -r -p "Pulse Enter para continuar..." _; }
ask() { local prompt=$1 default=${2:-}; read -r -p "$prompt${default:+ [$default]}: " REPLY; REPLY=${REPLY:-$default}; }
confirm() { local answer; read -r -p "$1 [s/N]: " answer; [[ $answer =~ ^[sS]$ ]]; }

main_menu() {
  banner
  cat <<'EOF'
1) Preparar este equipo como nodo de salida
2) Crear conexión WireGuard
3) Importar configuración de Droplet
4) Mostrar clave pública
5) Registrar datos de Droplet
6) Levantar túnel
7) Detener túnel
8) Estado del túnel
9) Configurar interfaz de salida
10) Activar modo gateway
11) Desactivar modo gateway
12) Ver IP pública
13) Probar salida desde WireGuard
14) Diagnóstico completo
15) Activar inicio automático
16) Desactivar inicio automático
17) Exportar configuración para la Droplet
18) Backup
19) Restaurar
20) Eliminar configuración
0) Salir
EOF
}
