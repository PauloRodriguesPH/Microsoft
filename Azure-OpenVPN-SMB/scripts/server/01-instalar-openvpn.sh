#!/usr/bin/env bash
# Instala o OpenVPN usando o instalador de terceiros angristan/openvpn-install.
# Dois passos de proposito: 1a execucao baixa o script (para voce LER antes);
# 2a execucao instala.
#
# Uso:
#   VPN_ENDPOINT=contoso-vpn.brazilsouth.cloudapp.azure.com ./01-instalar-openvpn.sh
#   (leia o openvpn-install.sh baixado)
#   VPN_ENDPOINT=contoso-vpn.brazilsouth.cloudapp.azure.com ./01-instalar-openvpn.sh
#
# Variaveis opcionais: VPN_PORT (853), VPN_PROTO (tcp), CLIENT_NAME (contoso)
#
# AVISO: consolida comandos executados manualmente. Teste em VM de laboratorio.
set -euo pipefail

: "${VPN_ENDPOINT:?Defina VPN_ENDPOINT (ex.: contoso-vpn.brazilsouth.cloudapp.azure.com)}"
VPN_PORT="${VPN_PORT:-853}"
VPN_PROTO="${VPN_PROTO:-tcp}"
CLIENT_NAME="${CLIENT_NAME:-contoso}"

cd "$HOME"
if [ ! -f openvpn-install.sh ]; then
  curl -fsSLO https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
  chmod +x openvpn-install.sh
  echo
  echo "Instalador baixado em $HOME/openvpn-install.sh"
  echo "LEIA antes de continuar:  less ~/openvpn-install.sh"
  echo "Confira as opcoes:        sudo ./openvpn-install.sh install --help"
  echo "Depois rode este script de novo."
  exit 0
fi

echo "Instalando OpenVPN: endpoint=$VPN_ENDPOINT porta=$VPN_PORT/$VPN_PROTO cliente=$CLIENT_NAME"
sudo ./openvpn-install.sh install \
  --endpoint "$VPN_ENDPOINT" \
  --port "$VPN_PORT" --protocol "$VPN_PROTO" \
  --no-route-internet --no-client-ipv6 \
  --multi-client \
  --client "$CLIENT_NAME"

echo
echo "Instalado. PROXIMOS PASSOS (o tunel sobe, mas NADA passa ate fazer isto):"
echo "  1) sudo STORAGE_IP=<ip> ./02-pos-instalacao.sh"
echo "  2) sudo STORAGE_IP=<ip> ./03-aplicar-firewall.sh"
