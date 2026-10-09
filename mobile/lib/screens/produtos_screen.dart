import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/data_service.dart';
import '../widgets/reload_on_sync.dart';
import '../widgets/ui.dart';

/// Cadastro de Produtos e estoque (somente Administrador).
class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> with ReloadOnSync {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _preco = TextEditingController();
  final _estoque = TextEditingController(text: '0');
  bool _ativo = true;
  int _id = 0;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _nome.dispose();
    _preco.dispose();
    _estoque.dispose();
    super.dispose();
  }

  @override
  Future<void> reload() async {
    try {
      final r = await context.read<DataService>().list('produtos');
      if (mounted) setState(() => _items = r.items);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, 'Erro ao carregar produtos. ${e.message}', error: true);
    }
  }

  void _limpar() {
    _form.currentState?.reset();
    _nome.clear();
    _preco.clear();
    _estoque.text = '0';
    setState(() {
      _id = 0;
      _ativo = true;
    });
  }

  void _editar(Map<String, dynamic> s) {
    setState(() {
      _id = s['id'] as int;
      _nome.text = '${s['nome'] ?? ''}';
      _preco.text = formatBrl(((s['preco'] ?? 0) as num));
      _estoque.text = '${s['estoque'] ?? 0}';
      _ativo = s['ativo'] != false;
    });
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    try {
      final r = await context.read<DataService>().save('produtos', {
        'id': _id,
        'nome': _nome.text.trim(),
        'preco': parseBrl(_preco.text),
        'estoque': int.tryParse(_estoque.text.trim()) ?? 0,
        'ativo': _ativo,
      });
      if (!mounted) return;
      showMessage(context, r.queued ? 'Sem conexão: salvo no aparelho e será enviado depois.' : 'Produto salvo.');
      _limpar();
      reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _excluir(Map<String, dynamic> s) async {
    if (!await confirmDialog(context, 'Deseja realmente excluir este produto?')) return;
    if (!mounted) return;
    try {
      await context.read<DataService>().delete('produtos', s['id'] as int);
      if (mounted) reload();
    } on NetworkException {
      if (mounted) showMessage(context, 'Excluir exige conexão com o servidor.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    watchSync(context);
    return ScreenBody(
      title: 'Produtos e estoque',
      subtitle: 'Cadastre os produtos vendidos no carrinho e controle o estoque.',
      onRefresh: reload,
      children: [
        Form(
          key: _form,
          child: Panel(
            title: _id == 0 ? 'Novo Produto' : 'Editar Produto',
            subtitle: 'Preencha as informações abaixo para cadastrar um produto.',
            children: [
              LabeledField(label: 'Nome do produto', controller: _nome, hint: 'Ex.: Tela iPhone 11', required: true),
              LabeledField(
                label: 'Preço',
                controller: _preco,
                hint: 'R\$ 0,00',
                keyboard: TextInputType.number,
                formatters: [BrlInputFormatter()],
                required: true,
              ),
              LabeledField(
                label: 'Estoque (unidades)',
                controller: _estoque,
                hint: '0',
                keyboard: TextInputType.number,
                required: true,
              ),
              LabeledDropdown<bool>(
                label: 'Disponível para venda',
                value: _ativo,
                items: const [
                  DropdownMenuItem(value: true, child: Text('Sim')),
                  DropdownMenuItem(value: false, child: Text('Não (oculto para atendentes)')),
                ],
                onChanged: (v) => setState(() => _ativo = v ?? true),
              ),
              FormActions(children: [
                TcButton('Salvar', onPressed: _salvar),
                TcButton('Limpar', onPressed: _limpar, color: kSecondary),
              ]),
            ],
          ),
        ),
        Panel(
          title: 'Produtos cadastrados',
          subtitle: 'Estoque baixo (5 ou menos) aparece em destaque.',
          children: [
            SortableTable(
              columns: [
                TCol('ID', (s) => (s['id'] as int) < 0 ? 'pendente' : '${s['id']}'),
                TCol('Nome', (s) => '${s['nome'] ?? ''}'),
                TCol('Preço', (s) => '${s['preco'] ?? 0}', cell: (_, s) => Text(formatBrl((s['preco'] ?? 0) as num))),
                TCol('Estoque', (s) => '${s['estoque'] ?? 0}',
                    cell: (_, s) => Text('${s['estoque'] ?? 0}',
                        style: TextStyle(
                            color: ((s['estoque'] ?? 0) as num) <= 5 ? kDanger : null,
                            fontWeight: ((s['estoque'] ?? 0) as num) <= 5 ? FontWeight.bold : null))),
                TCol('Situação', (s) => s['ativo'] == false ? 'Inativo' : 'Ativo'),
              ],
              rows: _items,
              actions: (_, s) => RowActions(onEdit: () => _editar(s), onDelete: () => _excluir(s)),
            ),
          ],
        ),
      ],
    );
  }
}
