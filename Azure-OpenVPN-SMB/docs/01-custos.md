# 01 - Custos

> Valores consultados em **outubro de 2026**. Preços de nuvem mudam: **confirme na calculadora da Azure** antes de decidir.

## Comparativo de custo fixo

| Opção | Custo fixo aproximado |
|---|---|
| Azure VPN Gateway VpnGw1 | cerca de **US$ 0,19/hora ≈ US$ 139/mês** (referência de uma fonte de terceiros; a página oficial exibe o valor dinâmico por região e moeda) |
| **VM OpenVPN (esta solução)** | VM B1ms + disco + IP público: **US$ 30 a 35/mês** (estimativa) |

O gateway ainda é cobrado **por hora, o mês inteiro**, mesmo sem ninguém conectado.

## Detalhe da solução proposta

| Item | Valor |
|---|---|
| VM `Standard_B1ms` (Brazil South) | US$ 0,0336/hora, ou **~US$ 24,5/mês** (730 h). Valor exibido no resumo de criação da VM |
| Disco Standard SSD 30 GiB | alguns dólares/mês (estimativa, não confirmada) |
| IP público Standard estático | alguns dólares/mês (estimativa; a página de preços só mostra valor dinâmico) |
| Alertas de métrica | centavos/mês (o preview do portal mostrou US$ 0,10/mês por regra) |
| Saída de dados | ver abaixo |

## Saída de dados (o que mais varia)

- **Entrada de dados é grátis.**
- **Os primeiros 100 GB/mês de saída são grátis**, somando todos os serviços da assinatura.
- Acima disso, saindo de Brazil South: **US$ 0,181/GB** (primeiros 10 TB).
- Tráfego entre a VM e a storage account **na mesma região** não gera cobrança de saída.

Na VPN, o que é cobrado é o que a VM manda **para o usuário** (downloads de arquivos).

### Cenários (suposições, 22 dias úteis)

| Cenário | Uso | GB/mês | Custo de saída |
|---|---|---|---|
| Leve | 5 pessoas × 0,5 GB/dia | ~55 | US$ 0 (dentro dos 100 GB) |
| Típico | 10 pessoas × 1 GB/dia | ~220 | ~US$ 22 |
| Pesado | 20 pessoas × 2 GB/dia | ~880 | ~US$ 141 |

Uma VM parada gera ruído de **cerca de 90 MiB/dia** de saída (medido), o que é irrelevante.

### Atenção: o storage também gera saída

Quem acessa o Azure Files **direto**, sem VPN, também gera saída do storage para a internet, cobrada na mesma tabela. A VPN só **desloca** parte desse tráfego, e não duplica a cobrança. O orçamento do resource group da VPN **não enxerga** o custo do storage. Crie um orçamento (ou alerta na métrica `Egress`) também para o resource group do storage.

## Orçamento sugerido

Algo em torno de **2× o custo fixo**. No ambiente real foi definido um orçamento mensal de **R$ 300** (a assinatura fatura em reais), com avisos em 50%, 80% e 100%. Detalhes em [06](06-monitoramento-alertas-orcamento.md).
