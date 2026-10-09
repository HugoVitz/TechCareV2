# TechCare Mobile (Flutter)

App do TechCare Pro para **Android, iOS, web e desktop**. Consome a API REST em ASP.NET Core,
guarda o JWT com segurança e funciona offline (cache local + fila de sincronização).
Guia completo em `../COMO-RODAR.md`.

## Como rodar

1. Instale o Flutter (3.22 ou superior) e rode a API (`../backend`) na porta 5000.
2. Gere as pastas de plataforma (só na primeira vez):

   ```bash
   cd mobile
   flutter create . --platforms=android,web --org br.com.techcare --project-name techcare_mobile
   flutter pub get
   ```

   O comando não sobrescreve `lib/`, `pubspec.yaml` nem `test/`.

3. Libere HTTP em desenvolvimento (a API local não usa HTTPS):

   - **Android** — em `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET" />
     <application android:usesCleartextTraffic="true" ...>
     ```
   - **iOS** — em `ios/Runner/Info.plist`:
     ```xml
     <key>NSAppTransportSecurity</key>
     <dict><key>NSAllowsLocalNetworking</key><true/></dict>
     ```
   Em produção use HTTPS e remova essas liberações.

4. Execute:

   ```bash
   flutter run                                   # emulador Android (API em 10.0.2.2:5000)
   flutter run --dart-define=API_BASE=http://192.168.0.10:5000/api   # aparelho físico
   ```

   Também dá para trocar o endereço na tela de login (ícone de engrenagem).

5. Testes: `flutter test`

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `lib/services/api_client.dart` | Cliente HTTP: anexa o JWT, mostra o motivo quando a sessão é derrubada, detecta senha provisória |
| `lib/services/auth_service.dart` | Login, troca de senha e sessão (flutter_secure_storage / localStorage na web) |
| `lib/services/data_service.dart` | Camada offline-first: cache, fila de pendências e sincronização |
| `lib/services/prefs_service.dart` | Configurações (tema, cor, fonte, contraste, VLibras, voz), salvas no servidor e no aparelho |
| `lib/services/tts_service.dart`, `vlibras*.dart` | Leitura por voz (pt-BR) e VLibras (somente na versão web) |
| `lib/data/local_db.dart` | Armazenamento local multiplataforma (`shared_preferences`) |
| `lib/screens/` | Login, troca de senha, Dashboard, Clientes, Agendamentos, Ordens de Serviço, Serviços, Produtos, Financeiro, Histórico, Atendentes, Configurações |
| `lib/widgets/ui.dart` | Componentes iguais aos do site: painéis, campos, tabela com ordenação A-Z/Z-A, máscara R$ |

## Igual ao site

As telas, textos, campos e funções espelham `frontend/`. Diferenças inevitáveis: o VLibras é um plugin de página web e só aparece na
versão para navegador; o PDF da OS é gerado com o pacote `pdf`/`printing` (baixa no navegador e abre o compartilhamento no celular).
Perfis: o **Administrador** vê Serviços e Atendentes; o **Atendente** não. A conta do **Dono** só entra no Console web.

## Como funciona o modo offline

- **Leitura:** a API é consultada e o resultado é gravado no armazenamento local; sem rede, o app mostra o último cache.
- **Escrita:** sem rede, clientes, agendamentos e serviços novos/editados vão para a fila de pendências.
  Registros criados offline recebem id negativo ("pendente") até o servidor responder.
- **Sincronização:** automática quando a conexão volta e manual pelo botão "Sincronizar". A fila é enviada em ordem;
  operações recusadas pelo servidor são descartadas e o usuário é avisado.
- **Exclusão** e a gestão de **Atendentes** exigem conexão.
- No **logout** (ou quando o servidor derruba a sessão) os dados locais são apagados, para outra loja no mesmo aparelho não ver nada.
- iOS: adicione `NSPhotoLibraryUsageDescription` ao `Info.plist` (anexar imagens na OS).
