# Mapeia o share do Azure Files como unidade de rede.
# A chave da storage account e digitada na hora (NAO fica gravada neste arquivo).
# Rode em PowerShell SEM administrador.
#
# Uso: .\mapear-unidade.ps1
#      .\mapear-unidade.ps1 -Conta contosofiles01 -Share files -Letra L
param(
    [string]$Conta = "contosofiles01",
    [string]$Share = "files",
    [string]$Letra = "L"
)

$hostName = "$Conta.file.core.windows.net"

$teste = Test-NetConnection -ComputerName $hostName -Port 445
if (-not $teste.TcpTestSucceeded) {
    Write-Error "Nao foi possivel acessar $hostName na porta 445. Sua rede ou operadora pode estar bloqueando. Conecte a VPN e tente de novo."
    return
}

$sec = Read-Host "Chave (access key) da storage account $Conta" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try {
    $chave = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    & cmdkey.exe "/delete:$hostName" | Out-Null
    & cmdkey.exe "/add:$hostName" "/user:localhost\$Conta" "/pass:$chave" | Out-Null
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $chave = $null
}

New-PSDrive -Name $Letra -PSProvider FileSystem -Root "\\$hostName\$Share" -Persist
