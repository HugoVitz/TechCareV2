import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/data_service.dart';
import '../widgets/reload_on_sync.dart';
import '../widgets/ui.dart';

class AgendamentosScreen extends StatefulWidget {
  const AgendamentosScreen({super.key});

  @override
  State<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

class _AgendamentosScreenState extends State<AgendamentosScreen> with ReloadOnSync {
  final _form = GlobalKey<FormState>();
  int _id = 0;
  int? _clienteId;
  int? _profissionalId;
  DateTime? _dataHora;
  String? _status;

  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _profissionais = [];
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> reload() async {
    final data = context.read<DataService>();
    try {
      final c = await data.list('clientes');
      final p = await data.list('equipe');
      final a = await data.list('agendamentos');
      if (!mounted) return;
      setState(() {
        _clientes = c.items;
        _profissionais = p.items;
        _items = a.items;
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  void _limpar() {
    _form.currentState?.reset();
    setState(() {
      _id = 0;
      _clienteId = null;
      _profissionalId = null;
      _dataHora = null;
      _status = null;
    });
  }

  void _editar(Map<String, dynamic> a) {
    int? idPorNome(List<Map<String, dynamic>> lista, String? nome) {
      for (final x in lista) {
        if (x['nome'] == nome) return x['id'] as int;
      }
      return null;
    }

    setState(() {
      _id = a['id'] as int;
      _clienteId = idPorNome(_clientes, a['pacienteNome'] as String?);
      _profissionalId = idPorNome(_profissionais, a['profissionalNome'] as String?);
      _dataHora = DateTime.tryParse('${a['dataHora']}');
      _status = AppConfig.statusAgendamento.contains(a['status']) ? a['status'] as String : null;
    });
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final cliente = _clientes.firstWhere((c) => c['id'] == _clienteId, orElse: () => {});
    final prof = _profissionais.firstWhere((p) => p['id'] == _profissionalId, orElse: () => {});
    if (cliente.isEmpty) return showMessage(context, 'Selecione um cliente válido.', error: true);
    if (prof.isEmpty) return showMessage(context, 'Selecione um atendente válido.', error: true);

    try {
      final r = await context.read<DataService>().save('agendamentos', {
        'id': _id,
        'pacienteNome': cliente['nome'],
        'profissionalNome': prof['nome'],
        'dataHora': DateFormat("yyyy-MM-dd'T'HH:mm").format(_dataHora!),
        'status': _status,
      });
      if (!mounted) return;
      showMessage(context, r.queued ? 'Sem conexão: salvo no aparelho e será enviado depois.' : 'Agendamento salvo.');
      _limpar();
      reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _excluir(Map<String, dynamic> a) async {
    if (!await confirmDialog(context, 'Deseja realmente excluir este agendamento?')) return;
    if (!mounted) return;
    try {
      await context.read<DataService>().delete('agendamentos', a['id'] as int);
      if (mounted) reload();
    } on NetworkException {
      if (mounted) showMessage(context, 'Excluir exige conexão com o servidor.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  String _quando(dynamic iso) {
    final d = DateTime.tryParse('$iso');
    return d == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    watchSync(context);
    return ScreenBody(
      title: 'Agendamentos',
      onRefresh: reload,
      children: [
        Form(
          key: _form,
          child: Panel(
            title: 'Novo Agendamento',
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
                label: 'Atendente',
                value: _profissionalId,
                required: true,
                items: [
                  for (final p in _profissionais)
                    DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['nome']}')),
                ],
                onChanged: (v) => setState(() => _profissionalId = v),
              ),
              DateTimeField(
                label: 'Data e horário',
                value: _dataHora,
                required: true,
                onChanged: (v) => setState(() => _dataHora = v),
              ),
              LabeledDropdown<String>(
                label: 'Status do atendimento',
                value: _status,
                required: true,
                items: [
                  for (final s in AppConfig.statusAgendamento) DropdownMenuItem<String>(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
              FormActions(children: [
                TcButton('Salvar', onPressed: _salvar),
                TcButton('Limpar', onPressed: _limpar, color: kSecondary),
              ]),
            ],
          ),
        ),
        Panel(
          title: 'Lista de Agendamentos',
          subtitle: 'Veja abaixo os agendamentos já cadastrados no sistema.',
          children: [
            SortableTable(
              columns: [
                TCol('ID', (a) => (a['id'] as int) < 0 ? 'pendente' : '${a['id']}'),
                TCol('Cliente', (a) => '${a['pacienteNome'] ?? ''}'),
                TCol('Atendente', (a) => '${a['profissionalNome'] ?? ''}'),
                TCol('Data e horário', (a) => '${a['dataHora'] ?? ''}',
                    cell: (_, a) => Text(_quando(a['dataHora']))),
                TCol('Status', (a) => '${a['status'] ?? ''}',
                    cell: (_, a) => AgendamentoStatusCell('${a['status'] ?? ''}')),
              ],
              rows: _items,
              actions: (_, a) => RowActions(onEdit: () => _editar(a), onDelete: () => _excluir(a)),
            ),
          ],
        ),
      ],
    );
  }
}
