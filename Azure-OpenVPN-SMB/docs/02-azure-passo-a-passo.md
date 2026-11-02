# 02 - Azure passo a passo

Tudo foi feito pelo **portal do Azure**. Região de todos os recursos: **Brazil South**. A VPN precisa estar na **mesma região** do storage para evitar cobrança de tráfego entre regiões.

## 1. Resource group

Portal > **Resource groups** > **Create**.

| Campo | Valor |
|---|---|
| Subscription | sua assinatura |
| Resource group | `rg-vpn-br` |
| Region | Brazil South |

**Aba Tags:**

| Nome | Valor |
|---|---|
| Company | Contoso |
| Environment | PRD |
| Owner | Infra |
| Region | Brazil-South |
| Service | VPN |

**Por que um resource group só para a VPN?** Ele agrupa por **função**: VM, disco, placa de rede, NSG e IP existem para a VPN. Se um dia for desativada, apaga-se o grupo inteiro, sem risco para o grupo do storage.

## 2. Criar a VM (aba Basics)

Portal > **Virtual machines** > **Create** > **Azure virtual machine**.

| Campo | Valor |
|---|---|
| Resource group | `rg-vpn-br` |
| Virtual machine name | `vm-openvpn-br` |
| Region | Brazil South |
| Availability options | No infrastructure redundancy required |
| Security type | Trusted launch (padrão) |
| Image | Ubuntu Server 24.04 LTS - x64 Gen2 |
| VM architecture | x64 |
| Size | **Standard_B1ms** (1 vCPU, 2 GiB) |
| Azure Spot | desmarcado |
| Authentication type | SSH public key |
| Username | `azureuser` |
| SSH public key source | Generate new key pair |
| SSH key type | RSA SSH Format |
| Key pair name | `vm-openvpn-br_key` |
| Public inbound ports | Allow selected ports |
| Select inbound ports | **somente SSH (22)** |

> **Cota:** se a validação falhar com `QuotaExceeded` na família `standardBasv2Family` (limite 0), escolha outro tamanho (ex.: B1ms ou B2s) ou peça aumento de cota. Ver [troubleshooting](08-operacao-e-troubleshooting.md).

O aviso amarelo de "SSH aberto para a internet" é esperado. A origem é restrita ao seu IP depois que a VM existir (passo 6).

## 3. Disks

| Campo | Valor |
|---|---|
| OS disk size | padrão (30 GiB) |
| OS disk type | **Standard SSD (locally-redundant storage)** |
| Delete with VM | marcado |
| Encryption at host | desmarcado (não registrado na assinatura; a criptografia em repouso padrão já se aplica) |
| Ultra Disk compatibility | desmarcado |
| Data disks | nenhum |

## 4. Networking

| Campo | Valor |
|---|---|
| Virtual network | **criar** `vnet-vpn-br`, espaço `172.16.0.0/16` |
| Subnet | `snet-vpn-br`, `172.16.0.0/24` |
| Public IP | **Create new**: `vm-openvpn-br-ip`, SKU **Standard**, atribuição **Static** |
| NIC network security group | Basic |
| Public inbound ports | Allow selected ports > **SSH (22)** |
| Delete public IP and NIC when VM is deleted | **desmarcado** (decisão: o IP estático pode ser reaproveitado em outra VM) |
| Accelerated networking | desmarcado |
| Load balancing | None |

> Se você preferir não deixar o IP "sobrar" ao apagar a VM, marque a opção de apagar junto. IP público estático é cobrado mesmo sem VM associada.

Para renomear a VNet e a sub-rede, use o lápis (**Edit virtual network**) no próprio assistente.

## 5. Management / Monitoring

- **Auto-shutdown: DESLIGADO.** Se ligado, a VPN cai todo dia.
- Backup e Site Recovery: desligados (a proteção é um **snapshot do disco** depois de configurar, ver [operação](08-operacao-e-troubleshooting.md)).
- Boot diagnostics: pode ficar ligado.

Clique em **Create**. Quando aparecer a janela da chave, **baixe o `vm-openvpn-br_key.pem` e guarde em local seguro** (cofre de senhas). O portal só oferece o download **uma vez**.

## 6. DNS label do IP público

Recurso `vm-openvpn-br-ip` > **Configuration** > **DNS name label**: `contoso-vpn`.

Resultado: `contoso-vpn.brazilsouth.cloudapp.azure.com`. É esse nome que vai no `remote` dos clientes, no lugar do IP.

Confira também que o IP está com **SKU Standard** (todo IP Standard é estático).

## 7. NSG de entrada (`vm-openvpn-br-nsg`)

NSG > **Inbound security rules**:

1. Edite a regra **SSH** (porta 22): **Source = IP Addresses**, com o **IP público do administrador** (confira em um site como meuip.com.br). Se o seu IP de casa mudar, o SSH deixa de entrar e a regra precisa ser corrigida. Alternativa sem depender de rede: **VM > Operations > Run command > RunShellScript**.
2. **Add** uma nova regra:

| Campo | Valor |
|---|---|
| Source | Any |
| Source port ranges | `*` |
| Destination | Any |
| Service | Custom |
| Destination port ranges | `853` |
| Protocol | TCP |
| Action | Allow |
| Priority | `310` |
| Name | `allow-openvpn-853` |

A **853 fica aberta para qualquer origem**, porque os usuários vêm de IPs variados. A proteção dela são os certificados do OpenVPN (`tls-crypt-v2`): sem o perfil, o servidor sequer responde ao handshake.

As **regras de saída** do NSG estão em [04](04-firewall-vm-e-nsg-saida.md).

## 8. Conectar por SSH (PuTTY)

O PuTTY não lê `.pem`:

1. **PuTTYgen** > **Load** (filtro "All Files") > selecione o `.pem` > **Save private key** como `.ppk`.
2. **PuTTY** > Session: Host Name = `contoso-vpn.brazilsouth.cloudapp.azure.com`, porta 22.
3. Connection > Data > Auto-login username = `azureuser`.
4. Connection > SSH > Auth > Credentials > escolha o `.ppk`.
5. Salve a sessão e clique em **Open**.

Com o cliente SSH nativo do Windows:

```powershell
icacls vm-openvpn-br_key.pem /inheritance:r
icacls vm-openvpn-br_key.pem /grant:r "$($env:USERNAME):(R)"
ssh -i vm-openvpn-br_key.pem azureuser@contoso-vpn.brazilsouth.cloudapp.azure.com
```

Próximo passo: [03 - Servidor OpenVPN](03-openvpn-servidor.md).
