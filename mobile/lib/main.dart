import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/local_db.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/trocar_senha_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/prefs_service.dart';
import 'services/tts_service.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  // Composição manual das dependências: Auth <-> ApiClient <-> DataService / Prefs.
  final auth = AuthService();
  final api = ApiClient(auth);
  auth.attach(api);
  await auth.init();

  final db = LocalDb();
  final data = DataService(api, db, auth);
  final tts = TtsService();
  final prefs = PrefsService(api, tts);
  await prefs.loadLocal();

  // Ao encerrar a sessão (inclusive quando o servidor derruba), apaga os dados do aparelho
  // para que outra loja/usuário no mesmo aparelho não veja nada.
  auth.onLogout = data.clearLocal;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<DataService>.value(value: data),
        ChangeNotifierProvider<PrefsService>.value(value: prefs),
        Provider<ApiClient>.value(value: api),
        Provider<TtsService>.value(value: tts),
      ],
      child: const TechCareApp(),
    ),
  );
}

/// Permite arrastar listas e puxar para atualizar também com mouse e trackpad (web e desktop).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

ThemeData _buildTheme(PrefsService p, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final seed = hexColor(p.cor);
  var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(primary: seed);

  if (p.altoContraste) {
    scheme = scheme.copyWith(
      primary: dark ? Colors.yellow : const Color(0xFF0B3D91),
      onPrimary: dark ? Colors.black : Colors.white,
      onSurface: dark ? Colors.white : Colors.black,
      surface: dark ? Colors.black : Colors.white,
      outline: dark ? Colors.white : Colors.black,
    );
  }

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: p.altoContraste ? scheme.outline : (dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      width: p.altoContraste ? 2 : 1,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.altoContraste ? scheme.surface : (dark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FB)),
    visualDensity: p.compactar ? VisualDensity.compact : VisualDensity.adaptivePlatformDensity,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.altoContraste ? scheme.surface : (dark ? const Color(0xFF0F172A) : Colors.white),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: seed, width: 2)),
    ),
  );
}

class TechCareApp extends StatelessWidget {
  const TechCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrefsService>();

    return MaterialApp(
      title: 'TechCare Soluções',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: _buildTheme(p, Brightness.light),
      darkTheme: _buildTheme(p, Brightness.dark),
      themeMode: p.escuro ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Tamanho da fonte das Configurações (80% a 150%).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(p.fonte)),
        child: child!,
      ),
      home: Consumer<AuthService>(
        builder: (_, auth, __) {
          if (!auth.ready) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!auth.isLogged) return const LoginScreen();
          if (auth.mustChange) return const TrocarSenhaScreen();
          return const HomeShell();
        },
      ),
    );
  }
}
