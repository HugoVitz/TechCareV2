import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/data_service.dart';
import '../widgets/ui.dart';

class _Anexo {
  _Anexo(this.nome, this.bytes);
  final String nome;
  final Uint8List bytes;
}

class _CartItem {
  _CartItem({required this.produto, required this.id, required this.nome, required this.qtd, required this.valor});
  final bool produto;
  final int id;
  final String nome;
  int qtd;
  final double valor;
  double get subtotal => qtd * valor;
}

/// Ordens de Serviço: igual à página do site. Carrinho (produtos + serviços), desconto,
/// forma de pagamento (Pix, Cartão, Dinheiro), gravação no servidor, histórico e PDF.
class OrdensScreen extends StatefulWidget {
  const OrdensScreen({super.key});

  @override
  State<OrdensScreen> createState() => _OrdensScreenState();
}

class _OrdensScreenState extends State<OrdensScreen> {
  final _form = GlobalKey<FormState>();
  final _status = TextEditingController(text: 'Aberta');
  final _garantia = TextEditingController();
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();

  int? _clienteId;
  int? _profissionalId;
  DateTime? _abertura = DateTime.now();
  DateTime? _prevista;
  DateTime? _conclusao;
  final List<_CartItem> _carrinho = [];
  final _cartQtd = TextEditingController(text: '1');
  final _desconto = TextEditingController();
  String? _catalogSel; // 'p:ID' ou 's:ID'
  String _descTipo = 'R\$';
  String _forma = '';
  bool _salvando = false;
  final List<_Anexo> _anexos = [];

  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _profissionais = [];
  List<Map<String, dynamic>> _servicos = [];
  List<Map<String, dynamic>> _produtos = [];
  List<Map<String, dynamic>> _ordens = [];

  bool _ready = false;
  String _statusMsg = 'Carregando dados do sistema...';
  bool _statusOk = false;
  bool _previewVisivel = false;
  late String _numeroOS;

