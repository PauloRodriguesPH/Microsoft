# 00 - Contexto e decisões

## Cenário

A Contoso (fictícia) é uma pequena empresa com até 20 usuários e cerca de 500 GB de arquivos. O file server foi migrado para o **Azure Files**, consolidado em uma única storage account (`contosofiles01`, share `files`), acessado por **SMB** e autenticado com a **chave da storage account**. Os usuários mapeiam a unidade `L:`.

No escritório, o acesso direto funciona. Em casa, parte dos usuários **não consegue**, porque o provedor bloqueia a **TCP 445** de saída.

## Requisitos do workaround

- Só ser usado por quem tem bloqueio (as demais pessoas continuam direto).
- **Custo baixo e previsível.**
- **Nada ligado no escritório** (a solução anterior dependia de um servidor local sempre ligado, e isso era o que se queria eliminar).
- Simples de operar por uma pessoa.
- Não pode virar um relay aberto: se alguém vazar o perfil da VPN, o estrago deve ser mínimo.

## Opções avaliadas

| Opção | Resultado | Motivo |
|---|---|---|
| **Azure VPN Gateway (P2S)** | Descartada | Custo fixo mensal alto para o porte; costuma vir acompanhada de private endpoint |
| **pfSense na Azure** | Descartada | A imagem do Marketplace tem licença cobrada por hora; instalar o CE manualmente é trabalhoso e sem suporte oficial |
| **Entra Private Access** | Descartada | Exige um conector (Windows sempre ligado) e licenciamento por usuário |
| **SMB over QUIC (porta 443)** | Descartada | O Azure Files não suporta direto; o caminho é Azure File Sync em Windows Server, ou seja, outro servidor sempre ligado |
| **Mudar o método de trabalho (SharePoint/OneDrive)** | Fora do escopo | Muda a forma de trabalho da equipe, e não era o objetivo |
| **OpenVPN em VM Linux pequena na Azure** | **Escolhida** | Sem licença, barata, funciona em TCP e é conhecida da equipe |

## Decisões de projeto

1. **VPN como desvio, não como caminho padrão.** O storage continua com acesso público (restrito por chave). Isso evita a complexidade de private endpoint e DNS privado.
2. **Split tunnel.** O cliente só manda pela VPN a rota `/32` do IP do storage. A internet do usuário não passa pela VPN. Isso reduz custo (menos tráfego de saída da VM) e evita que a VM vire proxy da empresa.
3. **TCP 853.** UDP já havia dado problema em redes de usuários, e essa porta TCP foi a que conectou em todos os lugares testados. A escolha é **empírica**, e não uma recomendação universal.
4. **Perfil único para todos** (`--multi-client`). É mais simples de distribuir, e o preço é não identificar quem conectou (ver [segurança](09-seguranca-e-limites.md)). A proteção real vem de limitar o que a VPN permite, e não de quem entra.
5. **Linux (Ubuntu 24.04)**, sem licença.
6. **Menor tamanho viável (B1ms).** A família B v2 padrão do portal (B2ats_v2) falhou por cota zero na assinatura (ver [troubleshooting](08-operacao-e-troubleshooting.md)).
7. **Endurecer a VM** em duas camadas: firewall da VM (iptables) e NSG de saída da Azure.
8. **Observabilidade barata:** dois alertas de tráfego e um orçamento mensal.

## Achado importante

Instalando o OpenVPN com `--no-route-internet`, o instalador deixa a VM **sem encaminhamento de IP e sem NAT**, e o firewall dela rejeita tudo o que vem da VPN. O túnel sobe, mas **nenhum tráfego passa**. Foi preciso ligar o `ip_forward`, criar o NAT e liberar só a 445 para o IP do storage. Está em [03](03-openvpn-servidor.md) e [04](04-firewall-vm-e-nsg-saida.md).
