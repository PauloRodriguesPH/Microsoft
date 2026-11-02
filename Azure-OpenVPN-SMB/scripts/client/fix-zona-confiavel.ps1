# Adiciona *.file.core.windows.net aos Sites Confiaveis do usuario atual.
# Reduz avisos de "arquivo de outro computador"/Modo Protegido ao abrir arquivos pela unidade mapeada.
# Roda por usuario (HKCU), NAO precisa de administrador.
# TESTE ANTES de distribuir: so aplique se o aviso realmente aparecer.

Write-Host "Configurando zona de seguranca..." -ForegroundColor Cyan

$zonaPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\file.core.windows.net\*"

New-Item -Path $zonaPath -Force | Out-Null
New-ItemProperty -Path $zonaPath -Name "https" -PropertyType DWord -Value 2 -Force | Out-Null
New-ItemProperty -Path $zonaPath -Name "file"  -PropertyType DWord -Value 2 -Force | Out-Null
New-ItemProperty -Path $zonaPath -Name "*"     -PropertyType DWord -Value 2 -Force | Out-Null

$valores = Get-ItemProperty -Path $zonaPath -ErrorAction SilentlyContinue
if ($valores -and $valores."*" -eq 2) {
    Write-Host "Zona configurada: *.file.core.windows.net -> Sites Confiaveis" -ForegroundColor Green
} else {
    Write-Host "ATENCAO: nao foi possivel confirmar o registro." -ForegroundColor Red
}

# Reinicia o Explorer para aplicar sem logoff (salve qualquer copia em andamento antes).
Stop-Process -Name explorer -Force
Start-Process explorer.exe

Write-Host "Pronto. Abra um PDF e uma planilha pela unidade mapeada e confirme que o aviso sumiu." -ForegroundColor Magenta
