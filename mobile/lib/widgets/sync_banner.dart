import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';

/// Faixa no topo: avisa quando está offline e quantas alterações aguardam envio.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    if (data.online && data.pendingCount == 0 && !data.syncing) return const SizedBox.shrink();

    final text = data.syncing
        ? 'Sincronizando...'
        : !data.online
            ? 'Modo offline - mostrando dados salvos no aparelho'
                '${data.pendingCount > 0 ? ' (${data.pendingCount} pendente(s))' : ''}'
            : '${data.pendingCount} alteração(ões) aguardando envio';

    return Material(
      color: data.online ? Colors.amber.shade100 : Colors.grey.shade800,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(data.online ? Icons.sync : Icons.cloud_off,
                size: 18, color: data.online ? Colors.black87 : Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13, color: data.online ? Colors.black87 : Colors.white)),
            ),
            if (!data.syncing)
              TextButton(
                onPressed: data.syncNow,
                child: Text('Sincronizar',
                    style: TextStyle(color: data.online ? Colors.blue.shade800 : Colors.lightBlueAccent)),
              ),
          ],
        ),
      ),
    );
  }
}
