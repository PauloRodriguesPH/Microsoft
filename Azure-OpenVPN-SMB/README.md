# OpenVPN na Azure como desvio para a porta 445 (SMB)

Documentação de um workaround real, anonimizado, para uma **pequena empresa** (aqui chamada de **Contoso**, ~20 usuários, ~500 GB de arquivos) que migrou o file server para o **Azure Files** e descobriu que **alguns provedores de internet bloqueiam a porta 445 (SMB)** na saída, deixando quem trabalha de casa sem acesso.

> English summary: [README.en.md](README.en.md)

## O problema

O Azure Files acessado por SMB usa a **TCP 445**. Parte dos provedores residenciais bloqueia essa porta. O usuário afetado não consegue mapear a unidade, mesmo com as credenciais certas.

## A solução em um minuto

Uma **VM Linux pequena na própria Azure** (mesma região do storage) roda um **OpenVPN em TCP 853**. A VPN é só um **desvio**: quem não tem bloqueio continua acessando direto. Quem tem bloqueio conecta na VPN, e o tráfego **só do storage** (split tunnel) sai pela VM, de dentro da Azure, onde a 445 não é bloqueada.

```
Usuário SEM bloqueio  ───────────────── TCP 445 ─────────────────►  Azure Files
                                                                     (storage)
Usuário COM bloqueio  ── OpenVPN TCP 853 ──► VM OpenVPN ──NAT──► TCP 445 ─┘
   (split tunnel: só a rota do IP do storage vai pelo túnel)
```

A VM é endurecida para **não servir de relay**: o firewall dela só encaminha TCP 445 para o IP do storage, e o NSG da Azure bloqueia o resto da saída para a internet.

## Cenário e premissas

| Item | Valor |
|---|---|
| Empresa | Contoso (fictícia), pequena empresa |
| Usuários | até 20 |
| Dados | até 500 GB no Azure Files |
| Expediente | seg-sex, 8h às 18h |
| Região | Brazil South |
| Autenticação do storage | chave da storage account (shared key) |
| Tráfego pela VPN | só uma parte dos usuários (os com bloqueio) |

## Por que não as outras opções

| Opção | Motivo de não adotar |
|---|---|
| Azure VPN Gateway (ponto-a-site) | Custo fixo mensal alto para o porte (ver [custos](docs/01-custos.md)) |
| pfSense na Azure | A imagem do Marketplace tem cobrança de licença por hora |
| Entra Private Access | Exige conector (um Windows sempre ligado) e licenciamento por usuário |
| SMB over QUIC | O Azure Files não suporta direto; exige Windows Server com Azure File Sync |
| Mudar o método de trabalho (ex.: SharePoint/OneDrive) | Fora do escopo: muda a forma de trabalho da equipe |

Detalhes em [docs/00-contexto-e-decisoes.md](docs/00-contexto-e-decisoes.md).

## Custo (resumo)

VM B1ms + disco + IP público: na casa de **US$ 30 a 35 por mês** (estimativa), mais a saída de dados (os primeiros 100 GB/mês são grátis; depois, US$ 0,181/GB saindo de Brazil South). Detalhes e cenários em [docs/01-custos.md](docs/01-custos.md). Valores consultados em outubro de 2026: **confirme na calculadora da Azure**.

## Índice

1. [Contexto e decisões](docs/00-contexto-e-decisoes.md)
2. [Custos](docs/01-custos.md)
3. [Azure passo a passo (resource group, tags, rede, VM, NSG)](docs/02-azure-passo-a-passo.md)
4. [Servidor OpenVPN](docs/03-openvpn-servidor.md)
5. [Firewall da VM e NSG de saída](docs/04-firewall-vm-e-nsg-saida.md)
6. [Clientes Windows](docs/05-clientes-windows.md)
7. [Monitoramento, alertas e orçamento](docs/06-monitoramento-alertas-orcamento.md)
8. [Testes e validação](docs/07-testes-e-validacao.md)
9. [Operação e troubleshooting](docs/08-operacao-e-troubleshooting.md)
10. [Segurança e limites](docs/09-seguranca-e-limites.md)

## Nomes usados (convenção)

| Recurso | Nome |
|---|---|
| Resource group da VPN | `rg-vpn-br` |
| Rede virtual | `vnet-vpn-br` (`172.16.0.0/16`) |
| Sub-rede | `snet-vpn-br` (`172.16.0.0/24`) |
| VM | `vm-openvpn-br` |
| IP público | `vm-openvpn-br-ip` (Standard, estático) |
| DNS label | `contoso-vpn` → `contoso-vpn.brazilsouth.cloudapp.azure.com` |
| NSG | `vm-openvpn-br-nsg` |
| Chave SSH | `vm-openvpn-br_key` |
| Action group | `ag-vpn-email` |
| Alertas | `vpn-saida-dia-10GB`, `vpn-saida-pico-5GB-1h` |
| Orçamento | `orcamento-vpn-mensal` |
| Storage (exemplo) | `contosofiles01`, share `files` |
| Rede interna da VPN | `10.8.0.0/24` |
| Perfil de cliente | `Contoso-Azure.ovpn` |
| Unidade mapeada | `L:` |

**Tags** (no resource group): `Company=Contoso`, `Environment=PRD`, `Owner=Infra`, `Region=Brazil-South`, `Service=VPN`.

## Estrutura do repositório

```
.
├── README.md / README.en.md
├── docs/                       documentação passo a passo
├── scripts/
│   ├── server/                 scripts da VM (bash)
│   │   └── firewall/           templates das regras iptables
│   └── client/                 scripts do Windows (PowerShell)
└── linkedin/post.md            texto do post de divulgação
```

## Avisos importantes

- **IPs, nomes e valores são exemplos.** `203.0.113.10` (IP da VM) e `198.51.100.20` (IP do storage) são faixas reservadas para documentação. Substitua pelos seus.
- **Nunca versione segredos:** perfis `.ovpn`, chaves `.pem`/`.ppk`, chaves da storage account. O `.gitignore` já bloqueia as extensões comuns.
- Os scripts em `scripts/` **consolidam comandos que foram executados manualmente**, um a um, no ambiente real. Eles não foram testados de ponta a ponta como scripts únicos. **Teste em uma VM de laboratório antes de usar em produção.**
- O instalador do OpenVPN é de terceiros ([angristan/openvpn-install](https://github.com/angristan/openvpn-install)), e as opções mudam entre versões. Sempre leia o script e rode `install --help` antes.

## Licença

MIT. Veja [LICENSE](LICENSE).
