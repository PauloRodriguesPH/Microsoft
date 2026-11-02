# Remove do perfil .ovpn as linhas 'block-outside-dns' (o Windows bloquearia todo DNS fora do tunel).
# Uso:  .\limpar-perfil-ovpn.ps1 -Perfil "C:\caminho\Contoso-Azure.ovpn"
# NAO cria copia de seguranca: o perfil contem a chave privada.
param([Parameter(Mandatory = $true)][string]$Perfil)

if (-not (Test-Path -LiteralPath $Perfil)) {
    Write-Error "Arquivo nao encontrado: $Perfil"
    return
}

$antes = @(Select-String -LiteralPath $Perfil -Pattern 'block-outside-dns' -SimpleMatch).Count
$linhas = Get-Content -LiteralPath $Perfil | Where-Object { $_ -notmatch 'block-outside-dns' }
Set-Content -LiteralPath $Perfil -Value $linhas -Encoding ascii

$depois = @(Select-String -LiteralPath $Perfil -Pattern 'block-outside-dns' -SimpleMatch).Count
Write-Host "Linhas removidas: $antes | restantes: $depois (esperado 0)" -ForegroundColor Green
Write-Host "Importe o perfil de novo (ou use 'Edit Config' no cliente) e reconecte." -ForegroundColor Cyan
