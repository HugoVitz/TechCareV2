import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/data_service.dart';
import '../widgets/reload_on_sync.dart';
import '../widgets/ui.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> with ReloadOnSync {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _cpf = TextEditingController();
  String? _etnia;
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
    _email.dispose();
    _telefone.dispose();
    _cpf.dispose();
    super.dispose();
  }

  @override
  Future<void> reload() async {
    try {
      final r = await context.read<DataService>().list('clientes');
      if (mounted) setState(() => _items = r.items);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  void _limpar() {
    _form.currentState?.reset();
    _nome.clear();
    _email.clear();
    _telefone.clear();
    _cpf.clear();
    setState(() {
      _etnia = null;
      _id = 0;
    });
  }

  void _editar(Map<String, dynamic> c) {
    setState(() {
      _id = c['id'] as int;
      _nome.text = '${c['nome'] ?? ''}';
      _email.text = '${c['email'] ?? ''}';
      _telefone.text = '${c['telefone'] ?? ''}';
      _cpf.text = '${c['cpf'] ?? ''}';
      final e = c['etnia'] as String?;
      _etnia = AppConfig.etnias.contains(e) ? e : null;
    });
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    try {
      final r = await context.read<DataService>().save('clientes', {
        'id': _id,
        'nome': _nome.text.trim(),
        'email': _email.text.trim(),
        'telefone': _telefone.text.trim(),
        'cpf': _cpf.text.trim(),
        'etnia': _etnia,
      });
      if (!mounted) return;
      showMessage(context, r.queued ? 'Sem conexão: salvo no aparelho e será enviado depois.' : 'Cliente salvo.');
      _limpar();
      reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _excluir(Map<String, dynamic> c) async {
    if (!await confirmDialog(context, 'Deseja realmente excluir este cliente?')) return;
    if (!mounted) return;
    try {
      await context.read<DataService>().delete('clientes', c['id'] as int);
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
      title: 'Clientes',
      onRefresh: reload,
      children: [
        Form(
          key: _form,
          child: Panel(
            title: 'Novo Cliente',
            children: [
              LabeledField(label: 'Nome', controller: _nome, hint: 'Digite o nome', required: true),
              LabeledField(
                label: 'E-mail',
                controller: _email,
                hint: 'Digite o e-mail',
                keyboard: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Preencha este campo.';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'E-mail inválido.';
                },
              ),
              LabeledField(
                  label: 'Telefone',
                  controller: _telefone,
                  hint: 'Digite o telefone',
                  keyboard: TextInputType.phone,
                  required: true),
              LabeledField(
                  label: 'CPF',
                  controller: _cpf,
                  hint: 'Digite o CPF',
                  keyboard: TextInputType.number,
                  required: true),
              LabeledDropdown<String?>(
                label: 'Etnia / cor (opcional)',
                value: _etnia,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Não informada')),
                  for (final e in AppConfig.etnias) DropdownMenuItem<String?>(value: e, child: Text(e)),
                ],
                onChanged: (v) => setState(() => _etnia = v),
              ),
              FormActions(children: [
                TcButton('Salvar', onPressed: _salvar),
                TcButton('Limpar', onPressed: _limpar, color: kSecondary),
              ]),
            ],
          ),
        ),
        Panel(
          title: 'Lista de Clientes',
          subtitle: 'Veja abaixo os clientes já cadastrados no sistema.',
          children: [
            SortableTable(
              columns: [
                TCol('ID', (c) => (c['id'] as int) < 0 ? 'pendente' : '${c['id']}'),
                TCol('Nome', (c) => '${c['nome'] ?? ''}'),
                TCol('E-mail', (c) => '${c['email'] ?? ''}'),
                TCol('Telefone', (c) => '${c['telefone'] ?? ''}'),
                TCol('CPF', (c) => '${c['cpf'] ?? ''}'),
              ],
              rows: _items,
              actions: (_, c) => RowActions(onEdit: () => _editar(c), onDelete: () => _excluir(c)),
            ),
          ],
        ),
      ],
    );
  }
}
