# Desliga a API e o Console do Dono que foram iniciados por iniciar.bat (segundo plano).
$raiz = Split-Path $PSScriptRoot -Parent
$pidsArquivo = Join-Path $raiz 'logs\pids.txt'

if (Test-Path $pidsArquivo) {
    Get-Content $pidsArquivo | ForEach-Object { if ($_ -match '^\d+$') { taskkill /F /T /PID $_ 2>$null | Out-Null } }
    Remove-Item $pidsArquivo -ErrorAction SilentlyContinue
}

# Garantia: quem ainda estiver escutando nas portas 5000 (API) e 5100 (Console).
foreach ($porta in 5000, 5100) {
    Get-NetTCPConnection -LocalPort $porta -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}
Write-Host 'Sistema desligado.' -ForegroundColor Green
Start-Sleep -Seconds 2
