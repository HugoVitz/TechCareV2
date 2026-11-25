# TechCare – PIM VIII

Solução corporativa integrada para gestão de assistências técnicas, oferecida por assinatura (SaaS).
Projeto Integrado Multidisciplinar VIII – CST em Análise e Desenvolvimento de Sistemas (UNIP EaD).

## Estrutura

```
backend/      API REST em ASP.NET Core 8 (EF Core + PostgreSQL + JWT)
  Database/   Scripts SQL: functions, procedures, triggers, índices, views e segurança
admin-mvc/    Console do Dono em ASP.NET Core MVC
core/         Biblioteca de domínio em C# (POO e padrões de projeto)
desktop/      Módulo desktop WPF (MVVM) para o Administrador da loja
tests/        Testes automatizados (xUnit)
frontend/     Painel web da loja (HTML, CSS e JavaScript)
mobile/       Aplicativo Flutter com modo offline
database/     Testes do banco (funcionais, desempenho e concorrência)
k8s/          Manifestos Kubernetes (Deployment, HPA, Ingress, NetworkPolicy)
infra/        Monitoramento (Prometheus e Grafana)
docs/agil/    Backlog do produto e sprints
.github/      Pipelines de CI/CD (GitHub Actions) e Dependabot
```

## Como rodar

Veja o [COMO-RODAR.md](COMO-RODAR.md). Resumo: `docker compose up --build` e abra http://localhost:5000.

| Acesso | Endereço | Login |
|---|---|---|
| Sistema da loja | http://localhost:5000 | `admin` / `admin123` |
| Console do Dono | http://localhost:5100 | `dono` / `dono123` |
| Módulo desktop | `dotnet run --project desktop/TechCare.Desktop` | `admin` / `admin123` |

## Requisitos do manual (PIM VIII)

| Disciplina | Requisito | Onde está |
|---|---|---|
| Cloud e DevOps | Arquitetura em nuvem | `k8s/`, `docker-compose.yml` |
| | Pipelines CI/CD | `.github/workflows/ci.yml` e `cd.yml` |
| | Docker, Kubernetes e automação | `backend/Dockerfile`, `admin-mvc/Dockerfile`, `k8s/`, `.github/dependabot.yml` |
| | Segurança, monitoramento e escalabilidade | `/health/*`, `/metrics`, HPA, NetworkPolicy, `infra/monitoramento/` |
| Projetos Ágeis | Backlog, sprints, Scrum/Kanban | `docs/agil/backlog.json`, `scripts/criar-backlog.ps1` |
| .NET | POO em C# e padrões de projeto | `core/TechCare.Core` (Strategy, Factory, Observer, Repository) |
| | Módulo desktop e arquitetura modular | `desktop/TechCare.Desktop` (MVVM, DI, Decorator) |
| | Testes e manutenção | `tests/TechCare.Tests`, CI |
| Banco de Dados | Stored procedures e functions | `backend/Database/02_functions.sql`, `03_procedures.sql` |
| | Triggers e transações | `backend/Database/04_triggers.sql` |
| | Otimização de consultas | `backend/Database/05_indices_e_views.sql`, `database/testes/20_benchmark.py` |
| | Segurança e concorrência | `06_seguranca.sql`, `sp_ajustar_estoque` (FOR UPDATE), `Produto.Versao` (xmin) |
