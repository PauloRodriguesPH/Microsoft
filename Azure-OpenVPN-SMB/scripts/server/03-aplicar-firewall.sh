#!/usr/bin/env bash
# Substitui os scripts de firewall do instalador por versoes que:
#  - permitem SO TCP 445 para o IP do storage (vindo da VPN)
#  - bloqueiam o acesso dos clientes a propria VM
#  - fazem NAT de saida
#
# Ordem segura (evita regras orfas): PARA o servico -> troca arquivos -> INICIA.
#
# Uso: sudo STORAGE_IP=198.51.100.20 [VPN_PORT=853] ./03-aplicar-firewall.sh
#
# Requisitos: servico 'iptables-openvpn' e 'openvpn-server@server' criados pelo instalador.
# AVISO: consolida comandos executados manualmente. Teste em VM de laboratorio.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo."; exit 1; }
: "${STORAGE_IP:?Defina STORAGE_IP (ex.: 198.51.100.20)}"
[[ "$STORAGE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "STORAGE_IP invalido: $STORAGE_IP"; exit 1; }
VPN_PORT="${VPN_PORT:-853}"
DIR="$(cd "$(dirname "$0")" && pwd)/firewall"

for f in add rm; do
  [ -f "$DIR/$f-openvpn-rules.sh.template" ] || { echo "Template ausente: $DIR/$f-openvpn-rules.sh.template"; exit 1; }
done
systemctl cat iptables-openvpn >/dev/null 2>&1 || { echo "Servico iptables-openvpn nao existe."; exit 1; }

echo "1) Parando iptables-openvpn (remove as regras antigas com o rm ANTIGO)..."
systemctl stop iptables-openvpn || true

echo "2) Guardando originais e instalando os novos scripts..."
for f in add rm; do
  [ -f "/etc/iptables/$f-openvpn-rules.sh" ] && cp -n "/etc/iptables/$f-openvpn-rules.sh" "/etc/iptables/$f-openvpn-rules.sh.orig"
  sed -e "s/__STORAGE_IP__/$STORAGE_IP/g" -e "s/__VPN_PORT__/$VPN_PORT/g" \
      "$DIR/$f-openvpn-rules.sh.template" > "/etc/iptables/$f-openvpn-rules.sh"
  chmod +x "/etc/iptables/$f-openvpn-rules.sh"
done

echo "3) Iniciando iptables-openvpn e reiniciando o OpenVPN..."
systemctl start iptables-openvpn
systemctl restart openvpn-server@server

echo
echo "== Conferencia"
iptables -S
iptables -t nat -S
iptables -L OPENVPN_INSTALL_FORWARD -v -n
sysctl net.ipv4.ip_forward
ss -tlnp | grep ":$VPN_PORT" || echo "ATENCAO: nada escutando em $VPN_PORT"
