import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

String money(num? v) => _money.format(v ?? 0);

String formatDate(dynamic iso) {
  if (iso == null) return '-';
  final d = DateTime.tryParse(iso.toString());
  return d == null ? '-' : DateFormat('dd/MM/yyyy').format(d.toLocal());
}

Color statusColor(String status) {
  final s = status.toLowerCase();
  if (s.startsWith('conclu') || s == 'realizado') return const Color(0xFF166534);
  if (s.startsWith('cancel')) return const Color(0xFF991B1B);
  if (s.startsWith('em and')) return const Color(0xFF92400E);
  return const Color(0xFF1D4ED8);
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
}
