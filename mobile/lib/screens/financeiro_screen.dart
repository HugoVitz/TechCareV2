import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/data_service.dart';
import '../widgets/ui.dart';

/// Financeiro (Administrador): faturamento por dia, semana, mês ou ano, com período opcional.
class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  String _agrupar = 'mes';
  DateTime? _de;
  DateTime? _ate;
  Map<String, dynamic> _d = {};
  bool _carregando = false;

  static final _dia = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  num _n(dynamic v) => (v ?? 0) as num;

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final f = <String, String>{
      'agrupar': _agrupar,
      if (_de != null) 'de': DateFormat('yyyy-MM-dd').format(_de!),
      if (_ate != null) 'ate': DateFormat('yyyy-MM-dd').format(_ate!),
    };
    try {
      final d = await context.read<DataService>().financeiro(f);
      if (mounted) setState(() => _d = d);
    } on NetworkException {
      if (mounted) showMessage(context, 'O financeiro exige conexão com o servidor.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _escolherData(bool inicio) async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (inicio ? _de : _ate) ?? hoje,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 1),
    );
    if (d != null) setState(() => inicio ? _de = d : _ate = d);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final resumo = (_d['resumo'] as Map?) ?? {};
    final serie = ((_d['serie'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final ranking = ((_d['ranking'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pagamentos = ((resumo['porPagamento'] as List?) ?? [])
        .map((p) => '${p['forma']} ${formatBrl(_n(p['total']))}')
        .join(' · ');
    final maxV = serie.fold<double>(1, (a, s) => max(a, _n(s['total']).toDouble()));
    final largura = max(44.0, 0.0);

    return ScreenBody(
      title: 'Financeiro',
      subtitle: 'Faturamento das ordens concluídas por dia, semana, mês ou ano.',
      onRefresh: _carregar,
      children: [
        Panel(
          title: 'Período',
          children: [
            LabeledDropdown<String>(
              label: 'Agrupar por',
              value: _agrupar,
              items: const [
                DropdownMenuItem(value: 'dia', child: Text('Dias')),
                DropdownMenuItem(value: 'semana', child: Text('Semanas')),
                DropdownMenuItem(value: 'mes', child: Text('Meses')),
                DropdownMenuItem(value: 'ano', child: Text('Anos')),
              ],
              onChanged: (v) {
                setState(() => _agrupar = v ?? 'mes');
                _carregar();
              },
            ),
            Wrap(spacing: 10, runSpacing: 10, children: [
              TcButton(_de == null ? 'Data inicial (opcional)' : 'De: ${_dia.format(_de!)}',
                  icon: Icons.event, color: kSecondary, onPressed: () => _escolherData(true)),
              TcButton(_ate == null ? 'Data final (opcional)' : 'Até: ${_dia.format(_ate!)}',
                  icon: Icons.event, color: kSecondary, onPressed: () => _escolherData(false)),
            ]),
            const SizedBox(height: 10),
            FormActions(children: [
              TcButton(_carregando ? 'Carregando...' : 'Atualizar', onPressed: _carregando ? null : _carregar),
              TcButton('Período padrão', color: kSecondary, onPressed: () {
                setState(() {
                  _de = null;
                  _ate = null;
                });
                _carregar();
              }),
            ]),
          ],
        ),
        Panel(
          title: 'Resumo',
          children: [
            SpokenText('Faturamento no período: ${formatBrl(_n(resumo['faturamento']))}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary)),
            SpokenText('Ordens concluídas: ${resumo['ordens'] ?? 0}'),
            SpokenText('Ticket médio: ${formatBrl(_n(resumo['ticketMedio']))}'),
            SpokenText('Descontos dados: ${formatBrl(_n(resumo['descontos']))}'),
            if (pagamentos.isNotEmpty) SpokenText('Por pagamento: $pagamentos'),
          ],
        ),
        Panel(
          title: 'Faturamento por período',
          children: [
            SizedBox(
              height: 210,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < serie.length; i++)
                    SizedBox(
                      width: serie.length > 6 ? largura + 20 : null,
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (serie.length <= 6)
                          Text(formatBrl(_n(serie[i]['total'])), style: const TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: max(3.0, 130 * (_n(serie[i]['total']).toDouble() / maxV)),
                          decoration: BoxDecoration(
                            color: i == serie.length - 1 ? const Color(0xFF16A34A) : primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${serie[i]['rotulo']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SortableTable(
              columns: [
                TCol('Período', (s) => '${s['rotulo']}'),
                TCol('Ordens', (s) => '${s['ordens']}'),
                TCol('Faturamento', (s) => '${s['total']}', cell: (_, s) => Text(formatBrl(_n(s['total'])))),
              ],
              rows: serie.reversed.toList(),
            ),
          ],
        ),
        Panel(
          title: 'Vendas por atendente',
          subtitle: 'No período escolhido.',
          children: [
            if (ranking.isEmpty) const Text('Nenhum vendedor cadastrado.'),
            for (var i = 0; i < ranking.length; i++)
              ListTile(
                leading: TcAvatar(
                    foto: ranking[i]['foto'] as String?,
                    nome: '${ranking[i]['nome']}',
                    size: 40,
                    lider: i == 0 && _n(ranking[i]['total']) > 0),
                title: Text('${i + 1}º  ${ranking[i]['nome']}'),
                subtitle: Text('${ranking[i]['ordens']} OS concluída(s)'),
                trailing: Text(formatBrl(_n(ranking[i]['total'])), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ],
    );
  }
}
