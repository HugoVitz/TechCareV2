// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class VLibras {
  static const bool supported = true;

  static bool _loaded = false;

  static void setEnabled(bool enabled) {
    if (enabled) _load();
    final el = html.document.querySelector('[vw]');
    if (el != null) el.style.display = enabled ? 'block' : 'none';
  }

  static void _load() {
    if (_loaded) return;
    _loaded = true;

    final box = html.DivElement()
      ..setAttribute('vw', '')
      ..classes.add('enabled');
    box.append(html.DivElement()
      ..setAttribute('vw-access-button', '')
      ..classes.add('active'));
    final wrapper = html.DivElement()..setAttribute('vw-plugin-wrapper', '');
    wrapper.append(html.DivElement()..classes.add('vw-plugin-top-wrapper'));
    box.append(wrapper);
    html.document.body!.append(box);

    final script = html.ScriptElement()..src = 'https://vlibras.gov.br/app/vlibras-plugin.js';
    script.onLoad.listen((_) {
      final init = html.ScriptElement()
        ..text = "new window.VLibras.Widget('https://vlibras.gov.br/app');";
      html.document.body!.append(init);
    });
    html.document.body!.append(script);
  }
}
