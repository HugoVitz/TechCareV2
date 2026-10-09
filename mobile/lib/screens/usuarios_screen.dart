import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../widgets/ui.dart';

/// Atendentes e usuários da loja (somente Administrador): criar, editar dados e cargo,
/// bloquear, derrubar sessão e gerar senha provisória para quem perdeu a senha.
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  static const _outro = 'Outro...';

  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _nome = TextEditingController();
  final _cargoOutro = TextEditingController();
  final _senha = TextEditingController();
  String? _cargo;
  String _perfil = 'Atendente';
  String? _etnia;
  int _id = 0;

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _auditoria = [];
  Map<String, dynamic>? _diversidade;
  Timer? _timer;

  late final ApiClient _api = context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _carregarTudo();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _listar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _login.dispose();
    _nome.dispose();
    _cargoOutro.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _carregarTudo() async {
    await _listar();
    await _diversidadeEAuditoria();
  }

  Future<void> _listar() async {
    try {
      final data = await _api.send('GET', 'usuarios') as List;
      if (mounted) setState(() => _usuarios = data.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } on NetworkException {
      if (mounted) showMessage(context, 'Sem conexão: a gestão de usuários exige internet.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _diversidadeEAuditoria() async {
    try {
      final d = await _api.send('GET', 'relatorios/diversidade');
      final a = await _api.send('GET', 'auditoria?limite=30') as List;
      if (!mounted) return;
      setState(() {
        _diversidade = Map<String, dynamic>.from(d as Map);
        _auditoria = a.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } on ApiException {
      // relatórios são complementares
    }
  }

  void _limpar() {
    _form.currentState?.reset();
    _login.clear();
    _nome.clear();
    _cargoOutro.clear();
    _senha.clear();
    setState(() {
      _id = 0;
      _cargo = null;
      _perfil = 'Atendente';
      _etnia = null;
    });
  }

  void _editar(Map<String, dynamic> u) {
    final cargo = '${u['cargo'] ?? ''}';
    setState(() {
      _id = u['id'] as int;
      _login.text = '${u['usuarioNome']}';
      _nome.text = '${u['nome'] ?? ''}';
      if (cargo.isEmpty) {
        _cargo = null;
        _cargoOutro.clear();
      } else if (AppConfig.cargos.contains(cargo)) {
        _cargo = cargo;
        _cargoOutro.clear();
      } else {
        _cargo = _outro;
        _cargoOutro.text = cargo;
      }
      _perfil = '${u['perfil']}' == 'Admin' ? 'Admin' : 'Atendente';
      final e = u['etnia'] as String?;
      _etnia = AppConfig.etnias.contains(e) ? e : null;
    });
  }

  String get _cargoFinal => _cargo == _outro ? _cargoOutro.text.trim() : (_cargo ?? '');

  Future<void> _mostrarSenha(String titulo, String usuario, String senha) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuário: $usuario'),
            const SizedBox(height: 8),
            const Text('Senha provisória:'),
            SelectableText(senha, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Informe ao usuário. Ela só aparece agora e deverá ser trocada no primeiro acesso.',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    try {
      if (_id == 0) {
        final senha = _senha.text.trim();
        if (senha.isNotEmpty && senha.length < 6) {
          return showMessage(context, 'A senha deve conter no mínimo 6 caracteres.', error: true);
        }
        final r = await _api.send('POST', 'usuarios', body: {
          'usuario': _login.text.trim(),
          'nome': _nome.text.trim(),
          'cargo': _cargoFinal,
          'perfil': _perfil,
          'etnia': _etnia ?? '',
          'senha': senha.isEmpty ? null : senha,
        }) as Map;
        if (!mounted) return;
        _limpar();
        await _mostrarSenha('Usuário criado', '${r['usuarioNome']}', '${r['senhaTemporaria']}');
      } else {
        await _api.send('PUT', 'usuarios/$_id', body: {
          'nome': _nome.text.trim(),
          'cargo': _cargoFinal,
          'perfil': _perfil,
          'etnia': _etnia ?? '',
        });
        if (!mounted) return;
        showMessage(context, 'Usuário atualizado.');
        _limpar();
      }
      await _carregarTudo();
    } on NetworkException {
      if (mounted) showMessage(context, 'Sem conexão com o servidor.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _acao(Map<String, dynamic> u, String acao) async {
    final nome = '${u['usuarioNome']}';
    try {
      switch (acao) {
        case 'senha':
          if (!await confirmDialog(context, 'Gerar uma senha provisória para "$nome"? As sessões dele serão encerradas.',
              confirm: 'Gerar')) {
            return;
          }
          final rSenha = await _api.send('POST', 'usuarios/${u['id']}/senha-temporaria', body: {}) as Map;
          if (mounted) await _mostrarSenha('Senha provisória', nome, '${rSenha['senhaTemporaria']}');
        case 'derrubar':
          if (!await confirmDialog(context, 'Encerrar agora todas as sessões de "$nome"?', confirm: 'Derrubar')) return;
          final rDerrubar = await _api.send('POST', 'usuarios/${u['id']}/derrubar', body: {}) as Map;
          if (mounted) showMessage(context, '${rDerrubar['encerradas']} sessão(ões) encerrada(s).');
        case 'bloquear':
          final novo = !(u['ativo'] == true);
          if (!await confirmDialog(context, '${novo ? 'Reativar' : 'Bloquear'} o usuário "$nome"?',
              confirm: novo ? 'Reativar' : 'Bloquear')) {
            return;
          }
          await _api.send('PUT', 'usuarios/${u['id']}', body: {'ativo': novo});
          if (mounted) showMessage(context, novo ? 'Usuário reativado.' : 'Usuário bloqueado e desconectado.');
        case 'excluir':
          if (!await confirmDialog(context, 'Excluir definitivamente "$nome"?')) return;
          await _api.send('DELETE', 'usuarios/${u['id']}');
          if (mounted) showMessage(context, 'Usuário excluído.');
      }
      await _carregarTudo();
    } on NetworkException {
      if (mounted) showMessage(context, 'Sem conexão com o servidor.', error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  String _quando(dynamic iso) {
    if (iso == null) return '—';
    var s = '$iso';
    if (!s.endsWith('Z')) s = '${s}Z';
    final d = DateTime.tryParse(s);
    return d == null ? '—' : DateFormat('dd/MM/yy HH:mm').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final editando = _id != 0;
    final div = _diversidade;

    return ScreenBody(
      title: 'Atendentes e usuários',
      onRefresh: _carregarTudo,
      children: [
        Form(
          key: _form,
          child: Panel(
            title: editando ? 'Editar usuário: ${_login.text}' : 'Novo usuário',
            subtitle: editando ? null : 'O usuário recebe uma senha provisória e precisa trocá-la no primeiro acesso.',
            children: [
              LabeledField(
                label: 'Usuário (login)',
                controller: _login,
                hint: 'Ex.: maria',
                required: true,
                readOnly: editando,
              ),
              LabeledField(label: 'Nome', controller: _nome, hint: 'Nome completo'),
              LabeledDropdown<String?>(
                label: 'Cargo',
                value: _cargo,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Não informado')),
                  for (final c in AppConfig.cargos) DropdownMenuItem<String?>(value: c, child: Text(c)),
                  const DropdownMenuItem<String?>(value: _outro, child: Text(_outro)),
                ],
                onChanged: (v) => setState(() => _cargo = v),
              ),
              if (_cargo == _outro)
                LabeledField(label: 'Qual cargo?', controller: _cargoOutro, hint: 'Digite o cargo', required: true),
              LabeledDropdown<String>(
                label: 'Perfil de acesso',
                value: _perfil,
                items: const [
                  DropdownMenuItem(value: 'Atendente', child: Text('Atendente (sem Serviços e sem Atendentes)')),
                  DropdownMenuItem(value: 'Admin', child: Text('Administrador (acesso total da loja)')),
                ],
                onChanged: (v) => setState(() => _perfil = v ?? 'Atendente'),
              ),
              LabeledDropdown<String?>(
                label: 'Etnia / cor (opcional)',
                value: _etnia,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Não informada')),
                  for (final e in AppConfig.etnias) DropdownMenuItem<String?>(value: e, child: Text(e)),
                ],
                onChanged: (v) => setState(() => _etnia = v),
              ),
              if (!editando)
                LabeledField(
                  label: 'Senha provisória (vazio = gerar automática)',
                  controller: _senha,
                  hint: 'Mínimo 6 caracteres',
                ),
              FormActions(children: [
                TcButton('Salvar', onPressed: _salvar),
                TcButton('Limpar', onPressed: _limpar, color: kSecondary),
              ]),
            ],
          ),
        ),
        Panel(
          title: 'Usuários da loja',
          subtitle: 'Quem está online agora aparece em azul. Senhas não podem ser consultadas (ficam '
              'criptografadas): para uma senha perdida, use "Senha provisória".',
          children: [
            SortableTable(
              columns: [
                TCol('ID', (u) => '${u['id']}'),
                TCol('Usuário', (u) => '${u['usuarioNome']}'),
                TCol('Nome', (u) => '${u['nome'] ?? ''}'),
                TCol('Cargo', (u) => '${u['cargo'] ?? ''}'),
                TCol('Perfil', (u) => u['perfil'] == 'Admin' ? 'Administrador' : 'Atendente'),
                TCol('Situação', (u) => u['ativo'] != true ? 'Bloqueado' : (u['online'] == true ? 'Online' : 'Ativo'),
                    cell: (_, u) {
                  final ativo = u['ativo'] == true;
                  final online = u['online'] == true;
                  final txt = !ativo ? 'Bloqueado' : (online ? 'Online' : 'Ativo');
                  final cor = !ativo ? const Color(0xFF991B1B) : (online ? const Color(0xFF1E40AF) : const Color(0xFF166534));
                  final bg = !ativo ? const Color(0xFFFEE2E2) : (online ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7));
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(txt, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    if (u['deveTrocarSenha'] == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('senha provisória', style: TextStyle(fontSize: 11)),
                      ),
                  ]);
                }),
                TCol('Último acesso', (u) => _quando(u['ultimoAcessoEm'])),
              ],
              rows: _usuarios,
              actions: (_, u) => RowActions(
                onEdit: () => _editar(u),
                onDelete: () => _acao(u, 'excluir'),
                extra: [
                  TcButton('Senha provisória', small: true, onPressed: () => _acao(u, 'senha')),
                  TcButton('Derrubar sessão', small: true, color: kSecondary, onPressed: () => _acao(u, 'derrubar')),
                  TcButton(u['ativo'] == true ? 'Bloquear' : 'Reativar',
                      small: true, color: kSecondary, onPressed: () => _acao(u, 'bloquear')),
                ],
              ),
            ),
          ],
        ),
        if (div != null)
          Panel(
            title: 'Diversidade (dados agregados)',
            subtitle: 'Autodeclaração opcional, sem nomes. Serve para acompanhar a inclusão na equipe e entre os clientes.',
            children: [
              SortableTable(
                columns: [
                  TCol('Etnia', (r) => '${r['etnia']}'),
                  TCol('Equipe', (r) => '${r['equipe']}'),
                  TCol('Clientes', (r) => '${r['clientes']}'),
                ],
                rows: _linhasDiversidade(div),
              ),
            ],
          ),
        Panel(
          title: 'Últimas ações',
          children: [
            SortableTable(
              columns: [
                TCol('Quando', (a) => '${a['data']}', cell: (_, a) => Text(_quando(a['data']))),
                TCol('Quem', (a) => '${a['atorNome']}'),
                TCol('Ação', (a) => '${a['acao']}'),
                TCol('Alvo', (a) => '${a['alvo']}'),
              ],
              rows: _auditoria,
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _linhasDiversidade(Map<String, dynamic> d) {
    final equipe = (d['equipe']['porEtnia'] as List).cast<Map>();
    final clientes = (d['clientes']['porEtnia'] as List).cast<Map>();
    return [
      for (var i = 0; i < equipe.length; i++)
        {'etnia': equipe[i]['etnia'], 'equipe': equipe[i]['quantidade'], 'clientes': clientes[i]['quantidade']},
      {'etnia': 'Total', 'equipe': d['equipe']['total'], 'clientes': d['clientes']['total']},
    ];
  }
}
