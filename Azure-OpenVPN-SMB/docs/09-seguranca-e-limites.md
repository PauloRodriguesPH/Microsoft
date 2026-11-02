# 09 - Segurança e limites

## O que protege o quê

| Camada | Proteção |
|---|---|
| Porta 853 aberta para o mundo | `tls-crypt-v2`: sem o perfil, o servidor não responde ao handshake. Certificados ECDSA, TLS 1.2+ (padrões do instalador) |
| SSH | Só chave (sem senha) e origem restrita ao IP do administrador no NSG |
| Dentro da VPN | `DROP` em INPUT para `tun+`: o cliente não alcança a própria VM |
| Saída da VM | Firewall (só TCP 445 para o IP do storage) e NSG (nega a internet) |
| Acesso ao arquivo | Continua dependendo da **chave da storage account** |

## O que um perfil vazado permite

Quem tiver o `.ovpn` consegue **conectar na VPN** e alcançar **TCP 445 no IP do storage**. Não consegue:

- usar a VM como proxy para a internet;
- acessar a própria VM;
- ler arquivos sem a chave da storage account.

Detalhe: o IP do storage é um endereço de **cluster do Azure Storage**, compartilhado com outras contas. Alguém com o perfil pode abrir SMB contra esse IP, mas precisa da chave de cada conta para ler algo.

## Limites da solução

1. **Perfil único = sem identidade.** Não dá para saber **quem** conectou, só o **IP de origem** e o horário. Também não dá para revogar uma pessoa sem trocar o perfil de todos. Perfis individuais não resolveriam: o arquivo pode ser copiado para outra máquina.
2. **Não dá para filtrar por MAC.** A VPN é de camada 3 (`tun`): o MAC da placa do usuário nunca chega ao servidor. Mesmo em camada 2, seria um dado informado pelo cliente.
3. **Autenticação por chave compartilhada.** A chave da storage account dá acesso total ao share. Evolução natural: autenticação baseada em identidade (Entra ID/Kerberos) no Azure Files.
4. **VM única = ponto único de falha.** Se cair, quem depende da VPN fica sem acesso. Quem não tem bloqueio nem percebe. Mitigação: snapshot do disco, alerta de disponibilidade e a possibilidade de recriar a VM em minutos a partir da documentação.
5. **IP do storage fixo em três lugares.** Pode mudar sem aviso (ver [operação](08-operacao-e-troubleshooting.md)).
6. **Sem atualizações automáticas** enquanto o NSG nega a internet. Exige a rotina mensal.
7. **Custo variável de saída.** Um uso muito acima do previsto gera custo. Os alertas são avisos, não travas.
8. **Instalador de terceiros** que roda como root. Leia o código, fixe a versão que usou e acompanhe as mudanças.

## Boas práticas aplicadas

- **Nada de segredos no repositório.** Perfis, chaves e senhas fora do controle de versão (`.gitignore`).
- **Chave da storage account** digitada na hora no script de mapeamento, nunca gravada em arquivo.
- **Rotacionar** qualquer chave que tenha sido exposta em chat, e-mail ou script.
- **Snapshot do disco** guardando a PKI.
- **Alertas e orçamento** para evitar surpresa na fatura.

## O que não faria

- Abrir a 22 para qualquer origem "só um pouquinho".
- Colocar toda a internet dos usuários na VPN (custo e risco).
- Deixar a VM com acesso livre à internet "para facilitar a manutenção".
