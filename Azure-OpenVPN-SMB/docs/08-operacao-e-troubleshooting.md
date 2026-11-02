# 08 - Operação e troubleshooting

## Rotinas

### Atualização mensal do sistema

Com a regra `deny-internet-out` ativa, a VM não acessa a internet. Uma vez por mês:

1. NSG `vm-openvpn-br-nsg` > Outbound > edite `deny-internet-out` e mude a ação para **Allow** (ou desabilite a regra).
2. Na VM:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
3. Reinicie se pedir (`sudo reboot`).
4. **Volte a regra para Deny.** Confirme com `curl -m 5 https://example.com` (tem que dar timeout).

As atualizações automáticas de segurança do Ubuntu também ficam bloqueadas nesse período.

### Snapshot do disco

O disco da VM guarda a **CA, os certificados e as chaves** do OpenVPN. Se a VM for perdida sem backup, é preciso refazer tudo e **todos os usuários precisam de perfil novo**.

Disco `vm-openvpn-br_OsDisk_...` > **Create snapshot**. Refaça sempre que mudar a configuração.

### O IP do storage mudou

O IP do storage aparece em **três lugares**. Se a VPN parar de funcionar só para o storage:

1. Confira o IP atual: `nslookup contosofiles01.file.core.windows.net` (na VM e no PC).
2. Se mudou, atualize:
   - `push "route ..."` no `/etc/openvpn/server/server.conf`
   - o IP no firewall da VM ([`03-aplicar-firewall.sh`](../scripts/server/03-aplicar-firewall.sh))
   - a regra `allow-storage-445-out` do NSG
3. `sudo systemctl restart openvpn-server@server`. Os clientes pegam a rota nova ao reconectar.

### Perfil vazado ou dispositivo perdido

Com o perfil único, **revogar um perfil derruba todos**. O procedimento é gerar um novo perfil (subcomando `client` do instalador), distribuir e remover o antigo. Ver [segurança](09-seguranca-e-limites.md).

### Rotação das chaves do storage

Se as chaves da storage account aparecerem em chat, e-mail ou script, **rotacione** (storage account > Access keys > Rotate key, nas duas) e atualize quem usa.

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| Criar VM: `QuotaExceeded` na família `standardBasv2Family`, limite 0 | A assinatura não tem cota dessa família na região | Escolha outro tamanho (B1ms, B2s) ou peça aumento em *Usage + quotas* |
| Túnel conecta, mas nada passa | Instalou com `--no-route-internet` e não aplicou o pós-instalação | `ip_forward=1`, NAT e firewall ([03](03-openvpn-servidor.md), [04](04-firewall-vm-e-nsg-saida.md)) |
| Conectou na VPN e a **internet "caiu"**, nomes não resolvem | `block-outside-dns` no perfil (o Windows bloqueia o DNS fora do túnel) | Remover as duas linhas; ver `WFP block filters` no log ([05](05-clientes-windows.md)) |
| Editou o perfil e **nada mudou** | O cliente usa a cópia importada, não o arquivo original | **Edit Config** no cliente, ou reimportar o arquivo corrigido |
| `Test-NetConnection <nome>` falha com "Name resolution failed", mas pelo IP funciona | DNS bloqueado (item acima) | Mesma solução |
| `tracert` para o storage mostra "Protocolo de destino inacessível" | O firewall da VM rejeita ICMP | Esperado. Teste com `tnc <IP> -P 445` |
| `ping 10.8.0.1` não responde | `DROP` em INPUT para `tun+` | Esperado |
| `apt update` pendurado na VM | `deny-internet-out` ativo | Esperado. Ver rotina mensal |
| SSH deixou de entrar | O IP do administrador mudou (regra do NSG restrita) | Atualize a regra, ou use *Run command* no portal |
| `iptables -S` mostra duas regras `INPUT ... tun+` (uma `DROP` e uma `ACCEPT`) | Regra órfã por ter só reiniciado o serviço | `sudo iptables -D INPUT -s 10.8.0.0/24 -i tun+ -j ACCEPT` |
| Dois `max-clients` no `server.conf` | Linha adicionada duas vezes | Deixe só uma e reinicie o serviço |
| Segunda pessoa derruba a primeira | Instalou sem `--multi-client` | Gerar de novo com `--multi-client` (ou `duplicate-cn` no `server.conf`) |
| Cliente recusa o perfil | OpenVPN anterior à 2.5 (`tls-crypt-v2`) ou perfil copiado incompleto | Atualizar o cliente; recopiar o arquivo **inteiro** (todas as linhas `<tag>` e `</tag>`) |
| PuTTY não aceita o `.pem` | O PuTTY só lê `.ppk` | Converter no PuTTYgen |
| Arquivo salvo como `.ovpn.txt` | Salvo com o tipo de arquivo padrão | Salvar com "Todos os arquivos" |
| Alerta de orçamento chegou duplicado | E-mail no action group **e** em *recipients* | Deixe o action group como None |

## Comandos úteis

```bash
sudo systemctl status openvpn-server@server --no-pager | head -12
sudo systemctl restart openvpn-server@server
sudo journalctl -u openvpn-server@server --no-pager | tail -50
sudo iptables -L OPENVPN_INSTALL_FORWARD -v -n
sudo grep -nE "^(max-clients|push)" /etc/openvpn/server/server.conf
```
