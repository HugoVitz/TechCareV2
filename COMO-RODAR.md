# Como rodar o TechCare (PIM VIII)

## Pré-requisitos

- [.NET SDK 8](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (para o PostgreSQL e os contêineres)
- [Flutter 3.22+](https://docs.flutter.dev/get-started/install) (só para o app mobile)
- Windows (só para o módulo desktop WPF)

## Opção 1: tudo em contêineres (mais simples)

```
docker compose up --build
```

| O quê | Endereço | Login |
|---|---|---|
| Sistema da loja | http://localhost:5000 | `admin` / `admin123` |
| Console do Dono (MVC) | http://localhost:5100 | `dono` / `dono123` |
| Swagger da API | http://localhost:5000/swagger | — |

A loja de demonstração já vem com clientes, produtos e ordens de serviço (procedure `sp_popular_demo`).
Para parar: `Ctrl+C` ou `docker compose down` (os dados ficam no volume `pgdata`).

## Opção 2: desenvolvimento (API rodando no Windows)

Dê duplo clique em `scripts/iniciar.bat`. Ele sobe o PostgreSQL no Docker (se ainda não estiver na
porta 5432), inicia a API e o Console do Dono e abre o navegador. Para desligar: `scripts/parar.bat`.

> Se você já tem um PostgreSQL instalado na porta 5432, crie nele o usuário `techcare` (senha `techcare_dev`)
> e o banco `techcare`, ou altere a conexão em `backend/appsettings.Development.json`.

## Módulo desktop (WPF)

Com a API rodando:

```
dotnet run --project desktop/TechCare.Desktop
```

Entre com `admin` / `admin123` e o endereço `http://localhost:5000`.

## App Flutter

```
cd mobile
flutter create . --platforms=web,android --org br.com.techcare --project-name techcare_mobile
flutter pub get
flutter run -d chrome
```

## Testes

```
dotnet test tests/TechCare.Tests                    # testes unitários (xUnit)
docker compose exec -T db psql -U techcare -d techcare < database/testes/10_testes_funcionais.sql
```

O pipeline do GitHub Actions (`.github/workflows/ci.yml`) roda tudo isso a cada push.

## Monitoramento (opcional)

```
docker compose --profile monitoramento up --build
```

Prometheus em http://localhost:9090 e Grafana em http://localhost:3000 (`admin` / `admin`).

## Kubernetes e backlog

- Kubernetes: veja `k8s/README.md`.
- Backlog no GitHub Projects: `scripts/criar-backlog.ps1` (precisa do GitHub CLI).
