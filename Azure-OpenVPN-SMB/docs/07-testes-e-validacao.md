# 07 - Testes e validação

Rode tudo **antes de liberar para os usuários**.

## 1. Servidor (na VM)

```bash
sudo ss -tlnp | grep 853             # OpenVPN escutando
sysctl net.ipv4.ip_forward           # = 1
sudo iptables -S
sudo iptables -t nat -S              # deve ter MASQUERADE para 10.8.0.0/24
sudo iptables -L OPENVPN_INSTALL_FORWARD -v -n
systemctl status iptables-openvpn openvpn-server@server --no-pager | head -30
```

Esperado: `ip_forward = 1`, `MASQUERADE` presente, `ACCEPT` da 445 antes do `REJECT`, os dois serviços ativos.

## 2. Cliente conectado (rede normal)

Com a VPN conectada, em um PowerShell:

```powershell
Test-NetConnection contosofiles01.file.core.windows.net -Port 445   # True, interface do OpenVPN
tnc 198.51.100.20 -P 445                                            # True
tracert -d 8.8.8.8                                                  # NAO pode passar por 10.8.0.1
```

Esperado:

- O nome resolve para o IP do storage (**o DNS não foi bloqueado**) e a interface é a do OpenVPN.
- No log do cliente, a linha `Adding WFP block filters` **não aparece**.
- A internet sai pelo gateway normal do usuário.
- `tracert -d <IP do storage>` mostra `10.8.0.1` no primeiro salto e, depois, **"Protocolo de destino inacessível"**. Isso é esperado: o firewall da VM só aceita TCP 445 e rejeita as sondas ICMP.

> Atenção: um `curl https://example.com` rodado **no PC** responde normalmente, porque a internet **não** vai pela VPN. Ele não testa o NSG.

## 3. Testes negativos (a VPN não é um relay)

Com a VPN conectada, em um **CMD como administrador**:

```
route add 1.1.1.1 mask 255.255.255.255 10.8.0.1 metric 5
```

No PowerShell:

```powershell
tnc 1.1.1.1 -P 443        # tem que dar False (a VM rejeita)
tnc 198.51.100.20 -P 445  # continua True
tnc 10.8.0.1 -P 22        # tem que dar False (DROP em INPUT)
```

E remova a rota de teste:

```
route delete 1.1.1.1
```

## 4. NSG de saída (na VM)

```bash
curl -m 5 https://example.com     # tem que dar timeout (NSG deny-internet-out)
sudo apt update                   # fica pendurado (esperado)
```

E o **SSH** continua conectado (NSG stateful). Se o SSH cair, revise a regra de entrada.

## 5. O teste que realmente importa: rede com a 445 bloqueada

O que foi feito até aqui prova a **rota**, mas na rede normal a 445 já passava. Para validar o contorno:

1. Use um **hotspot de celular de uma operadora que bloqueie a 445** (ou a rede doméstica de um usuário afetado).
2. **Sem VPN:** `tnc 198.51.100.20 -P 445` tem que dar **False** (bloqueio confirmado).
3. **Conecte a VPN.** Repita: tem que dar **True**.
4. Mapeie `\\contosofiles01.file.core.windows.net\files` e **abra um arquivo**. Isso valida também a autenticação.

## 6. Persistência após reinício

Faça com ninguém conectado:

```bash
sudo reboot
```

Aguarde 1 a 2 minutos, entre de novo e rode o bloco do item 1. **Tudo tem que voltar igual**, com `ip_forward = 1`. Se uma manutenção da Azure reiniciar a VM no meio do expediente, você não vai querer descobrir isso na hora.

## 7. Checklist final antes de liberar

- [ ] Teste com hotspot bloqueado: sem VPN `False`, com VPN `True`
- [ ] Reinício da VM validado
- [ ] Regra SSH do NSG restrita ao seu IP (não `Any`)
- [ ] Perfil sem `block-outside-dns` (servidor e arquivos distribuídos)
- [ ] Alertas e orçamento ativos
- [ ] **Snapshot do disco** da VM (ver [operação](08-operacao-e-troubleshooting.md))
- [ ] Chave `.pem` guardada em cofre
