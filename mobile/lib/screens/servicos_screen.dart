import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/data_service.dart';
import '../widgets/reload_on_sync.dart';
import '../widgets/ui.dart';

/// Cadastro de Serviços (somente Administrador).
class ServicosScreen extends StatefulWidget {
  const ServicosScreen({super.key});

  @override
  State<ServicosScreen> createState() => _ServicosScreenState();
}

class _ServicosScreenState extends State<ServicosScreen> with ReloadOnSync {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  final _valor = TextEditingController();
  int _id = 0;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _valor.dispose();
    super.dispose();
  }

  @override
  Future<void> reload() async {
    try {
      final r = await context.read<DataService>().list('servicos');
      if (mounted) setState(() => _items = r.items);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, 'Erro ao carregar serviços. ${e.message}', error: true);
    }
  }

  void _limpar() {
    _form.currentState?.reset();
    _titulo.clear();
    _descricao.clear();
    _valor.clear();
    setState(() => _id = 0);
  }

  void _editar(Map<String, dynamic> s) {
    setState(() {
      _id = s['id'] as int;
      _titulo.text = '${s['titulo'] ?? ''}';
      _descricao.text = '${s['descricao'] ?? ''}';
      _valor.text = formatBrl(((s['valor'] ?? 0) as num));
    });
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    try {
      final r = await context.read<DataService>().save('servicos', {
        'id': _id,
        'titulo': _titulo.text.trim(),
        'descricao': _descricao.text.trim(),
        'valor': parseBrl(_valor.text),
      });
      if (!mounted) return;
      showMessage(context, r.queued ? 'Sem conexão: salvo no aparelho e será enviado depois.' : 'Serviço salvo.');
      _limpar();
      reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _excluir(Map<String, dynamic> s) async {
    if (!await confirmDialog(context, 'Deseja realmente excluir este serviço?')) return;
    if (!mounted) return;
    try {
      await context.read<DataService>().delete('servicos', s['id'] as int);
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
      title: 'Cadastro de Serviços',
      subtitle: 'Cadastre, consulte e remova serviços usados nas ordens de serviço.',
      onRefresh: reload,
      children: [
        Form(
          key: _form,
          child: Panel(
            title: 'Novo Serviço',
            subtitle: 'Preencha as informações abaixo para cadastrar um serviço.',
            children: [
              LabeledField(
                  label: 'Título do serviço',
                  controller: _titulo,
                  hint: 'Digite o título do serviço',
                  required: true),
              LabeledField(
                  label: 'Descrição do serviço',
                  controller: _descricao,
                  hint: 'Digite a descrição do serviço',
                  maxLines: 4,
                  required: true),
              LabeledField(
                label: 'Valor do serviço',
                controller: _valor,
                hint: 'R\$ 0,00',
                keyboard: TextInputType.number,
                formatters: [BrlInputFormatter()],
                required: true,
              ),
              FormActions(children: [
                TcButton('Cadastrar', onPressed: _salvar),
                TcButton('Limpar', onPressed: _limpar, color: kSecondary),
              ]),
            ],
          ),
        ),
        Panel(
          title: 'Serviços cadastrados',
          subtitle: 'Veja abaixo os serviços já cadastrados no sistema.',
          children: [
            SortableTable(
              columns: [
                TCol('ID', (s) => (s['id'] as int) < 0 ? 'pendente' : '${s['id']}'),
                TCol('Título', (s) => '${s['titulo'] ?? ''}'),
                TCol('Descrição', (s) => '${s['descricao'] ?? ''}'),
                TCol('Valor', (s) => '${s['valor'] ?? 0}', cell: (_, s) => Text(formatBrl((s['valor'] ?? 0) as num))),
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
