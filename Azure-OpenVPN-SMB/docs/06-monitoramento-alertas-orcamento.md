# 06 - Monitoramento, alertas e orçamento

O que gera custo é a **saída de dados da VM** para os usuários. Por isso o monitoramento foca na métrica **Network Out Total**.

## Métricas (linha de base)

VM `vm-openvpn-br` > **Monitoring > Metrics** > adicione **Network In Total** e **Network Out Total** (agregação *Sum*).

Observado em 24 h com a VM parada: a saída é de **~90 MiB por dia** (ruído do agente e da plataforma). Os ~500 MiB de entrada do primeiro dia foram a instalação dos pacotes. Tudo acima disso é uso real.

> A métrica **Network Out** da VM mede o que passa **pela VM**. O acesso direto dos usuários ao storage aparece na métrica **Egress** da **storage account**, não aqui.

## Alertas

VM > **Monitoring > Alerts > Create > Alert rule**. Os dois alertas criados:

### Alerta 1: dia anormal

| Campo | Valor |
|---|---|
| Signal | Network Out Total |
| Threshold type | Static |
| Aggregation type | Total |
| Value is | Greater than |
| Unit / Threshold | **GB** / **10** |
| Check every | 1 hour |
| Lookback period | 24 hours |
| Severity | 3 - Informational |
| Name | `vpn-saida-dia-10GB` |

### Alerta 2: pico em uma hora

| Campo | Valor |
|---|---|
| Signal | Network Out Total |
| Aggregation type | Total |
| Value is | Greater than |
| Unit / Threshold | **GB** / **5** |
| Check every | 5 minutes |
| Lookback period | 1 hour |
| Severity | 2 - Warning |
| Name | `vpn-saida-pico-5GB-1h` |

**Raciocínio:** para ~20 usuários com uso moderado, um dia normal fica abaixo de uns 5 GB. 10 GB/dia sustentado já seria ~220 GB/mês, o que ultrapassa a franquia gratuita. Os valores são **palpites iniciais**: ajuste depois de duas semanas de dados reais.

### Action group

Na aba **Actions** do primeiro alerta, use **quick actions**:

| Campo | Valor |
|---|---|
| Action group name | `ag-vpn-email` |
| Display name | `VPN-Contoso` (máx. 12 caracteres) |
| Email | marcado, com o e-mail do administrador |

No segundo alerta, escolha **Use action groups** e selecione o `ag-vpn-email`.

## Orçamento (Cost Management)

Resource group `rg-vpn-br` > **Budgets** > **Add**.

| Campo | Valor |
|---|---|
| Scope | `rg-vpn-br` |
| Name | `orcamento-vpn-mensal` |
| Reset period | Monthly |
| Creation date | primeiro dia do mês corrente |
| Expiration date | uns 10 anos à frente (para não expirar sem perceber) |
| Amount | ~2× o custo fixo. No ambiente real: **R$ 300** (a moeda segue a da assinatura) |

**Alertas do orçamento:**

| Tipo | % |
|---|---|
| Actual cost | 50 |
| Actual cost | 80 |
| Actual cost | 100 |
| Forecasted cost | 100 |

O **Alert recipients (email)** é obrigatório, mesmo com action group. Se você preencher os dois, chegam **duas mensagens iguais**: para evitar, deixe o action group como **None** e use só o e-mail dos recipients.

O alerta de **previsão** pode não disparar no primeiro mês (a Azure precisa de alguns dias de histórico).

O orçamento só **avisa**: se estourar, a VM continua rodando. Os dados de custo atrasam até um dia, então o alerta **não é em tempo real**. Os alertas de tráfego da VM são o aviso rápido, e o orçamento é a rede de segurança.

## Quem está conectado (dentro da VM)

```bash
sudo systemctl status openvpn-server@server --no-pager | head -12
sudo journalctl -u openvpn-server@server --no-pager | tail -50
sudo cat /run/openvpn-server/status-server.log
```

O arquivo de status lista cada sessão com **IP de origem** e **bytes enviados/recebidos**. O `server.conf` também declara `status /var/log/openvpn/status.log`: confira qual dos dois arquivos está sendo atualizado na sua versão. Com perfil único, o **IP de origem** é o que diferencia as pessoas.

## Recomendações para depois

- Um **segundo orçamento** (ou o da assinatura) para o resource group do storage.
- Um alerta na métrica **Egress** da storage account.
- **Cost analysis** filtrando pela tag `Service: VPN` e agrupando por *Meter*, para separar VM, disco, IP e transferência.
