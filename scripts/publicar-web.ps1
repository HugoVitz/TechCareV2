# Compila o app Flutter para WEB e copia para backend\wwwroot\app.
# Depois qualquer aparelho com navegador (iPhone, Android, PC, Mac) abre http://IP-DO-PC:5000/app/
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$mobile = Join-Path $raiz 'mobile'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'Flutter não encontrado (veja COMO-RODAR.md).' -ForegroundColor Red
    exit 1
}

Set-Location $mobile

if (-not (Test-Path 'web')) {
    flutter create . --platforms=web --org br.com.techcare --project-name techcare_mobile
}

flutter pub get
flutter build web --release --base-href /app/
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Falha ao compilar o app web. Veja a mensagem acima.' -ForegroundColor Red
    exit 1
}

$destino = Join-Path $raiz 'backend\wwwroot\app'
if (Test-Path $destino) { Remove-Item $destino -Recurse -Force }
New-Item -ItemType Directory -Path $destino -Force | Out-Null
Copy-Item (Join-Path $mobile 'build\web\*') $destino -Recurse

Write-Host ''
Write-Host 'App web publicado em backend\wwwroot\app.' -ForegroundColor Green
Write-Host 'Reinicie a API (iniciar.bat) e abra http://IP-DO-PC:5000/app/ no celular ou no computador.'
Write-Host 'Se o navegador mostrar a versão antiga, limpe os dados do site ou abra em aba anônima.'
