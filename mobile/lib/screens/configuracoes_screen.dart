import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/prefs_service.dart';
import '../services/tts_service.dart';
import '../services/vlibras.dart';
import '../widgets/ui.dart';

/// Configurações do Sistema: mesmas opções da página do site.
class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  Widget _linha(BuildContext context, String titulo, String descricao, Widget controle, {Widget? extra}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpokenText(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                SpokenText(descricao, style: TextStyle(color: mutedText(context), fontSize: 13)),
                if (extra != null) extra,
              ],
            ),
          ),
          const SizedBox(width: 12),
          controle,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrefsService>();
    final primary = Theme.of(context).colorScheme.primary;

    return ScreenBody(
      title: 'Configurações do Sistema',
      subtitle: 'Personalize aparência, acessibilidade e preferências da plataforma.',
      children: [
        const _PerfilPanel(),
        Panel(
          title: 'Configurações de Aparência',
          children: [
            _linha(context, 'Tema escuro', 'Alterna entre o modo claro e o modo escuro do sistema.',
                Switch(value: p.escuro, onChanged: p.setEscuro)),
            const Divider(height: 1),
            _linha(
              context,
              'Cor principal',
              'Escolha a cor principal utilizada no sistema.',
              Wrap(
                spacing: 8,
                children: [
                  for (final c in AppConfig.cores)
                    Semantics(
                      button: true,
                      label: 'Cor $c',
                      child: GestureDetector(
                        onTap: () => p.setCor(c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: hexColor(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.cor.toLowerCase() == c ? (isDark(context) ? Colors.white : Colors.black87) : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _linha(context, 'Compactar tabelas', 'Reduz os espaçamentos internos das tabelas.',
                Switch(value: p.compactar, onChanged: p.setCompactar)),
          ],
        ),
        Panel(
          title: 'Configurações de Acessibilidade',
          children: [
            _linha(
              context,
              'Tamanho da fonte',
              'Ajusta o tamanho dos textos exibidos no sistema.',
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(
                  onPressed: p.fonte <= 0.8 ? null : () => p.mudarFonte(-0.1),
                  child: const Text('A-'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${(p.fonte * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                OutlinedButton(
                  onPressed: p.fonte >= 1.5 ? null : () => p.mudarFonte(0.1),
                  child: const Text('A+'),
                ),
              ]),
            ),
            const Divider(height: 1),
            _linha(context, 'Alto contraste', 'Melhora a visibilidade de textos e elementos visuais.',
                Switch(value: p.altoContraste, onChanged: p.setAltoContraste)),
            const Divider(height: 1),
            _linha(
              context,
              'VLibras',
              'Ativa o tradutor automático em Libras para acessibilidade.',
              Switch(value: p.libras, onChanged: p.setLibras),
              extra: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Status: ${p.libras ? 'Ativado' : 'Desativado'}'
                  '${p.libras && !VLibras.supported ? ' (o tradutor aparece na versão para navegador)' : ''}',
                  style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const Divider(height: 1),
            _linha(
              context,
              p.leituraVoz ? 'Leitura por voz ativada' : 'Leitura por voz',
              'Reproduz uma mensagem utilizando voz em português. Com ela ativada, toque em um texto para ouvi-lo.',
              TcButton(
                p.leituraVoz ? 'Desativar leitura por voz' : 'Ativar leitura por voz',
                onPressed: () async {
                  final tts = context.read<TtsService>();
                  final vaiAtivar = !p.leituraVoz;
                  await p.setLeituraVoz(vaiAtivar);
                  if (vaiAtivar) await tts.speakAlways('Leitura por voz ativada.');
                },
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TcButton('Restaurar configurações padrão', color: kSecondary, onPressed: p.restaurarPadrao),
        ),
      ],
    );
  }
}


/// Meu perfil: foto (enviar/remover), nome e cargo. O 1º do ranking do mês ganha destaque dourado.
class _PerfilPanel extends StatefulWidget {
  const _PerfilPanel();

  @override
  State<_PerfilPanel> createState() => _PerfilPanelState();
}

class _PerfilPanelState extends State<_PerfilPanel> {
  final _nome = TextEditingController();
  final _cargo = TextEditingController();
  bool _carregado = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    _cargo.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final auth = context.read<AuthService>();
    await auth.refreshProfile();
    if (!mounted) return;
    setState(() {
      _nome.text = auth.nomeExibicao ?? auth.usuario ?? '';
      _cargo.text = auth.cargo ?? '';
      _carregado = true;
    });
  }

  Future<void> _salvar() async {
    try {
      await context.read<AuthService>().saveProfile(_nome.text.trim(), _cargo.text.trim());
      if (mounted) showMessage(context, 'Dados salvos.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } on NetworkException {
      if (mounted) showMessage(context, 'Sem conexão com o servidor.', error: true);
    }
  }

  Future<void> _enviarFoto() async {
    final auth = context.read<AuthService>();
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 320, maxHeight: 320, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final mime = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      await auth.saveFoto('data:image/$mime;base64,${base64Encode(bytes)}');
      if (mounted) showMessage(context, 'Foto atualizada.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } on NetworkException {
      if (mounted) showMessage(context, 'Enviar a foto exige conexão com o servidor.', error: true);
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível abrir a imagem.', error: true);
    }
  }

  Future<void> _trocarSenha() async {
    final atual = TextEditingController();
    final nova = TextEditingController();
    final conf = TextEditingController();
    String erro = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Trocar minha senha'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: atual, obscureText: true, decoration: const InputDecoration(labelText: 'Senha atual')),
              TextField(controller: nova, obscureText: true, decoration: const InputDecoration(labelText: 'Nova senha (mínimo 6)')),
              TextField(controller: conf, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar nova senha')),
              if (erro.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(erro, style: const TextStyle(color: kDanger))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (nova.text.length < 6) return setD(() => erro = 'A senha deve conter no mínimo 6 caracteres.');
                if (nova.text != conf.text) return setD(() => erro = 'As senhas não conferem.');
                try {
                  await context.read<AuthService>().changePassword(atual: atual.text, nova: nova.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } on ApiException catch (e) {
                  setD(() => erro = e.message);
                } on NetworkException {
                  setD(() => erro = 'Sem conexão com o servidor.');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    atual.dispose();
    nova.dispose();
    conf.dispose();
    if (ok == true && mounted) showMessage(context, 'Senha alterada.');
  }

  Future<void> _removerFoto() async {
    try {
      await context.read<AuthService>().saveFoto('');
      if (mounted) showMessage(context, 'Foto removida.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } on NetworkException {
      if (mounted) showMessage(context, 'Sem conexão com o servidor.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Panel(
      title: 'Meu perfil',
      subtitle: 'Sua foto aparece no menu, no ranking e na lista da equipe. Quem fechar o mês em 1º lugar ganha destaque dourado.',
      children: [
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TcAvatar(foto: auth.foto, nome: auth.nomeExibicao ?? auth.usuario ?? '', size: 110, lider: auth.lider),
        )),
        if (auth.lider)
          const Center(child: Text('👑 1º lugar do ranking do mês', style: TextStyle(fontWeight: FontWeight.bold))),
        if (_carregado) ...[
          LabeledField(label: 'Nome', controller: _nome, hint: 'Seu nome'),
          LabeledField(label: 'Cargo', controller: _cargo, hint: 'Ex.: Vendedor, Técnico'),
        ],
        FormActions(children: [
          TcButton('Salvar dados', onPressed: _salvar),
          TcButton('Enviar foto', icon: Icons.photo_camera_outlined, onPressed: _enviarFoto, color: kSecondary),
          TcButton('Remover foto', onPressed: _removerFoto, color: kSecondary),
          TcButton('Trocar minha senha', icon: Icons.lock_outline, onPressed: _trocarSenha, color: kSecondary),
        ]),
      ],
    );
  }
}
