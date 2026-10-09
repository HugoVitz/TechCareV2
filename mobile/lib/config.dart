import 'package:flutter/foundation.dart';

/// Configuração do app.
///
/// O endereço da API é escolhido automaticamente conforme a plataforma, mas pode ser trocado:
///  1. na tela de login (engrenagem) - fica salvo no aparelho;
///  2. na execução: flutter run --dart-define=API_BASE=http://192.168.0.10:5000/api
class AppConfig {
  static String get defaultApiBase {
    const fromEnv = String.fromEnvironment('API_BASE');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) {
      // Web app servido pela própria API em /app/: mesma origem, não precisa de CORS nem de IP.
      if (Uri.base.path.startsWith('/app')) return '${Uri.base.origin}/api';
      // Servidor de desenvolvimento do Flutter (flutter run -d chrome).
      return 'http://${Uri.base.host}:5000/api';
    }

    // 10.0.2.2 = "localhost" do computador visto pelo emulador Android.
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000/api';

    // Simulador iOS, Windows, macOS e Linux acessam o localhost direto.
    return 'http://127.0.0.1:5000/api';
  }

  static const List<String> statusOrdem = ['Aberta', 'Em andamento', 'Concluída', 'Cancelada'];
  static const List<String> statusAgendamento = ['Agendado', 'Cancelado', 'Em andamento', 'Realizado'];

  /// Categorias do IBGE (autodeclaração, campo opcional).
  static const List<String> etnias = [
    'Branca',
    'Preta',
    'Parda',
    'Amarela',
    'Indígena',
    'Prefiro não informar',
  ];

  static const List<String> cargos = ['Gerente', 'Técnico', 'Atendente', 'Recepcionista', 'Financeiro'];

  /// Mesmas cores principais das Configurações do site.
  static const List<String> cores = ['#2563eb', '#0ea5e9', '#4f46e5', '#7c3aed', '#15803d'];
}
