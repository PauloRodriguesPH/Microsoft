# 04 - Firewall da VM e NSG de saída

Objetivo: **quem entrar na VPN só consegue chegar na TCP 445 do storage.** Nada de internet, nada de acesso à própria VM. Duas camadas independentes.

## Camada 1: firewall da VM (iptables)

O instalador cria o serviço `iptables-openvpn`, que roda dois scripts em `/etc/iptables/`:

- `add-openvpn-rules.sh` (ao iniciar)
- `rm-openvpn-rules.sh` (ao parar)

As regras abaixo **substituem** esses scripts.

### Regras finais

| Regra | O que faz |
|---|---|
| `INPUT -i eth0 -p tcp --dport 853 -j ACCEPT` | Aceita o OpenVPN pela interface pública |
| `INPUT -i tun+ -s 10.8.0.0/24 -j DROP` | O cliente da VPN **não fala com a própria VM** (nem SSH, nem ping em `10.8.0.1`) |
| `FORWARD -o tun+ ... ESTABLISHED,RELATED -j ACCEPT` | Deixa passar as respostas para os clientes |
| `FORWARD -i tun+ -s 10.8.0.0/24 -j OPENVPN_INSTALL_FORWARD` | Todo tráfego que vem da VPN passa pela chain de filtro |
| `OPENVPN_INSTALL_FORWARD -d <IP_STORAGE> -p tcp --dport 445 -j ACCEPT` | **A única coisa permitida** |
| `OPENVPN_INSTALL_FORWARD -j REJECT` | Todo o resto é rejeitado |
| `nat POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE` | NAT: o tráfego sai com o IP da VM |

Templates em [`scripts/server/firewall/`](../scripts/server/firewall/).

### Aplicar (jeito seguro)

```bash
cd ~/openvpn-azure-smb-workaround/scripts/server   # ou onde você colocou os arquivos
sudo STORAGE_IP=198.51.100.20 VPN_PORT=853 ./03-aplicar-firewall.sh
```

O script segue uma ordem que **evita regras órfãs**:

1. **Para** o serviço `iptables-openvpn` (isso roda o `rm` **antigo** e remove as regras antigas).
2. Substitui os dois arquivos.
3. **Inicia** o serviço (roda o `add` novo) e reinicia o OpenVPN.

> **Pegadinha observada:** se você editar os scripts e **só** reiniciar o serviço, o `rm` novo tenta remover a regra *nova*, a regra *antiga* continua no kernel, e as duas coexistem. Nesse caso a regra nova (`DROP`) fica no topo e vale, mas a antiga (`ACCEPT`) sobra. Para limpar na mão:
> ```bash
> sudo iptables -D INPUT -s 10.8.0.0/24 -i tun+ -j ACCEPT
> sudo iptables -S
> ```

### Conferir

```bash
sudo iptables -S
sudo iptables -t nat -S
sudo iptables -L OPENVPN_INSTALL_FORWARD -v -n
```

A chain deve mostrar o `ACCEPT` da 445 para o IP do storage **antes** do `REJECT`. Os **contadores de pacotes** sobem quando alguém usa a VPN: o `ACCEPT` quando é tráfego legítimo, o `REJECT` quando alguém tenta outra coisa.

> A interface pública foi `eth0` (padrão do Ubuntu na Azure). Confirme com `ip addr`.

## Camada 2: NSG de saída (Azure)

NSG `vm-openvpn-br-nsg` > **Outbound security rules** > **Add**:

| Prioridade | Nome | Destino | Porta | Protocolo | Ação |
|---|---|---|---|---|---|
| 100 | `allow-storage-445-out` | IP `198.51.100.20/32` | 445 | TCP | **Allow** |
| 4000 | `deny-internet-out` | Service Tag **Internet** | `*` | Any | **Deny** |

As regras padrão (`AllowVnetOutBound`, etc.) continuam abaixo, nas prioridades 65000+.

### Como o NSG se comporta aqui

- O tráfego dos usuários sai da VM com o **IP da própria VM** (NAT). Por isso o NSG **não consegue separar** o tráfego da VPN do tráfego da VM: a regra vale para a VM toda.
- **Consequência:** a VM **deixa de acessar a internet**. `apt update` fica pendurado e o `curl https://example.com` dá timeout. Isso é o comportamento desejado, e é a prova de que a regra funciona.
- O NSG é **stateful**: respostas de conexões de **entrada** (seu SSH, o OpenVPN na 853) passam sozinhas. Seu SSH **não cai**.
- O DNS e o agente da VM usam o endereço da plataforma Azure, coberto pelas regras padrão de rede virtual, e continuam funcionando.

Para atualizar o sistema, veja a rotina mensal em [08](08-operacao-e-troubleshooting.md).

## Por que duas camadas?

| Camada | Protege contra |
|---|---|
| iptables na VM | Relay para qualquer destino/porta; acesso dos clientes à própria VM |
| NSG de saída | Erro ou mudança no iptables; comprometimento da VM; qualquer processo da VM falando com a internet |

Se uma falhar, a outra ainda limita o estrago.

Próximo: [05 - Clientes Windows](05-clientes-windows.md).
