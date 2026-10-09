# Prepara o app Flutter (rodar UMA vez): cria a pasta android/, libera internet/HTTP e baixa os pacotes.
$ErrorActionPreference = 'Stop'
$mobile = Join-Path (Split-Path $PSScriptRoot -Parent) 'mobile'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'Flutter não encontrado. Instale o Flutter e adicione a pasta bin ao PATH (veja COMO-RODAR.md).' -ForegroundColor Red
    exit 1
}

Set-Location $mobile

if (-not (Test-Path 'android')) {
    flutter create . --platforms=android --org br.com.techcare --project-name techcare_mobile
}

$manifest = Join-Path $mobile 'android\app\src\main\AndroidManifest.xml'
$xml = Get-Content $manifest -Raw

if ($xml -notmatch 'android.permission.INTERNET') {
    $linha = '    <uses-permission android:name="android.permission.INTERNET" />'
    $xml = $xml -replace '(<manifest[^>]*>)', ('$1' + [Environment]::NewLine + $linha)
}
if ($xml -notmatch 'usesCleartextTraffic') {
    $xml = $xml -replace '<application', '<application android:usesCleartextTraffic="true"'
}
Set-Content -Path $manifest -Value $xml -Encoding UTF8

flutter pub get

Write-Host ''
Write-Host 'App preparado. Agora rode: iniciar.bat -Celular' -ForegroundColor Green
