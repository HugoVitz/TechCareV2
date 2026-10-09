import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/ui.dart';

/// Primeiro acesso (senha provisória) ou troca de senha: igual à página "Definir nova senha".
class TrocarSenhaScreen extends StatefulWidget {
  const TrocarSenhaScreen({super.key});

  @override
  State<TrocarSenhaScreen> createState() => _TrocarSenhaScreenState();
}

class _TrocarSenhaScreenState extends State<TrocarSenhaScreen> {
  final _form = GlobalKey<FormState>();
  final _nova = TextEditingController();
  final _confirmar = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nova.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().changePassword(nova: _nova.text);
    } on NetworkException {
      setState(() => _error = 'Erro ao conectar com o servidor.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _form,
                child: Panel(
                  title: 'Definir nova senha',
                  subtitle: 'Por segurança, escolha uma senha só sua para continuar.',
                  children: [
                    LabeledField(
                      label: 'Nova senha',
                      controller: _nova,
                      hint: 'Mínimo 6 caracteres',
                      obscure: true,
                      validator: (v) => (v == null || v.length < 6) ? 'A senha deve conter no mínimo 6 caracteres.' : null,
                    ),
                    LabeledField(
                      label: 'Confirmar nova senha',
                      controller: _confirmar,
                      obscure: true,
                      validator: (v) => v != _nova.text ? 'As senhas não conferem.' : null,
                    ),
                    TcButton(_loading ? 'Salvando...' : 'Salvar nova senha', onPressed: _loading ? null : _submit),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: kDanger)),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.read<AuthService>().logout(),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
