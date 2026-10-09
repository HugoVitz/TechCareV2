# Libera a porta 5000 no Firewall do Windows para o celular acessar a API.
# Precisa de permissão de administrador (o script pede sozinho).
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Remove-NetFirewallRule -DisplayName 'TechCare API 5000' -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName 'TechCare API 5000' -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow -Profile Any | Out-Null

Write-Host ''
Write-Host 'Porta 5000 liberada no Firewall.' -ForegroundColor Green
Write-Host 'Para remover depois: Remove-NetFirewallRule -DisplayName "TechCare API 5000"'
Write-Host ''
Read-Host 'Pressione Enter para fechar'
