import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/format.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Motivo da sessão derrubada (ex.: falta de pagamento, senha redefinida).
    _error = context.read<AuthService>().notice;
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await auth.login(_user.text, _pass.text);
    } on NetworkException catch (e) {
      setState(() => _error = 'Não foi possível conectar em ${auth.apiBase}.\n'
          '${e.detail}\n'
          'Toque na engrenagem para ajustar o endereço e testar a conexão.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editServer() async {
    final auth = context.read<AuthService>();
    final ctrl = TextEditingController(text: auth.apiBase);
    String? resultado;
    bool resultadoOk = false;
    bool testando = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Endereço da API'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: '192.168.0.15:5000',
                    helperText: 'IP do computador + :5000. Emulador Android: 10.0.2.2:5000',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: testando
                      ? null
                      : () async {
                          setLocal(() {
                            testando = true;
                            resultado = null;
                          });
                          try {
                            final msg = await auth.testConnection(ctrl.text);
                            resultado = msg;
                            resultadoOk = msg.contains('Banco de dados: ok');
                          } on NetworkException catch (e) {
                            resultado = e.toString();
                            resultadoOk = false;
                          } on ApiException catch (e) {
                            resultado = e.message;
                            resultadoOk = false;
                          }
                          setLocal(() => testando = false);
                        },
                  icon: testando
                      ? const SizedBox(
                          height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find),
                  label: const Text('Testar conexão'),
                ),
                if (resultado != null) ...[
                  const SizedBox(height: 8),
                  Text(resultado!,
                      style: TextStyle(
                          color: resultadoOk ? Colors.green.shade800 : Colors.red.shade700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );

    if (ok == true) {
      await auth.setApiBase(ctrl.text);
      if (mounted) showSnack(context, 'Endereço salvo: ${auth.apiBase}');
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Configurar servidor',
                icon: const Icon(Icons.settings),
                onPressed: _editServer,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _form,
                    child: Panel(
                      title: 'Login',
                      children: [
                        LabeledField(
                          label: 'Nome',
                          controller: _user,
                          hint: 'Digite seu usuário',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o usuário.' : null,
                        ),
                        LabeledField(
                          label: 'Senha',
                          controller: _pass,
                          hint: 'Digite sua senha',
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha.' : null,
                        ),
                        TcButton(
                          _loading ? 'Entrando...' : 'Entrar no sistema',
                          onPressed: _loading ? null : _submit,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Não possui uma conta? Peça ao administrador da sua loja para criar o seu acesso.',
                          style: TextStyle(color: mutedText(context)),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                        ],
                        const SizedBox(height: 12),
                        Text('Servidor: ${context.watch<AuthService>().apiBase}',
                            style: TextStyle(fontSize: 12, color: mutedText(context))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
