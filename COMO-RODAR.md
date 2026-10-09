# Como rodar o TechCare

## Pré-requisitos

- [.NET SDK 8](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Flutter 3.22+](https://docs.flutter.dev/get-started/install) (só para o app mobile)

## Sistema web e Console do Dono

1. Dê duplo clique em `scripts/iniciar.bat`.
2. Abra os endereços:

| O quê | Endereço | Login |
|---|---|---|
| Sistema da loja | http://localhost:5000 | `admin` / `admin123` |
| Console do Dono (MVC) | http://localhost:5100 | `dono` / `dono123` |
| Documentação da API (Swagger) | http://localhost:5000/swagger | — |

Para desligar: `scripts/parar.bat`.

O banco SQLite (`backend/techcare.db`) é criado sozinho na primeira execução.

## App Flutter

Com o sistema rodando:

```
cd mobile
flutter create . --platforms=web,android --org br.com.techcare --project-name techcare_mobile
flutter pub get
flutter run -d chrome
```

Entre com `admin` / `admin123`.

## Sem os scripts

```
cd backend    && dotnet run --urls "http://0.0.0.0:5000"
cd admin-mvc  && dotnet run
```
