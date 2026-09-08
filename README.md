# Residential Exit Node Manager

Administrador interactivo y modular para convertir un Linux convencional en nodo de salida residencial de una Droplet mediante WireGuard. El dispositivo inicia el túnel, por lo que funciona detrás de NAT o CGNAT sin abrir puertos en el router doméstico.

## Plataformas

- Arch Linux y CachyOS (`pacman`)
- Debian y Ubuntu (`apt`)
- Mini PC, Raspberry Pi o laptop con una de esas distribuciones

Android/Termux no está soportado. El instalador no reinicia el equipo.

## Seguridad y convivencia

- La clave privada se crea con permisos `600`, nunca se muestra y no entra en los logs.
- Las reglas cubren únicamente la subred WireGuard elegida y llevan la marca `RESIDENTIAL_EXIT_NODE`.
- nftables usa una tabla propia llamada `residential_exit_node`; al desactivar se borra sólo esa tabla. Nunca se ejecuta `nft flush ruleset`.
- iptables/iptables-nft añade y retira reglas exactas con comentarios. UFW no se desactiva; cuando está activo se usa su mismo backend netfilter.
- firewalld usa reglas direct exactas y marcadas para forwarding y NAT.
- No se sustituyen `/etc/nftables.conf` ni reglas de Docker. Al desactivar no se fuerza `ip_forward=0`, porque otro servicio podría necesitarlo.
- Antes de modificar WireGuard, sysctl o systemd se guardan copias en `/var/backups/residential-exit-node/`.

## Instalación

Instalación rápida desde GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/Juandocoro/residential-exit-node/main/quick-install.sh | sudo bash
```

El comando instala `git` si hace falta, descarga o actualiza el proyecto en
`/opt/residential-exit-node`, instala sus dependencias y no reinicia el equipo.
Después abra el menú con:

```bash
sudo /opt/residential-exit-node/exit-node.sh
```

Instalación manual:

```bash
cd residential-exit-node
sudo ./install.sh
sudo ./exit-node.sh
```

El menú permite preparar el equipo de extremo a extremo o ejecutar cada operación por separado. Los datos viven en `/etc/residential-exit-node/profiles/`; una configuración WireGuard se activa a la vez por nombre de interfaz.

## Crear y conectar un nodo

1. Ejecute la opción **9** y seleccione la interfaz física que tiene salida a Internet. No se presupone `wlan0`.
2. Use **2** y escriba nombre, interfaz WireGuard, CIDR local, IP WireGuard de la Droplet, endpoint, puerto y clave pública de la Droplet.
3. Use **4** para copiar la clave pública del nodo.
4. En la Droplet, añada esa clave como peer. La opción **17** genera el bloque y sus variables.
5. Use **6** para levantar el túnel y **10** para activar forwarding, NAT y retorno `ESTABLISHED,RELATED`.
6. Use **15** para persistencia mediante `wg-quick@<interfaz>` y `residential-exit-gateway.service` después de `network-online.target`. `PersistentKeepalive = 25` mantiene el enlace detrás de NAT.

Ejemplo de peer que se exporta para la Droplet:

```ini
[Peer]
PublicKey = CLAVE_PUBLICA_DEL_NODO
AllowedIPs = 0.0.0.0/0
```

`0.0.0.0/0` es para el lado Droplet junto con policy routing y `Table = off`; no debe convertirse en la ruta por defecto administrativa principal de la Droplet.

## Verificación

Handshake y tráfico:

```bash
sudo wg show wg-exit
sudo wg show wg-exit latest-handshakes
sudo wg show wg-exit transfer
```

NAT, según el backend detectado:

```bash
sudo nft list table ip residential_exit_node
sudo iptables-save | grep RESIDENTIAL_EXIT_NODE
sudo firewall-cmd --permanent --direct --get-all-rules | grep RESIDENTIAL_EXIT_NODE
```

La opción **13** comprueba forwarding, reglas y ruta de salida sin cambiar rutas. La opción **14** presenta resumen, interfaces, rutas, firewall, RX/TX, último handshake e IP pública.

## Perfiles, backups y restauración

Cada perfil es un archivo `600` bajo `/etc/residential-exit-node/profiles/`. Crear o importar otro perfil lo convierte en activo; una interfaz WireGuard no puede tener dos perfiles activos simultáneamente. Las opciones **18** y **19** crean y restauran backups con estructura de rutas completa.

## Desinstalación

```bash
sudo ./uninstall.sh
```

Detiene y deshabilita las unidades administradas, retira sólo las reglas propias y elimina claves/configuración del proyecto. Conserva dependencias y backups para recuperación.

## Desarrollo y pruebas

Las pruebas no modifican red, firewall, `/etc` ni systemd; usan un directorio temporal:

```bash
bash -n ./*.sh lib/*.sh tests/*.sh
bash tests/test_core.sh
shellcheck ./*.sh lib/*.sh tests/*.sh
```

## Archivos principales

- `exit-node.sh`: menú y coordinación.
- `lib/wireguard.sh`: perfiles, claves y configuración del túnel.
- `lib/firewall.sh` y `lib/routing.sh`: reglas idempotentes, NAT y forwarding.
- `lib/persistence.sh`: unidades systemd.
- `lib/diagnostics.sh`: estado y pruebas no destructivas.
- `lib/backup.sh`: respaldo y restauración.
- `install.sh` / `uninstall.sh`: ciclo de vida.
- `quick-install.sh`: instalación o actualización remota con un solo comando.
