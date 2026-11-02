# 05 - Clientes Windows

## Instalação

1. Instale o **OpenVPN Community client** para Windows (testado com a versão **2.7.1**, Windows 10). É preciso versão **2.5 ou mais nova**, por causa do `tls-crypt-v2`.
2. Importe o `Contoso-Azure.ovpn` (menu do ícone na bandeja > **Import file**).

## Conferir o perfil (importante)

Abra o perfil **pelo próprio cliente**: botão direito no perfil, na bandeja > **Edit Config**. O cliente guarda uma **cópia própria** do arquivo importado. Editar o arquivo original (por exemplo, o da pasta Downloads) **não altera** essa cópia.

Procure estas duas linhas e **remova** se existirem:

```
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
```

Elas fazem o Windows bloquear **todo DNS fora do túnel**. Como a VPN só leva o storage, o resultado é a **perda de DNS**: sites e o `contosofiles01...` deixam de resolver, e parece que a internet caiu. O sintoma no log do cliente é a linha:

```
Adding WFP block filters using service succeeded.
```

Depois de limpar o perfil e reconectar, essa linha **não deve aparecer**.

Script de apoio (limpa o arquivo `.ovpn` antes de importar): [`limpar-perfil-ovpn.ps1`](../scripts/client/limpar-perfil-ovpn.ps1).

Se alguém tiver um perfil antigo importado, apague e importe o novo.

## Como o usuário usa

1. **Normalmente** não precisa da VPN. O mapeamento direto funciona.
2. Se o mapeamento falhar porque o provedor bloqueia a 445, **conectar a VPN** e tentar de novo.
3. Terminado o uso, pode desconectar.

## Mapear a unidade `L:`

Script: [`mapear-unidade.ps1`](../scripts/client/mapear-unidade.ps1). Ele:

1. Testa a conexão com a porta 445. Se não passar, avisa para usar a VPN.
2. Pede a **chave da storage account** (digitada na hora, **sem ficar no arquivo**).
3. Grava a credencial no Gerenciador de Credenciais (`cmdkey`).
4. Mapeia `L:` para `\\contosofiles01.file.core.windows.net\files`.

Rode em um PowerShell **sem administrador** (a unidade mapeada em modo elevado não aparece na sessão normal).

## Aviso de "arquivo de outro computador" / Modo Protegido (opcional)

O Windows trata nomes de servidor **com pontos** (como `...file.core.windows.net`) como zona **Internet**. Isso gera avisos ao abrir PDFs e planilhas. O script [`fix-zona-confiavel.ps1`](../scripts/client/fix-zona-confiavel.ps1) adiciona `*.file.core.windows.net` aos **Sites Confiáveis** (por usuário, sem admin).

**Teste antes de distribuir:** abra um PDF e uma planilha pela unidade `L:` sem o fix. Só aplique se o aviso aparecer. Pelo que se sabe, o Azure Files não guarda a marca "bloqueado" (stream alternativo), então rodar `Unblock-File` na unidade inteira não adianta.

## Cuidados

- O perfil contém a **chave privada**. Não envie por e-mail ou chat em massa.
- Se um dispositivo for perdido ou o perfil vazar, veja [segurança](09-seguranca-e-limites.md).
