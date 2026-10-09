# TechCare 

Sistema de gestão para assistências técnicas, oferecido por assinatura (SaaS).


## Estrutura

```
backend/     API REST em ASP.NET Core 8 (Entity Framework Core + SQLite + JWT)
frontend/    Painel web da loja (HTML, CSS e JavaScript responsivo)
admin-mvc/   Console do Dono em ASP.NET Core MVC
mobile/      Aplicativo Flutter com modo offline
scripts/     Atalhos para iniciar e parar o sistema
```

## Como rodar

Veja o [COMO-RODAR.md](COMO-RODAR.md). Resumo: duplo clique em `scripts/iniciar.bat` e abra http://localhost:5000.

| Acesso | Endereço | Login |
|---|---|---|
| Sistema da loja | http://localhost:5000 | `admin` / `admin123` |
| Console do Dono | http://localhost:5100 | `dono` / `dono123` |

## Perfis

| Perfil | Acesso |
|---|---|
| Dono | Console MVC: lojas, vencimentos, suspensão, sessões, relatórios |
| Administrador | Tudo da loja: serviços, produtos, atendentes, financeiro e histórico |
| Atendente | Clientes, agendamentos e ordens de serviço |

## Requisitos do manual

| Requisito | Onde está |
|---|---|
| APIs REST com ASP.NET Core | `backend/Controllers` |
| Banco com Entity Framework | `backend/Data/AppDbContext.cs` |
| Autenticação, autorização e segurança | `AuthController`, `SessaoGuard`, `PasswordHasher` |
| Painel administrativo MVC | `admin-mvc/` |
| Interface responsiva em Flutter | `mobile/lib/screens` |
| Integração com API REST | `mobile/lib/services/api_client.dart` |
| Autenticação no app | `mobile/lib/services/auth_service.dart` |
| Armazenamento local e sincronização | `mobile/lib/data/local_db.dart` e `data_service.dart` |
| Inclusão e diversidade | Campo opcional de cor ou raça, relatório agregado e acessibilidade (VLibras, leitura por voz, alto contraste) |
