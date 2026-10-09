import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../widgets/reload_on_sync.dart';
import '../widgets/ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with ReloadOnSync {
  Map<String, dynamic> _d = {};
  Map<String, dynamic> _rank = {};
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    reload();
    // Quem entra e sai da equipe aparece/some sozinho.
    _auto = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) reload();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  @override
  Future<void> reload() async {
    try {
      final data = context.read<DataService>();
      final d = await data.dashboard();
      final r = await data.ranking();
      if (mounted) {
        setState(() {
        _d = d;
        _rank = r;
      });
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    watchSync(context);
    final primary = Theme.of(context).colorScheme.primary;

    Widget card(String titulo, String chave) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: panelBg(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SpokenText(titulo, style: TextStyle(color: mutedText(context), fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
              SpokenText('${_d[chave] ?? 0}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary)),
            ],
          ),
        );

    return ScreenBody(
      title: 'Dashboard',
      onRefresh: reload,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final cols = (box.maxWidth / 240).floor().clamp(1, 3);
            final w = (box.maxWidth - (cols - 1) * 20) / cols;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                SizedBox(width: w, child: card('Clientes cadastrados', 'clientes')),
                SizedBox(width: w, child: card('Equipe cadastrada', 'equipe')),
                SizedBox(width: w, child: card('Agendamentos cadastrados', 'agendamentos')),
              ],
            );
          },
        ),
        if (context.read<AuthService>().isAdmin) ..._indicadoresAdmin(),
        _ranking(),
      ],
    );
  }

  List<Widget> _indicadoresAdmin() {
    final online = (_d['online'] as Map?) ?? {};
    final agora = ((online['agora'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return [
      Panel(
        title: 'Quem está online',
        subtitle: 'Atualiza sozinho: quem fecha o app sai da lista na hora.',
        children: [
          if (agora.isEmpty) const Text('Ninguém online no momento.'),
          Wrap(spacing: 16, runSpacing: 12, children: [
            for (final u in agora)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.circle, color: Color(0xFF22C55E), size: 10),
                const SizedBox(width: 6),
                TcAvatar(foto: u['foto'] as String?, nome: '${u['nome']}', size: 36),
                const SizedBox(width: 8),
                Text('${u['nome']}'),
              ]),
          ]),
        ],
      ),
    ];
  }

  Widget _ranking() {
    final itens = ((_rank['itens'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final liderId = _rank['liderId'];
    final meuId = _rank['meuId'];
    final mes = '${_rank['mes'] ?? ''}';

    return Panel(
      title: mes.length == 7 ? 'Ranking de vendas ($mes)' : 'Ranking de vendas do mês',
      subtitle: 'Ordens de serviço concluídas no mês (os valores ficam em Financeiro). O 1º lugar ganha destaque dourado e a coroa na foto.',
      children: [
        if (itens.isEmpty) const Text('Nenhum vendedor cadastrado.'),
        for (final i in itens)
          Builder(builder: (context) {
            final lider = i['usuarioId'] == liderId;
            final eu = i['usuarioId'] == meuId;
            return Container(
              margin: EdgeInsets.only(bottom: 10, top: lider ? 8 : 0),
              padding: EdgeInsets.fromLTRB(14, lider ? 16 : 10, 14, 10),
              decoration: BoxDecoration(
                gradient: lider ? const LinearGradient(colors: [Color(0xFFFEF9C3), Color(0xFFFDE68A)]) : null,
                border: Border.all(color: lider ? const Color(0xFFFACC15) : lineColor(context), width: eu && !lider ? 2 : 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: lider ? const Color(0xFF1F2937) : null),
                child: Row(children: [
                  SizedBox(
                    width: 36,
                    child: Text(lider ? '🥇' : '${i['posicao']}º',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: lider ? 24 : 16, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  TcAvatar(foto: i['foto'] as String?, nome: '${i['nome']}', size: lider ? 56 : 42, lider: lider),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i['nome']}${eu ? ' (você)' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${i['cargo']}', style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                  Text('${i['ordens']} OS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: lider ? 18 : 14)),
                ]),
              ),
            );
          }),
      ],
    );
  }
}
