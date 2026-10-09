import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/prefs_service.dart';
import '../widgets/sync_banner.dart';
import '../widgets/ui.dart';
import 'agendamentos_screen.dart';
import 'clientes_screen.dart';
import 'configuracoes_screen.dart';
import 'dashboard_screen.dart';
import 'ordens_screen.dart';
import 'financeiro_screen.dart';
import 'historico_screen.dart';
import 'produtos_screen.dart';
import 'servicos_screen.dart';
import 'usuarios_screen.dart';

class _Item {
  const _Item(this.icon, this.label, this.builder, {this.adminOnly = false});
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  final bool adminOnly;
}

/// Menu lateral fixo em telas largas (como o site) e gaveta no celular.
/// Atendentes não veem "Serviços" nem "Atendentes" (só o Administrador).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  late final DataService _data;
  Timer? _batimento;

  static final _all = <_Item>[
    _Item(Icons.dashboard_outlined, 'Dashboard', (_) => const DashboardScreen()),
    _Item(Icons.people_outline, 'Clientes', (_) => const ClientesScreen()),
    _Item(Icons.calendar_month_outlined, 'Agendamentos', (_) => const AgendamentosScreen()),
    _Item(Icons.assignment_outlined, 'Ordens de Serviço', (_) => const OrdensScreen()),
    _Item(Icons.build_outlined, 'Serviços', (_) => const ServicosScreen(), adminOnly: true),
    _Item(Icons.inventory_2_outlined, 'Produtos', (_) => const ProdutosScreen(), adminOnly: true),
    _Item(Icons.account_balance_wallet_outlined, 'Financeiro', (_) => const FinanceiroScreen(), adminOnly: true),
    _Item(Icons.history, 'Histórico', (_) => const HistoricoScreen(), adminOnly: true),
    _Item(Icons.manage_accounts_outlined, 'Atendentes', (_) => const UsuariosScreen(), adminOnly: true),
    _Item(Icons.settings_outlined, 'Configurações', (_) => const ConfiguracoesScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _data = context.read<DataService>();
    WidgetsBinding.instance.addObserver(this);
    _data.presenca(true);
    _batimento = Timer.periodic(const Duration(seconds: 30), (_) => _data.presenca(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _data.start();
      context.read<PrefsService>().loadRemote();
      context.read<AuthService>().refreshProfile();
    });
  }

  // Fechou ou minimizou o app: sai de "online" na hora. Voltou: entra de novo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _data.presenca(true);
      _batimento ??= Timer.periodic(const Duration(seconds: 30), (_) => _data.presenca(true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _batimento?.cancel();
      _batimento = null;
      _data.presenca(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _batimento?.cancel();
    _data.stop();
    super.dispose();
  }

  Future<void> _trocarFoto() async {
    final auth = context.read<AuthService>();
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 320, maxHeight: 320, imageQuality: 85);
      if (f == null) return;
      final mime = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      await auth.saveFoto('data:image/$mime;base64,${base64Encode(await f.readAsBytes())}');
      if (mounted) showMessage(context, 'Foto atualizada.');
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível enviar a foto. Verifique a conexão.', error: true);
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();

    if (_data.pendingCount > 0) {
      final ok = await confirmDialog(
        context,
        'Existem ${_data.pendingCount} alteração(ões) feitas offline. Sair agora vai descartá-las.',
        confirm: 'Sair mesmo assim',
      );
      if (!ok) return;
    }

    _data.stop();
    await auth.logout(); // limpa também os dados do aparelho (onLogout)
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final items = _all.where((i) => !i.adminOnly || auth.isAdmin).toList();
    if (_index >= items.length) _index = 0;

    final wide = MediaQuery.of(context).size.width >= 900;

    Widget sidebar({bool inDrawer = false}) => _Sidebar(
          items: [for (final i in items) (i.icon, i.label)],
          selected: _index,
          user: auth.usuario ?? '',
          nome: auth.nomeExibicao ?? auth.usuario ?? '',
          foto: auth.foto,
          lider: auth.lider,
          role: auth.isAdmin ? 'Administrador' : 'Atendente',
          loja: auth.lojaNome,
          onSelect: (i) {
            setState(() => _index = i);
            if (inDrawer) Navigator.pop(context);
          },
          onLogout: _logout,
          onFoto: _trocarFoto,
        );

    final body = Column(
      children: [
        const SyncBanner(),
        Expanded(child: KeyedSubtree(key: ValueKey(items[_index].label), child: items[_index].builder(context))),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: 210, child: sidebar()),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(items[_index].label)),
      drawer: Drawer(
        width: 240,
        backgroundColor: const Color(0xFF0F172A),
        child: sidebar(inDrawer: true),
      ),
      body: body,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.user,
    required this.nome,
    required this.foto,
    required this.lider,
    required this.role,
    required this.loja,
    required this.onSelect,
    required this.onLogout,
    required this.onFoto,
  });

  final List<(IconData, String)> items;
  final int selected;
  final String user;
  final String nome;
  final String? foto;
  final bool lider;
  final String role;
  final String? loja;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onFoto;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TechCare Soluções',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(children: [
                Tooltip(
                  message: 'Toque para trocar sua foto',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onFoto,
                    child: TcAvatar(foto: foto, nome: nome, size: 44, lider: lider),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('$nome\n$role${lider ? ' · 1º do mês' : ''}${(loja ?? '').isEmpty ? '' : '\n$loja'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: i == selected ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onSelect(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(items[i].$1, color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(items[i].$2,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onLogout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Sair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
