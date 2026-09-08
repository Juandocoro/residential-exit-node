#!/usr/bin/env bash

service_active() { command_exists systemctl && systemctl is-active --quiet "$1"; }

detect_firewall() {
  if command_exists ufw && ufw status 2>/dev/null | grep -q '^Status: active'; then printf 'ufw\n'
  elif command_exists firewall-cmd && service_active firewalld; then printf 'firewalld\n'
  elif command_exists nft; then printf 'nftables\n'
  elif command_exists iptables; then printf 'iptables\n'
  else return 1; fi
}

iptables_add() {
  local table=$1; shift
  iptables -t "$table" -C "$@" 2>/dev/null || iptables -t "$table" -A "$@"
}
iptables_del() {
  local table=$1; shift
  while iptables -t "$table" -C "$@" 2>/dev/null; do iptables -t "$table" -D "$@"; done
}

apply_iptables_rules() {
  local wg=$1 out=$2 network=$3
  iptables_add filter FORWARD -i "$wg" -o "$out" -s "$network" -m comment --comment "$RULE_TAG" -j ACCEPT
  iptables_add filter FORWARD -i "$out" -o "$wg" -d "$network" -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "$RULE_TAG" -j ACCEPT
  iptables_add nat POSTROUTING -s "$network" -o "$out" -m comment --comment "$RULE_TAG" -j MASQUERADE
}

remove_iptables_rules() {
  local wg=$1 out=$2 network=$3
  iptables_del filter FORWARD -i "$wg" -o "$out" -s "$network" -m comment --comment "$RULE_TAG" -j ACCEPT
  iptables_del filter FORWARD -i "$out" -o "$wg" -d "$network" -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "$RULE_TAG" -j ACCEPT
  iptables_del nat POSTROUTING -s "$network" -o "$out" -m comment --comment "$RULE_TAG" -j MASQUERADE
}

apply_nft_rules() {
  local wg=$1 out=$2 network=$3
  nft list table ip residential_exit_node >/dev/null 2>&1 || nft add table ip residential_exit_node
  nft list chain ip residential_exit_node forward >/dev/null 2>&1 || nft 'add chain ip residential_exit_node forward { type filter hook forward priority filter; policy accept; }'
  nft list chain ip residential_exit_node postrouting >/dev/null 2>&1 || nft 'add chain ip residential_exit_node postrouting { type nat hook postrouting priority srcnat; policy accept; }'
  nft -a list chain ip residential_exit_node forward | grep -Fq 'comment "RESIDENTIAL_EXIT_NODE outbound"' || \
    nft add rule ip residential_exit_node forward iifname "$wg" oifname "$out" ip saddr "$network" counter accept comment 'RESIDENTIAL_EXIT_NODE outbound'
  nft -a list chain ip residential_exit_node forward | grep -Fq 'comment "RESIDENTIAL_EXIT_NODE return"' || \
    nft add rule ip residential_exit_node forward iifname "$out" oifname "$wg" ip daddr "$network" ct state established,related counter accept comment 'RESIDENTIAL_EXIT_NODE return'
  nft -a list chain ip residential_exit_node postrouting | grep -Fq 'comment "RESIDENTIAL_EXIT_NODE nat"' || \
    nft add rule ip residential_exit_node postrouting ip saddr "$network" oifname "$out" counter masquerade comment 'RESIDENTIAL_EXIT_NODE nat'
}

apply_firewalld_rules() {
  local wg=$1 out=$2 network=$3
  firewall-cmd --permanent --direct --query-rule ipv4 filter FORWARD 0 -i "$wg" -o "$out" -s "$network" -m comment --comment "$RULE_TAG" -j ACCEPT >/dev/null 2>&1 || \
    firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "$wg" -o "$out" -s "$network" -m comment --comment "$RULE_TAG" -j ACCEPT >/dev/null
  firewall-cmd --permanent --direct --query-rule ipv4 filter FORWARD 0 -i "$out" -o "$wg" -d "$network" -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "$RULE_TAG" -j ACCEPT >/dev/null 2>&1 || \
    firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "$out" -o "$wg" -d "$network" -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "$RULE_TAG" -j ACCEPT >/dev/null
  firewall-cmd --permanent --direct --query-rule ipv4 nat POSTROUTING 0 -s "$network" -o "$out" -m comment --comment "$RULE_TAG" -j MASQUERADE >/dev/null 2>&1 || \
    firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s "$network" -o "$out" -m comment --comment "$RULE_TAG" -j MASQUERADE >/dev/null
  firewall-cmd --reload >/dev/null
}

remove_firewalld_rules() {
  local wg=$1 out=$2 network=$3
  firewall-cmd --permanent --direct --remove-rule ipv4 filter FORWARD 0 -i "$wg" -o "$out" -s "$network" -m comment --comment "$RULE_TAG" -j ACCEPT >/dev/null 2>&1 || true
  firewall-cmd --permanent --direct --remove-rule ipv4 filter FORWARD 0 -i "$out" -o "$wg" -d "$network" -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "$RULE_TAG" -j ACCEPT >/dev/null 2>&1 || true
  firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s "$network" -o "$out" -m comment --comment "$RULE_TAG" -j MASQUERADE >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null
}

apply_firewall() {
  local backend=$1 wg=$2 out=$3 network=$4
  case $backend in
    nftables) apply_nft_rules "$wg" "$out" "$network" ;;
    firewalld) apply_firewalld_rules "$wg" "$out" "$network" ;;
    ufw|iptables) apply_iptables_rules "$wg" "$out" "$network" ;;
    *) die "Backend de firewall no soportado: $backend" ;;
  esac
}

remove_firewall() {
  local backend=$1 wg=$2 out=$3 network=$4
  case $backend in
    nftables) nft delete table ip residential_exit_node 2>/dev/null || true ;;
    firewalld) remove_firewalld_rules "$wg" "$out" "$network" ;;
    ufw|iptables) remove_iptables_rules "$wg" "$out" "$network" ;;
  esac
}

firewall_has_rules() {
  local backend=$1
  case $backend in
    nftables) nft list table ip residential_exit_node >/dev/null 2>&1 ;;
    firewalld) firewall-cmd --permanent --direct --get-all-rules 2>/dev/null | grep -q "$RULE_TAG" ;;
    ufw|iptables) iptables-save 2>/dev/null | grep -q "$RULE_TAG" ;;
  esac
}
