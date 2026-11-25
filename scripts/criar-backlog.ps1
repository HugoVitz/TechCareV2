# Cria o backlog do PIM VIII no GitHub: rótulos, marcos (sprints), issues e o quadro do GitHub Projects.
# Pré-requisitos: GitHub CLI instalado (https://cli.github.com) e login com permissão de projetos:
#   gh auth login
#   gh auth refresh -s project
# Uso (na pasta do repositório):
#   .\scripts\criar-backlog.ps1                     -> cria tudo com as issues abertas
#   .\scripts\criar-backlog.ps1 -MarcarConcluidas   -> fecha as issues (o quadro mostra tudo em "Done")
param([switch]$MarcarConcluidas)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$dados = Get-Content (Join-Path $raiz 'docs\agil\backlog.json') -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Instale o GitHub CLI: https://cli.github.com' }
Push-Location $raiz
try {
    $repo = gh repo view --json nameWithOwner -q .nameWithOwner
    Write-Host "Repositório: $repo" -ForegroundColor Cyan

    # 1) Rótulos por épico e por prioridade (MoSCoW)
    $rotulos = @{ 'Banco' = '1d4ed8'; 'DevOps' = '0f766e'; '.NET' = '7c3aed'; 'Qualidade' = '15803d'; 'Segurança' = 'b91c1c';
                  'Must' = 'dc2626'; 'Should' = 'f59e0b'; 'Could' = '64748b'; 'user story' = '0ea5e9' }
    foreach ($r in $rotulos.GetEnumerator()) { gh label create $r.Key --color $r.Value --force | Out-Null }

    # 2) Marcos = sprints (com data de término)
    $existentes = gh api "repos/$repo/milestones?state=all&per_page=100" | ConvertFrom-Json
    foreach ($s in $dados.sprints) {
        if (-not ($existentes | Where-Object title -eq $s.nome)) {
            gh api "repos/$repo/milestones" -f title="$($s.nome)" -f description="$($s.objetivo) ($($s.inicio) a $($s.fim))" -f due_on="$($s.fim)T23:59:59Z" | Out-Null
        }
    }

    # 3) Quadro do GitHub Projects
    $projeto = gh project create --owner '@me' --title $dados.projeto --format json | ConvertFrom-Json
    Write-Host "Projeto criado: $($projeto.url)" -ForegroundColor Green

    # 4) Uma issue por história de usuário, ligada ao sprint e ao quadro
    foreach ($i in $dados.itens) {
        $corpo = @"
**História:** $($i.historia)

**Critérios de aceite:** $($i.aceite)

**Estimativa:** $($i.pontos) pontos · **Prioridade:** $($i.prioridade) · **Épico:** $($i.epico)
"@
        $url = gh issue create --title "[$($i.id)] $($i.titulo)" --body $corpo --label 'user story' --label $i.epico --label $i.prioridade --milestone $i.sprint
        gh project item-add $projeto.number --owner '@me' --url $url | Out-Null
        if ($MarcarConcluidas) { gh issue close $url --reason completed | Out-Null }
        Write-Host "  $($i.id) -> $url"
    }

    Write-Host ''
    Write-Host "Pronto. Abra $($projeto.url) e use a visualização Board (Kanban) agrupada por Status." -ForegroundColor Green
}
finally {
    Pop-Location
}
