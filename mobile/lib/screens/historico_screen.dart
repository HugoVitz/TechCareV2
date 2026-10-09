import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/data_service.dart';
import '../widgets/ui.dart';

/// Histórico de ordens de serviço com filtros, totais e exportação (Excel via CSV e PDF). Somente Administrador.
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _busca = TextEditingController();
  DateTime? _de;
  DateTime? _ate;
  String _status = '';
  String _pag = '';
  int? _vend;

  List<Map<String, dynamic>> _equipe = [];
  List<Map<String, dynamic>> _itens = [];
  Map<String, dynamic> _resumo = {};
  bool _carregando = false;

  static final _dia = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      final e = await context.read<DataService>().equipe();
      if (mounted) setState(() => _equipe = e);
    } catch (_) {}
    await _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final f = <String, String>{
      if (_de != null) 'de': DateFormat('yyyy-MM-dd').format(_de!),
      if (_ate != null) 'ate': DateFormat('yyyy-MM-dd').format(_ate!),
      if (_status.isNotEmpty) 'status': _status,
      if (_pag.isNotEmpty) 'pagamento': _pag,
      if (_vend != null) 'vendedorId': '$_vend',
      if (_busca.text.trim().isNotEmpty) 'q': _busca.text.trim(),
    };
    try {
      final d = await context.read<DataService>().historico(f);
      if (!mounted) return;
      setState(() {
        _resumo = Map<String, dynamic>.from(d['resumo'] as Map);
        _itens = (d['itens'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } on NetworkException {
      if (mounted) showMessage(context, 'O histórico exige conexão com o servidor.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _limpar() {
    _busca.clear();
    setState(() {
      _de = null;
      _ate = null;
      _status = '';
      _pag = '';
      _vend = null;
    });
    _carregar();
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

  String _data(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}');
    return d == null ? '-' : _dia.format(d);
  }

  num _n(dynamic v) => (v ?? 0) as num;

  // ---------------------------------------------------------------- exportação

  Future<void> _exportarCsv() async {
    if (_itens.isEmpty) return showMessage(context, 'Não há dados para exportar.', error: true);
    String c(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
    String num2(num v) => v.toStringAsFixed(2).replaceAll('.', ',');
    final sb = StringBuffer('ID;Data;Cliente;Título;Itens;Vendedor;Status;Pagamento;Desconto;Total\r\n');
    for (final o in _itens) {
      sb.write([
        o['id'],
        _data(o['dataAbertura']),
        c(o['clienteNome']),
        c(o['titulo']),
        c(o['itens']),
        c(o['vendedor'] ?? '-'),
        c(o['status']),
        c(o['formaPagamento'] ?? '-'),
        num2(_n(o['desconto'])),
        num2(_n(o['total'])),
      ].join(';'));
      sb.write('\r\n');
    }
    sb.write(';;;;;;;Faturamento (concluídas);;${num2(_n(_resumo['faturamento']))}\r\n');
    // BOM para o Excel abrir com acentos; separador ";" é o padrão do Excel em português.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())]);
    try {
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'text/csv', name: 'historico-os.csv')],
          fileNameOverrides: ['historico-os.csv']);
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível exportar neste dispositivo.', error: true);
    }
  }

  Future<void> _exportarPdf() async {
    if (_itens.isEmpty) return showMessage(context, 'Não há dados para exportar.', error: true);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('TechCare Soluções - Histórico de ordens de serviço',
            style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(
            'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}  |  Ordens: ${_resumo['quantidade']}  |  '
            'Faturamento: ${formatBrl(_n(_resumo['faturamento']))}  |  Ticket médio: ${formatBrl(_n(_resumo['ticketMedio']))}  |  '
            'Descontos: ${formatBrl(_n(_resumo['descontos']))}',
            style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 8),
      ]),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: ['ID', 'Data', 'Cliente', 'Título', 'Itens', 'Vendedor', 'Status', 'Pagamento', 'Desconto', 'Total'],
          data: [
            for (final o in _itens)
              [
                '${o['id']}',
                _data(o['dataAbertura']),
                '${o['clienteNome']}',
                '${o['titulo']}',
                '${o['itens']}',
                '${o['vendedor'] ?? '-'}',
                '${o['status']}',
                '${o['formaPagamento'] ?? '-'}',
                formatBrl(_n(o['desconto'])),
                formatBrl(_n(o['total'])),
              ]
          ],
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerStyle: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        ),
      ],
    ));
    try {
      await Printing.sharePdf(bytes: await doc.save(), filename: 'historico-os.pdf');
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível gerar o PDF neste dispositivo.', error: true);
    }
  }

  // ---------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final pagamentos = ((_resumo['porPagamento'] as List?) ?? [])
        .map((p) => '${p['forma']} ${formatBrl(_n(p['total']))}')
        .join(' · ');

    return ScreenBody(
      title: 'Histórico e relatórios',
      subtitle: 'Consulte ordens antigas e exporte o resultado.',
      onRefresh: _carregar,
      children: [
        Panel(
          title: 'Filtros',
          children: [
            Wrap(spacing: 10, runSpacing: 10, children: [
              TcButton(_de == null ? 'Data inicial' : 'De: ${_dia.format(_de!)}',
                  icon: Icons.event, color: kSecondary, onPressed: () => _escolherData(true)),
              TcButton(_ate == null ? 'Data final' : 'Até: ${_dia.format(_ate!)}',
                  icon: Icons.event, color: kSecondary, onPressed: () => _escolherData(false)),
            ]),
            LabeledDropdown<String>(
              label: 'Status',
              value: _status,
              items: [
                for (final s in ['', 'Aberta', 'Em andamento', 'Concluída', 'Cancelada'])
                  DropdownMenuItem(value: s, child: Text(s.isEmpty ? 'Todos' : s)),
              ],
              onChanged: (v) => setState(() => _status = v ?? ''),
            ),
            LabeledDropdown<String>(
              label: 'Pagamento',
              value: _pag,
              items: [
                for (final s in ['', 'Pix', 'Cartão', 'Dinheiro'])
                  DropdownMenuItem(value: s, child: Text(s.isEmpty ? 'Todos' : s)),
              ],
              onChanged: (v) => setState(() => _pag = v ?? ''),
            ),
            LabeledDropdown<int?>(
              label: 'Vendedor',
              value: _vend,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                for (final u in _equipe) DropdownMenuItem<int?>(value: u['id'] as int, child: Text('${u['nome']}')),
              ],
              onChanged: (v) => setState(() => _vend = v),
            ),
            LabeledField(label: 'Buscar (cliente, título, descrição)', controller: _busca, hint: 'Digite para buscar'),
            FormActions(children: [
              TcButton(_carregando ? 'Carregando...' : 'Filtrar', onPressed: _carregando ? null : _carregar),
              TcButton('Limpar filtros', onPressed: _limpar, color: kSecondary),
            ]),
          ],
        ),
        Panel(
          title: 'Resumo',
          children: [
            SpokenText('Ordens no filtro: ${_resumo['quantidade'] ?? 0}'),
            SpokenText('Faturamento (concluídas): ${formatBrl(_n(_resumo['faturamento']))}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
            SpokenText('Ticket médio: ${formatBrl(_n(_resumo['ticketMedio']))}'),
            SpokenText('Descontos dados: ${formatBrl(_n(_resumo['descontos']))}'),
            if (pagamentos.isNotEmpty) SpokenText('Por pagamento: $pagamentos'),
          ],
        ),
        Panel(
          title: 'Ordens de serviço',
          children: [
            FormActions(children: [
              TcButton('Exportar Excel (CSV)', icon: Icons.table_chart_outlined, onPressed: _exportarCsv),
              TcButton('Exportar PDF', icon: Icons.picture_as_pdf_outlined, onPressed: _exportarPdf, color: kSecondary),
            ]),
            const SizedBox(height: 12),
            SortableTable(
              columns: [
                TCol('ID', (o) => '${o['id']}'),
                TCol('Data', (o) => '${o['dataAbertura'] ?? ''}', cell: (_, o) => Text(_data(o['dataAbertura']))),
                TCol('Cliente', (o) => '${o['clienteNome'] ?? ''}'),
                TCol('Título', (o) => '${o['titulo'] ?? ''}'),
                TCol('Itens', (o) => '${o['itens'] ?? ''}'),
                TCol('Vendedor', (o) => '${o['vendedor'] ?? '-'}'),
                TCol('Status', (o) => '${o['status'] ?? ''}'),
                TCol('Pagamento', (o) => '${o['formaPagamento'] ?? '-'}'),
                TCol('Desconto', (o) => '${o['desconto'] ?? 0}', cell: (_, o) => Text(formatBrl(_n(o['desconto'])))),
                TCol('Total', (o) => '${o['total'] ?? 0}', cell: (_, o) => Text(formatBrl(_n(o['total'])))),
              ],
              rows: _itens,
            ),
          ],
        ),
      ],
    );
  }
}
