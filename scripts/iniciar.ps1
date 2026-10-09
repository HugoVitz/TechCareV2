# Sobe a API (que já entrega o painel web), o Console do Dono (MVC) e, se quiser, o app no celular.
#   .\iniciar.ps1              -> API + painel web + Console do Dono
#   .\iniciar.ps1 -Celular     -> idem + app Flutter no celular conectado por USB
#   .\iniciar.ps1 -SemPainel   -> só a API e o painel web (sem o Console do Dono)
#   .\iniciar.ps1 -Visivel     -> mostra as janelas da API/Console (para ver erros ao vivo)
# Por padrão a API e o Console rodam em SEGUNDO PLANO (sem janelas) e esta tela fecha sozinha.
# Para desligar: parar.bat. Os registros ficam na pasta logs\.
param([switch]$Celular, [switch]$SemPainel, [switch]$Visivel)
$raiz = Split-Path $PSScriptRoot -Parent

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host 'dotnet não encontrado. Instale o .NET SDK 8: https://dotnet.microsoft.com/download/dotnet/8.0' -ForegroundColor Red
    exit 1
}

function Get-IpLocal {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }
    $bom = $ips | Where-Object { $_.InterfaceAlias -match 'Wi-?Fi|Wireless|Ethernet' -and $_.InterfaceAlias -notmatch 'vEthernet|VirtualBox|VMware|WSL|Bluetooth' } | Select-Object -First 1
    if (-not $bom) { $bom = $ips | Select-Object -First 1 }
    return $bom.IPAddress
}

$ip = Get-IpLocal
Write-Host "IP deste computador: $ip" -ForegroundColor Cyan

$logs = Join-Path $raiz 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$pidsArquivo = Join-Path $logs 'pids.txt'
$env:ASPNETCORE_ENVIRONMENT = 'Development'

# Se já estiver rodando, derruba a instância anterior para não dar conflito de porta.
if (Test-Path $pidsArquivo) {
    Get-Content $pidsArquivo | ForEach-Object { if ($_ -match '^\d+$') { taskkill /F /T /PID $_ 2>$null | Out-Null } }
    Remove-Item $pidsArquivo -ErrorAction SilentlyContinue
}

# Inicia em segundo plano (oculto, com saída gravada em logs\) ou em janela própria (-Visivel).
function Start-Servico($nome, $pasta, $urls) {
    $argumentos = @('run', '--urls', $urls, '--no-launch-profile')
    if ($Visivel) {
        return Start-Process powershell -PassThru -ArgumentList '-NoExit', '-Command', "`$env:ASPNETCORE_ENVIRONMENT='Development'; Set-Location '$pasta'; dotnet $($argumentos -join ' ')"
    }
    return Start-Process dotnet -PassThru -WindowStyle Hidden -WorkingDirectory $pasta -ArgumentList $argumentos `
        -RedirectStandardOutput (Join-Path $logs "$nome.log") -RedirectStandardError (Join-Path $logs "$nome-erro.log")
}

# 1) API
Write-Host 'Iniciando a API (a primeira vez demora porque baixa pacotes)...'
$pApi = Start-Servico 'api' "$raiz\backend" 'http://0.0.0.0:5000'
$pApi.Id | Add-Content $pidsArquivo

$ok = $false
for ($i = 0; $i -lt 90; $i++) {
    try {
        $r = Invoke-RestMethod 'http://127.0.0.1:5000/api/health' -TimeoutSec 2
        if ($r.api -eq 'ok') { $ok = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}

if (-not $ok) {
    Write-Host "A API não respondeu. Veja os arquivos em $logs (api.log e api-erro.log): o erro aparece lá." -ForegroundColor Red
    taskkill /F /T /PID $pApi.Id 2>$null | Out-Null
    exit 1
}
Write-Host "API no ar. Banco de dados: $($r.banco)" -ForegroundColor Green

# 2) Console do Dono (MVC)
if (-not $SemPainel) {
    $pMvc = Start-Servico 'console-dono' "$raiz\admin-mvc" 'http://localhost:5100'
    $pMvc.Id | Add-Content $pidsArquivo
    Write-Host 'Console do Dono iniciando em http://localhost:5100'
}

Write-Host ''
Write-Host "SISTEMA (clientes, no navegador do PC ou do celular): http://${ip}:5000" -ForegroundColor Cyan
Write-Host "Console do Dono (so voce):                          http://localhost:5100"
Write-Host "Swagger (teste da API):                             http://localhost:5000/swagger"
if (Test-Path "$raiz\backend\wwwroot\app\index.html") {
    Write-Host "App web (qualquer aparelho): http://${ip}:5000/app/" -ForegroundColor Cyan
} else {
    Write-Host 'App web ainda não publicado. Rode publicar-web.bat para abrir no iPhone/Android/PC pelo navegador.' -ForegroundColor Yellow
}
Write-Host "Endereço da API no app:  http://${ip}:5000/api"
Write-Host 'Logins de teste:  dono / dono123 (Console do Dono)   admin / admin123 (loja, Administrador)'
Write-Host ''

# Guarda os endereços para consulta depois (a tela fecha sozinha).
@(
    "Sistema (clientes):  http://${ip}:5000",
    "Console do Dono:     http://localhost:5100",
    "Swagger:             http://localhost:5000/swagger",
    "Endereço da API no app: http://${ip}:5000/api",
    'Logins de teste: dono / dono123 (Console)   admin / admin123 (loja)'
) | Set-Content (Join-Path $logs 'enderecos.txt') -Encoding UTF8

# 3) App no celular
if ($Celular) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Host 'Flutter não encontrado (veja COMO-RODAR.md).' -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path "$raiz\mobile\android")) {
        Write-Host 'Rode primeiro: preparar-mobile.bat' -ForegroundColor Yellow
        exit 1
    }
    Set-Location "$raiz\mobile"
    flutter run --dart-define=API_BASE=http://${ip}:5000/api
}

elseif (-not $Visivel) {
    # Tudo rodando em segundo plano: abre o sistema no navegador e fecha esta tela.
    Start-Process 'http://localhost:5000'
    Write-Host 'Rodando em segundo plano. Para desligar, use parar.bat. Fechando esta tela...' -ForegroundColor Green
    Start-Sleep -Seconds 4
    exit 0
}
