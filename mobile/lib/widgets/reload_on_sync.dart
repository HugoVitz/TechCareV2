import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';

/// Faz a tela recarregar seus dados quando uma sincronização altera o banco local.
mixin ReloadOnSync<T extends StatefulWidget> on State<T> {
  int _seenVersion = -1;

  Future<void> reload();

  /// Chame no início do build().
  void watchSync(BuildContext context) {
    final v = context.select<DataService, int>((d) => d.version);
    if (_seenVersion == -1) {
      _seenVersion = v;
      return;
    }
    if (v != _seenVersion) {
      _seenVersion = v;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reload();
      });
    }
  }
}
