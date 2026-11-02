#!/usr/bin/env bash
# Pos-instalacao do OpenVPN (split tunnel):
#  - max-clients
#  - rota push apenas para o IP do storage
#  - ip_forward permanente
#  - remove 'block-outside-dns' do template de perfis (evita perder DNS no Windows)
#
# Uso: sudo STORAGE_IP=198.51.100.20 [MAX_CLIENTS=20] ./02-pos-instalacao.sh
#
# AVISO: consolida comandos executados manualmente. Teste em VM de laboratorio.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo."; exit 1; }
: "${STORAGE_IP:?Defina STORAGE_IP (ex.: 198.51.100.20)}"
[[ "$STORAGE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "STORAGE_IP invalido: $STORAGE_IP"; exit 1; }
MAX_CLIENTS="${MAX_CLIENTS:-20}"

CONF=/etc/openvpn/server/server.conf
TPL=/etc/openvpn/server/client-template.txt
[ -f "$CONF" ] || { echo "$CONF nao encontrado (o instalador rodou?)"; exit 1; }

cp -n "$CONF" "$CONF.bak"
[ -f "$TPL" ] && cp -n "$TPL" "$TPL.bak"

grep -q '^max-clients' "$CONF" || echo "max-clients $MAX_CLIENTS" >> "$CONF"
grep -q "^push \"route $STORAGE_IP " "$CONF" || echo "push \"route $STORAGE_IP 255.255.255.255\"" >> "$CONF"

echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn-forward.conf
sysctl --system >/dev/null

[ -f "$TPL" ] && sed -i '/block-outside-dns/d' "$TPL"

echo "== Conferencia"
grep -nE '^(max-clients|push)' "$CONF"
sysctl net.ipv4.ip_forward
[ -f "$TPL" ] && echo "block-outside-dns no template: $(grep -c block-outside-dns "$TPL" || true) (esperado 0)"
echo
echo "Perfis JA GERADOS nao sao alterados. Limpe-os:  sed -i '/block-outside-dns/d' ~/<perfil>.ovpn"
echo "Proximo: sudo STORAGE_IP=$STORAGE_IP ./03-aplicar-firewall.sh"
