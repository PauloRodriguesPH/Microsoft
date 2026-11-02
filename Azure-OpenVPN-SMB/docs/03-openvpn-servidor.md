# 03 - Servidor OpenVPN

Todos os comandos rodam **na VM**, por SSH, com o usuário `azureuser`.

> **Ordem importa:** faça a atualização do sistema e a instalação **antes** de criar as regras de saída do NSG ([04](04-firewall-vm-e-nsg-saida.md)). Depois delas, a VM não alcança mais a internet e o `apt` deixa de funcionar.

## 1. Atualizar o sistema

```bash
sudo apt update && sudo apt upgrade -y
```

## 2. Descobrir o IP do storage

O cliente vai mandar pela VPN **só** o IP do storage. Descubra:

```bash
nslookup contosofiles01.file.core.windows.net
```

Anote o `Address` da resposta (o nome é um CNAME para um endereço de cluster do Azure Storage). Exemplo usado nesta documentação: `198.51.100.20`.

Rode o mesmo comando em um PC do escritório e confirme que o IP é **o mesmo**. A rota empurrada para os clientes precisa ser o IP que eles resolvem.

> O IP do storage costuma ser estável, mas a Azure não garante. Ele fica em **três lugares** (rota do OpenVPN, firewall da VM e NSG de saída). Ver [operação](08-operacao-e-troubleshooting.md).

## 3. Baixar o instalador e ler antes de rodar

```bash
cd ~
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
less openvpn-install.sh
```

Esse é um instalador de terceiros e roda como root. **Leia antes de executar** (saia do `less` com `q`). A interface mudou entre versões. A usada aqui tem subcomandos:

```bash
sudo ./openvpn-install.sh install --help
```

Confira as opções na versão que você baixou.

## 4. Instalar

```bash
sudo ./openvpn-install.sh install \
  --endpoint contoso-vpn.brazilsouth.cloudapp.azure.com \
  --port 853 --protocol tcp \
  --no-route-internet --no-client-ipv6 \
  --multi-client \
  --client contoso
```

(O script [`01-instalar-openvpn.sh`](../scripts/server/01-instalar-openvpn.sh) faz o download e depois executa esse comando com variáveis.)

| Opção | Efeito |
|---|---|
| `--endpoint` | Nome (ou IP) que vai dentro do perfil dos clientes. Use o DNS label |
| `--port 853 --protocol tcp` | A porta e o protocolo que funcionaram nas redes dos usuários |
| `--no-route-internet` | **Split tunnel:** a internet do cliente não passa pela VPN |
| `--no-client-ipv6` | Só IPv4 |
| `--multi-client` | O **mesmo certificado** pode ser usado em vários dispositivos ao mesmo tempo (perfil único) |
| `--client contoso` | Nome do primeiro perfil |

Padrões do instalador nessa versão: cifra AES-128-GCM, certificados ECDSA (`prime256v1`), TLS mínimo 1.2, `tls-crypt-v2` e validade de 3650 dias. Atenção: o `tls-crypt-v2` exige **cliente OpenVPN 2.5 ou mais novo**.

## 5. Estado logo após instalar (o achado)

```bash
sudo ss -tlnp | grep 853
sysctl net.ipv4.ip_forward
sudo iptables -S
sudo iptables -t nat -S
```

Resultado observado com `--no-route-internet`:

- A porta 853 está em escuta (ok).
- **`net.ipv4.ip_forward = 0`**
- **Tabela NAT vazia**
- A chain do instalador termina em **`REJECT`**: nada encaminha.

Ou seja, o túnel sobe, mas **nenhum tráfego passa**. Isso é esperado para quem não roteia a internet, e é por isso que o passo seguinte é obrigatório.

Também não há nenhuma linha `push` em `/etc/openvpn/server/server.conf`: o cliente não recebe rota nenhuma.

## 6. Pós-instalação: rota, limite de conexões e encaminhamento

```bash
sudo cp /etc/openvpn/server/server.conf /etc/openvpn/server/server.conf.bak
echo 'max-clients 20' | sudo tee -a /etc/openvpn/server/server.conf
echo 'push "route 198.51.100.20 255.255.255.255"' | sudo tee -a /etc/openvpn/server/server.conf
sudo grep -nE "^(max-clients|push)" /etc/openvpn/server/server.conf

echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-openvpn-forward.conf
sudo sysctl --system | grep ip_forward
```

- `max-clients 20`: limite de **conexões simultâneas** (não de pessoas). Com perfil único, 20 sessões = 20 dispositivos.
- `push "route <IP> 255.255.255.255"`: o cliente envia pela VPN só esse IP.
- Confira que cada linha apareceu **uma vez** no `grep`. Duas linhas `max-clients` conflitam.

(Equivalente em script: [`02-pos-instalacao.sh`](../scripts/server/02-pos-instalacao.sh).)

## 7. Limpar o template de perfil (DNS)

O template do instalador inclui duas linhas que fazem o **Windows bloquear todo DNS que não passe pelo túnel** (proteção contra "DNS leak"). Como esta VPN **não leva DNS nem internet**, isso derruba a resolução de nomes do usuário (parece que a internet caiu). Remova:

```bash
sudo cp /etc/openvpn/server/client-template.txt /etc/openvpn/server/client-template.txt.bak
sudo sed -i '/block-outside-dns/d' /etc/openvpn/server/client-template.txt
sudo grep -c block-outside-dns /etc/openvpn/server/client-template.txt   # deve dar 0
```

E, se o perfil já foi gerado, limpe também:

```bash
sed -i '/block-outside-dns/d' ~/contoso.ovpn
grep -c block-outside-dns ~/contoso.ovpn   # deve dar 0
```

(Não deixe `.bak` do `.ovpn`: ele contém a **chave privada** do perfil.)

## 8. Firewall

Aplique as regras de [04](04-firewall-vm-e-nsg-saida.md) (ou rode [`03-aplicar-firewall.sh`](../scripts/server/03-aplicar-firewall.sh)) e reinicie:

```bash
sudo systemctl restart openvpn-server@server
systemctl status openvpn-server@server --no-pager | head -8
```

O `Status` deve ser `Initialization Sequence Completed`. Logo após o restart ele pode mostrar `Pre-connection initialization successful`, e isso é só o primeiro instante.

## 9. Renomear e levar o perfil para o PC

```bash
ls ~/*.ovpn
mv ~/contoso.ovpn ~/Contoso-Azure.ovpn
```

O nome do arquivo é o nome do perfil que o usuário vê no cliente. O nome do certificado por dentro continua o antigo, e isso não afeta nada.

Para copiar para o PC:

- **pscp** (vem com o PuTTY): `pscp -i chave.ppk azureuser@contoso-vpn.brazilsouth.cloudapp.azure.com:/home/azureuser/Contoso-Azure.ovpn .`
- ou `cat ~/Contoso-Azure.ovpn`, selecionar **o arquivo inteiro** no PuTTY, colar **no Bloco de Notas** e salvar como `Contoso-Azure.ovpn` (tipo "Todos os arquivos"). Cole só no Bloco de Notas: o arquivo contém a chave privada.

## Mais perfis

Para criar mais perfis (por exemplo, trocar o perfil de todos depois de um vazamento), use o subcomando `client` do instalador. Confira a sintaxe da sua versão com:

```bash
sudo ./openvpn-install.sh client --help
```

Próximo: [04 - Firewall da VM e NSG de saída](04-firewall-vm-e-nsg-saida.md).