  static final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _numeroOS = 'OS #${Random().nextInt(10000).toString().padLeft(4, '0')}';
    _carregar();
  }

  @override
  void dispose() {
    _status.dispose();
    _garantia.dispose();
    _titulo.dispose();
    _descricao.dispose();
    _cartQtd.dispose();
    _desconto.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final data = context.read<DataService>();
    try {
      final c = await data.list('clientes');
      final p = await data.list('equipe');
      final s = await data.list('servicos');
      final pr = await data.list('produtos');
      final o = await data.list('ordens');
      if (!mounted) return;
      final faltando = <String>[
        if (c.items.isEmpty) 'cliente',
        if (p.items.isEmpty) 'atendente',
        if (s.items.isEmpty && pr.items.where((x) => x['ativo'] != false).isEmpty) 'produto ou serviço',
      ];
      setState(() {
        _clientes = c.items;
        _profissionais = p.items;
        _servicos = s.items;
        _produtos = pr.items.where((x) => x['ativo'] != false).toList();
        _ordens = o.items;
        _ready = faltando.isEmpty;
        _statusOk = faltando.isEmpty;
        _statusMsg = faltando.isEmpty
            ? 'Pronto para gerar a pré-visualização da ordem de serviço.'
            : 'Cadastre pelo menos um ${faltando.join(", ")} para gerar a ordem de serviço.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showMessage(context, 'Erro ao carregar dados da ordem de serviço.', error: true);
      setState(() {
        _ready = false;
        _statusOk = false;
        _statusMsg = 'Erro ao carregar dados do backend. ${e.message}';
      });
    }
  }

  Map<String, dynamic>? get _cliente {
    for (final c in _clientes) {
      if (c['id'] == _clienteId) return c;
    }
    return null;
  }

  Map<String, dynamic>? get _profissional {
    for (final p in _profissionais) {
      if (p['id'] == _profissionalId) return p;
    }
    return null;
  }

  double get _subtotal => _carrinho.fold(0.0, (a, i) => a + i.subtotal);

  double get _descontoValor {
    final bruto = _descTipo == '%'
        ? (double.tryParse(_desconto.text.trim().replaceAll(',', '.')) ?? 0)
        : parseBrl(_desconto.text);
    final v = bruto < 0 ? 0.0 : bruto;
    final calc = _descTipo == '%' ? _subtotal * min(v, 100) / 100 : v;
    return (min(calc, _subtotal) * 100).round() / 100;
  }

  double get _total => max(0, _subtotal - _descontoValor);

  int _estoqueDe(_CartItem i) {
    if (!i.produto) return 1 << 30;
    for (final p in _produtos) {
      if (p['id'] == i.id) return (p['estoque'] ?? 0) as int;
    }
    return 0;
  }

  void _adicionar() {
    final sel = _catalogSel;
    final qtd = int.tryParse(_cartQtd.text.trim()) ?? 0;
    if (sel == null) {
      showMessage(context, 'Selecione um produto ou serviço.', error: true);
      return;
    }
    if (qtd < 1) {
      showMessage(context, 'Informe uma quantidade válida (mínimo 1).', error: true);
      return;
    }
    final id = int.parse(sel.substring(2));
    final ehProduto = sel.startsWith('p:');
    final origem = (ehProduto ? _produtos : _servicos).firstWhere((x) => x['id'] == id);
    final novo = _CartItem(
      produto: ehProduto,
      id: id,
      nome: '${ehProduto ? origem['nome'] : (origem['titulo'] ?? 'Serviço $id')}',
      qtd: qtd,
      valor: ((ehProduto ? origem['preco'] : origem['valor']) ?? 0).toDouble(),
    );
    final existente = _carrinho.where((i) => i.produto == novo.produto && i.id == novo.id).toList();
    final total = (existente.isEmpty ? 0 : existente.first.qtd) + qtd;
    if (total > _estoqueDe(novo)) {
      showMessage(context, 'Estoque insuficiente de "${novo.nome}" (disponível: ${_estoqueDe(novo)}).', error: true);
      return;
    }
    setState(() {
      if (existente.isEmpty) {
        _carrinho.add(novo);
      } else {
        existente.first.qtd = total;
      }
      _catalogSel = null;
      _cartQtd.text = '1';
    });
  }

  void _alterarQtd(_CartItem i, int delta) {
    if (delta > 0 && i.qtd + delta > _estoqueDe(i)) {
      showMessage(context, 'Estoque insuficiente de "${i.nome}".', error: true);
      return;
    }
    setState(() {
      i.qtd += delta;
      if (i.qtd < 1) _carrinho.remove(i);
    });
  }

  String get _itensTexto => _carrinho
      .map((i) => '${i.qtd}x ${i.nome} (${i.produto ? 'produto' : 'serviço'}) - ${formatBrl(i.valor)} = ${formatBrl(i.subtotal)}')
      .join('\n');

  bool _validar() {
    String? erro;
    if (_clienteId == null) {
      erro = 'Selecione um cliente.';
    } else if (_profissionalId == null) {
      erro = 'Selecione um atendente.';
    } else if (_titulo.text.trim().isEmpty) {
      erro = 'Informe o título da ordem de serviço.';
    } else if (_descricao.text.trim().isEmpty) {
      erro = 'Informe a descrição do serviço.';
    } else if (_abertura == null) {
      erro = 'Informe a data de abertura.';
    } else if (_carrinho.isEmpty) {
      erro = 'Adicione pelo menos um produto ou serviço ao carrinho.';
    }
    if (erro != null) {
      showMessage(context, erro, error: true);
      return false;
    }
    return true;
  }

  void _alternarPreview() {
    if (_previewVisivel) {
      setState(() {
        _previewVisivel = false;
        _statusOk = true;
        _statusMsg = 'Pré-visualização ocultada.';
      });
      return;
    }
    if (!_ready) {
      showMessage(context, 'Aguarde o carregamento dos dados.', error: true);
      return;
    }
    if (!_validar()) return;
    setState(() {
      _previewVisivel = true;
      _statusOk = true;
      _statusMsg = 'Pré-visualização atualizada com sucesso.';
    });
  }

  void _limpar() {
    _form.currentState?.reset();
    setState(() {
      _clienteId = null;
      _profissionalId = null;
      _status.text = 'Aberta';
      _garantia.clear();
      _titulo.clear();
      _descricao.clear();
      _abertura = DateTime.now();
      _prevista = null;
      _conclusao = null;
      _carrinho.clear();
      _desconto.clear();
      _descTipo = 'R\$';
      _forma = '';
      _catalogSel = null;
      _anexos.clear();
      _statusOk = true;
      _statusMsg = 'Formulário limpo. Pronto para gerar uma nova pré-visualização.';
    });
  }

  Future<void> _escolherImagens() async {
    try {
      final files = await ImagePicker().pickMultiImage();
      final novos = <_Anexo>[];
      for (final f in files) {
        novos.add(_Anexo(f.name, await f.readAsBytes()));
      }
      if (files.isNotEmpty && mounted) {
        setState(() {
          _anexos
            ..clear()
            ..addAll(novos);
        });
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível abrir as imagens.', error: true);
    }
  }

  // ------------------------------------------------------------------ pagamento e gravação

  Future<void> _finalizar() async {
    if (!_ready) {
      showMessage(context, 'Aguarde o carregamento dos dados.', error: true);
      return;
    }
    if (!_validar()) return;

    final forma = await showDialog<String>(
      context: context,
      builder: (_) => _PagamentoDialog(total: _total, inicial: _forma),
    );
    if (forma == null || !mounted) return;
    setState(() {
      _forma = forma;
      _salvando = true;
    });

    final body = <String, dynamic>{
      'clienteId': _clienteId,
      'profissionalId': _profissionalId,
      'titulo': _titulo.text.trim(),
      'descricao': _descricao.text.trim(),
      'garantia': _garantia.text.trim().isEmpty ? null : _garantia.text.trim(),
      'dataAbertura': _abertura!.toIso8601String(),
      'dataPrevista': _prevista?.toIso8601String(),
      'dataConclusao': _conclusao?.toIso8601String(),
      'status': _status.text.trim().isEmpty ? 'Aberta' : _status.text.trim(),
      'desconto': _descontoValor,
      'formaPagamento': forma,
      'itens': [
        for (final i in _carrinho.where((x) => !x.produto)) {'servicoId': i.id, 'quantidade': i.qtd}
      ],
      'produtos': [
        for (final i in _carrinho.where((x) => x.produto)) {'produtoId': i.id, 'quantidade': i.qtd}
      ],
      'imagens': [
        for (final a in _anexos) {'nomeArquivo': a.nome, 'conteudoBase64': base64Encode(a.bytes)}
      ],
    };

    try {
      final os = await context.read<DataService>().createOrderOnline(body);
      if (!mounted) return;
      final total = _total;
      showMessage(context, 'Ordem de serviço #${os['id']} salva! Total: ${formatBrl(total)} ($forma).');
      _limpar();
      await _carregar();
    } on NetworkException {
      if (mounted) {
        showMessage(context, 'Salvar a OS exige conexão com o servidor (confere estoque e preços).', error: true);
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _mudarStatus(Map<String, dynamic> o, String novo) async {
    try {
      await context.read<DataService>().updateOrderStatus(o['id'] as int, novo);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
    if (mounted) _carregar();
  }

  Future<void> _excluirOrdem(Map<String, dynamic> o) async {
    if (!await confirmDialog(context, 'Deseja realmente excluir esta ordem de serviço? Os produtos voltam ao estoque.')) {
      return;
    }
    if (!mounted) return;
    try {
      await context.read<DataService>().delete('ordens', o['id'] as int);
    } on NetworkException {
      if (mounted) showMessage(context, 'Excluir exige conexão com o servidor.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
    if (mounted) _carregar();
  }

  // ------------------------------------------------------------------ PDF

  Future<void> _exportarPdf() async {
    if (!_validar()) return;
    setState(() {
      _previewVisivel = true;
    });

    final c = _cliente;
    final p = _profissional;
    final logo = pw.MemoryImage((await rootBundle.load('assets/LogoTC.png')).buffer.asUint8List());
    final servicos = _itensTexto;

    String d(DateTime? v) => v == null ? '--' : _fmt.format(v);

    pw.Widget caixa(String rotulo, List<String> linhas) => pw.Container(
          width: 240,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(rotulo, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 3),
            for (final l in linhas) pw.Text(l, style: const pw.TextStyle(fontSize: 11)),
          ]),
        );

    final imagens = <pw.Widget>[];
    for (final a in _anexos) {
      try {
        imagens.add(pw.Container(
          width: 110,
          height: 110,
          child: pw.Image(pw.MemoryImage(a.bytes), fit: pw.BoxFit.cover),
        ));
      } catch (_) {
        // formato que o PDF não aceita: ignora a imagem
      }
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.SizedBox(width: 80, child: pw.Image(logo)),
          pw.Text(_numeroOS, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: PdfColors.blue100,
              child: pw.Text(_status.text.trim().isEmpty ? 'Status da OS' : _status.text.trim()),
            ),
            pw.SizedBox(height: 4),
            pw.Text('TechCare Soluções', style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text('suporte@techcare.com', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ]),
        ]),
        pw.Divider(),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_titulo.text.trim(), style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(_descricao.text.trim(), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Datas', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text('Data de Abertura', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text(d(_abertura), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Data Prevista', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text(d(_prevista), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Data de Conclusão', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text(d(_conclusao), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ]),
        ]),
        pw.Divider(),
        pw.Wrap(spacing: 10, runSpacing: 10, children: [
          caixa('Atendente responsável', ['${p?['nome'] ?? 'Nome do atendente'}']),
          caixa('Dados do cliente', [
            '${c?['nome'] ?? 'Nome do cliente'}',
            '${c?['email'] ?? 'E-mail do cliente'}',
            '${c?['telefone'] ?? 'Telefone do cliente'}',
            '${c?['cpf'] ?? 'CPF do cliente'}',
          ]),
          caixa('Garantia', [_garantia.text.trim().isEmpty ? 'Sem garantia informada' : _garantia.text.trim()]),
          caixa('Itens do carrinho', servicos.isEmpty ? ['Nenhum item no carrinho'] : servicos.split('\n')),
          caixa('Pagamento', [
            _forma.isEmpty ? 'Forma de pagamento não informada' : _forma,
            'Subtotal: ${formatBrl(_subtotal)}',
            'Desconto: - ${formatBrl(_descontoValor)}',
            'Total: ${formatBrl(_total)}',
          ]),
        ]),
        pw.Divider(),
        pw.Text('Imagens anexadas', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        pw.Wrap(spacing: 8, runSpacing: 8, children: imagens),
        pw.SizedBox(height: 60),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          for (final t in ['Assinatura do cliente', 'Responsável técnico'])
            pw.Column(children: [
              pw.Container(width: 190, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Text(t, style: const pw.TextStyle(fontSize: 10)),
            ]),
        ]),
      ],
    ));

    try {
      await Printing.sharePdf(bytes: await doc.save(), filename: 'OrdemServico.pdf');
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível gerar o PDF neste dispositivo.', error: true);
    }
  }

  // ------------------------------------------------------------------ tela

  @override
  Widget build(BuildContext context) {
    return ScreenBody(
      title: 'Ordem de Serviço',
      subtitle: 'Preencha os dados da ordem de serviço, visualize o documento e exporte em PDF.',
      children: [
        Form(
          key: _form,
          child: Panel(
            title: 'Dados da Ordem de Serviço',
            children: [
              LabeledDropdown<int>(
                label: 'Cliente',
                value: _clienteId,
                required: true,
                items: [
                  for (final c in _clientes)
                    DropdownMenuItem<int>(value: c['id'] as int, child: Text('${c['nome']}')),
                ],
                onChanged: (v) => setState(() => _clienteId = v),
              ),
              LabeledDropdown<int>(
                label: 'Atendente responsável',
                value: _profissionalId,
                required: true,
                items: [
                  for (final p in _profissionais)
                    DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['nome']}')),
                ],
                onChanged: (v) => setState(() => _profissionalId = v),
              ),
              LabeledField(
                  label: 'Status da OS', controller: _status, hint: 'Exemplo: Aberta', required: true, onChanged: (_) => setState(() {})),
              LabeledField(
                  label: 'Garantia', controller: _garantia, hint: 'Exemplo: 90 dias', onChanged: (_) => setState(() {})),
              LabeledField(
                  label: 'Título da OS',
                  controller: _titulo,
                  hint: 'Exemplo: Troca de tela',
                  required: true,
                  onChanged: (_) => setState(() {})),
              DateTimeField(
                  label: 'Data de abertura',
                  value: _abertura,
                  required: true,
                  onChanged: (v) => setState(() => _abertura = v)),
              DateTimeField(
                  label: 'Data prevista', value: _prevista, onChanged: (v) => setState(() => _prevista = v)),
              DateTimeField(
                  label: 'Data de conclusão', value: _conclusao, onChanged: (v) => setState(() => _conclusao = v)),
              LabeledField(
                  label: 'Descrição do serviço',
                  controller: _descricao,
                  hint: 'Descreva o serviço',
                  maxLines: 4,
                  required: true,
                  onChanged: (_) => setState(() {})),
              const Divider(),
              const SizedBox(height: 8),
              const SpokenText('Carrinho: adicionar produto ou serviço', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _catalogSel,
                isExpanded: true,
                hint: const Text('Selecione um produto ou serviço'),
                items: [
                  for (final p in _produtos)
                    DropdownMenuItem(
                      value: 'p:${p['id']}',
                      child: Text('Produto: ${p['nome']} - ${formatBrl((p['preco'] ?? 0) as num)} (estoque ${p['estoque']})',
                          overflow: TextOverflow.ellipsis),
                    ),
                  for (final sv in _servicos)
                    DropdownMenuItem(
                      value: 's:${sv['id']}',
                      child: Text('Serviço: ${sv['titulo'] ?? sv['id']} - ${formatBrl((sv['valor'] ?? 0) as num)}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _catalogSel = v),
              ),
              const SizedBox(height: 8),
              LabeledField(label: 'Quantidade', controller: _cartQtd, hint: '1', keyboard: TextInputType.number),
              Align(
                alignment: Alignment.centerLeft,
                child: TcButton('Adicionar ao carrinho', icon: Icons.add_shopping_cart, onPressed: _adicionar),
              ),
              const SizedBox(height: 10),
              if (_carrinho.isEmpty)
                const Text('Carrinho vazio. Adicione produtos ou serviços acima.')
              else
                for (final i in _carrinho)
                  Card(
                    child: ListTile(
                      title: Text('${i.nome} (${i.produto ? 'produto' : 'serviço'})'),
                      subtitle: Text('${formatBrl(i.valor)} cada  •  subtotal ${formatBrl(i.subtotal)}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'Diminuir', icon: const Icon(Icons.remove_circle_outline), onPressed: () => _alterarQtd(i, -1)),
                        Text('${i.qtd}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                            tooltip: 'Aumentar', icon: const Icon(Icons.add_circle_outline), onPressed: () => _alterarQtd(i, 1)),
                        IconButton(
                            tooltip: 'Remover',
                            icon: const Icon(Icons.delete_outline, color: kDanger),
                            onPressed: () => setState(() => _carrinho.remove(i))),
                      ]),
                    ),
                  ),
              const SizedBox(height: 10),
              LabeledDropdown<String>(
                label: 'Tipo de desconto',
                value: _descTipo,
                items: const [
                  DropdownMenuItem(value: 'R\$', child: Text('R\$ (reais)')),
                  DropdownMenuItem(value: '%', child: Text('% (porcentagem)')),
                ],
                onChanged: (v) => setState(() {
                  _descTipo = v ?? 'R\$';
                  _desconto.clear();
                }),
              ),
              LabeledField(
                label: 'Desconto',
                controller: _desconto,
                hint: _descTipo == '%' ? '0' : 'R\$ 0,00',
                keyboard: TextInputType.number,
                formatters: _descTipo == '%' ? const [] : [BrlInputFormatter()],
                onChanged: (_) => setState(() {}),
              ),
              SpokenText('Subtotal: ${formatBrl(_subtotal)}'),
              SpokenText('Desconto: - ${formatBrl(_descontoValor)}'),
              SpokenText('Total: ${formatBrl(_total)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 14),
              const SpokenText('Imagens anexadas', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TcButton('Escolher imagens', icon: Icons.image_outlined, color: kSecondary, onPressed: _escolherImagens),
              ),
              if (_anexos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in _anexos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(a.bytes, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                ]),
              ],
              const SizedBox(height: 16),
              FormActions(children: [
                TcButton(_salvando ? 'Salvando...' : 'Finalizar e salvar OS', onPressed: _salvando ? null : _finalizar),
                TcButton('Gerar pré-visualização', onPressed: _alternarPreview, color: kSecondary),
                TcButton('Exportar PDF', onPressed: _exportarPdf, color: kSecondary),
                TcButton('Limpar', onPressed: _limpar, color: kSecondary),
              ]),
              if (_statusMsg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_statusMsg,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: _statusOk ? const Color(0xFF16A34A) : kDanger)),
              ],
            ],
          ),
        ),
        if (_previewVisivel) _preview(context),
        Panel(
          title: 'Ordens de serviço registradas',
          subtitle: 'Histórico das ordens salvas, com valores e forma de pagamento.',
          children: [
            SortableTable(
              columns: [
                TCol('ID', (o) => (o['id'] as int) < 0 ? 'pendente' : '${o['id']}'),
                TCol('Cliente', (o) => '${o['clienteNome'] ?? ''}'),
                TCol('Título', (o) => '${o['titulo'] ?? ''}'),
                TCol('Data', (o) => '${o['dataAbertura'] ?? ''}',
                    cell: (_, o) {
                      final d = DateTime.tryParse('${o['dataAbertura'] ?? ''}');
                      return Text(d == null ? '--' : DateFormat('dd/MM/yyyy').format(d));
                    }),
                TCol('Status', (o) => '${o['status'] ?? ''}',
                    cell: (_, o) => DropdownButton<String>(
                          value: ['Aberta', 'Em andamento', 'Concluída', 'Cancelada'].contains(o['status']) ? '${o['status']}' : null,
                          hint: Text('${o['status'] ?? ''}'),
                          items: [
                            for (final st in ['Aberta', 'Em andamento', 'Concluída', 'Cancelada'])
                              DropdownMenuItem(value: st, child: Text(st)),
                          ],
                          onChanged: (v) => v == null ? null : _mudarStatus(o, v),
                        )),
                TCol('Pagamento', (o) => '${o['formaPagamento'] ?? '-'}'),
                TCol('Total', (o) => '${o['valorTotal'] ?? 0}', cell: (_, o) => Text(formatBrl((o['valorTotal'] ?? 0) as num))),
              ],
              rows: _ordens,
              actions: (_, o) => RowActions(onDelete: () => _excluirOrdem(o)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final c = _cliente;
    final p = _profissional;
    final muted = TextStyle(color: mutedText(context), fontSize: 13);
    final servicos = _itensTexto;

    Widget caixa(String rotulo, List<Widget> filhos) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: lineColor(context)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SpokenText(rotulo, style: muted), const SizedBox(height: 4), ...filhos],
          ),
        );

    String d(DateTime? v) => v == null ? '--' : _fmt.format(v);
    final status = _status.text.trim().isEmpty ? 'Status da OS' : _status.text.trim();

    return Panel(
      title: 'Pré-visualização da Ordem de Serviço',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: lineColor(context)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Image.asset('assets/LogoTC.png', height: 56),
                  SpokenText(_numeroOS, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(status),
                      ),
                      const SizedBox(height: 4),
                      const SpokenText('TechCare Soluções', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('suporte@techcare.com', style: muted),
                    ],
                  ),
                ],
              ),
              const Divider(height: 28),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 12,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SpokenText(_titulo.text.trim().isEmpty ? 'Título da ordem de serviço' : _titulo.text.trim(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SpokenText(_descricao.text.trim().isEmpty ? 'Descrição do serviço' : _descricao.text.trim(),
                            style: muted),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Datas', style: muted),
                      Text('Data de Abertura', style: muted),
                      Text(d(_abertura), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Data Prevista', style: muted),
                      Text(d(_prevista), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Data de Conclusão', style: muted),
                      Text(d(_conclusao), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 28),
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 640 ? 2 : 1;
                final w = (box.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(
                    width: w,
                    child: caixa('Atendente responsável', [
                      SpokenText('${p?['nome'] ?? 'Nome do atendente'}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  SizedBox(
                    width: w,
                    child: caixa('Dados do cliente', [
                      SpokenText('${c?['nome'] ?? 'Nome do cliente'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${c?['email'] ?? 'E-mail do cliente'}', style: muted),
                      Text('${c?['telefone'] ?? 'Telefone do cliente'}', style: muted),
                      Text('${c?['cpf'] ?? 'CPF do cliente'}', style: muted),
                    ]),
                  ),
                  SizedBox(
                    width: w,
                    child: caixa('Garantia', [
                      SpokenText(_garantia.text.trim().isEmpty ? 'Sem garantia informada' : _garantia.text.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  SizedBox(
                    width: w,
                    child: caixa('Itens do carrinho', [
                      SpokenText(servicos.isEmpty ? 'Nenhum item no carrinho' : servicos,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  SizedBox(
                    width: w,
                    child: caixa('Pagamento', [
                      SpokenText(_forma.isEmpty ? 'Forma de pagamento não informada' : _forma,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Subtotal: ${formatBrl(_subtotal)}', style: muted),
                      Text('Desconto: - ${formatBrl(_descontoValor)}', style: muted),
                      SpokenText('Total: ${formatBrl(_total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]);
              }),
              const Divider(height: 28),
              Text('Imagens anexadas', style: muted),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final a in _anexos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(a.bytes, width: 120, height: 120, fit: BoxFit.cover),
                  ),
              ]),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final t in ['Assinatura do cliente', 'Responsável técnico'])
                    Column(children: [
                      Container(width: 150, height: 1, color: mutedText(context)),
                      const SizedBox(height: 4),
                      Text(t, style: muted),
                    ]),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// Pergunta a forma de pagamento (Pix, Cartão, Dinheiro); no dinheiro calcula o troco.
class _PagamentoDialog extends StatefulWidget {
  const _PagamentoDialog({required this.total, required this.inicial});
  final double total;
  final String inicial;

  @override
  State<_PagamentoDialog> createState() => _PagamentoDialogState();
}

class _PagamentoDialogState extends State<_PagamentoDialog> {
  late String _forma = widget.inicial;
  final _recebido = TextEditingController();
  String _erro = '';

  @override
  void dispose() {
    _recebido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recebido = parseBrl(_recebido.text);
    final troco = recebido <= 0
        ? formatBrl(0)
        : recebido < widget.total
            ? 'faltam ${formatBrl(widget.total - recebido)}'
            : formatBrl(recebido - widget.total);

    return AlertDialog(
      title: const Text('Qual a forma de pagamento?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total a pagar: ${formatBrl(widget.total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final f in ['Pix', 'Cartão', 'Dinheiro'])
                ChoiceChip(
                  label: Text(f),
                  selected: _forma == f,
                  onSelected: (_) => setState(() {
                    _forma = f;
                    _erro = '';
                  }),
                ),
            ]),
            if (_forma == 'Dinheiro') ...[
              const SizedBox(height: 12),
              LabeledField(
                label: 'Valor recebido (opcional)',
                controller: _recebido,
                hint: 'R\$ 0,00',
                keyboard: TextInputType.number,
                formatters: [BrlInputFormatter()],
                onChanged: (_) => setState(() {}),
              ),
              Text('Troco: $troco'),
            ],
            if (_erro.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_erro, style: const TextStyle(color: kDanger))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_forma.isEmpty) {
              setState(() => _erro = 'Escolha a forma de pagamento (Pix, Cartão ou Dinheiro).');
              return;
            }
            if (_forma == 'Dinheiro' && recebido > 0 && recebido < widget.total) {
              setState(() => _erro = 'O valor recebido é menor que o total.');
              return;
            }
            Navigator.pop(context, _forma);
          },
          child: const Text('Confirmar e salvar'),
        ),
      ],
    );
  }
}
