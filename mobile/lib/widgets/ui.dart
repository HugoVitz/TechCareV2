import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/prefs_service.dart';
import '../services/tts_service.dart';

// ---------------------------------------------------------------------------
// Cores do site (styles.css)
// ---------------------------------------------------------------------------

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color pageBg(BuildContext c) => isDark(c) ? const Color(0xFF0B1220) : const Color(0xFFF4F7FB);
Color panelBg(BuildContext c) => isDark(c) ? const Color(0xFF111827) : Colors.white;
Color mutedText(BuildContext c) => isDark(c) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color lineColor(BuildContext c) => isDark(c) ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

/// Cor de "perigo/aviso/secundário" dos botões do site.
const kDanger = Color(0xFFDC2626);
const kWarning = Color(0xFFF59E0B);
const kSecondary = Color(0xFF64748B);

Color hexColor(String hex, {Color fallback = const Color(0xFF2563EB)}) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

// ---------------------------------------------------------------------------
// Leitura por voz: ao tocar no texto, lê em voz alta (se ativada nas Configurações)
// ---------------------------------------------------------------------------

class Speak extends StatelessWidget {
  const Speak(this.text, {required this.child, super.key});

  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => context.read<TtsService>().speak(text),
      child: child,
    );
  }
}

/// Texto que também é lido ao toque.
class SpokenText extends StatelessWidget {
  const SpokenText(this.text, {this.style, this.textAlign, super.key});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Speak(text, child: Text(text, style: style, textAlign: textAlign));
}

// ---------------------------------------------------------------------------
// Estrutura de página
// ---------------------------------------------------------------------------

/// Rolagem + largura máxima + cabeçalho (título e subtítulo), como o `.content` do site.
class ScreenBody extends StatelessWidget {
  const ScreenBody({required this.title, this.subtitle, required this.children, this.onRefresh, super.key});

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpokenText(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  SpokenText(subtitle!, style: TextStyle(color: mutedText(context), fontSize: 13)),
                ],
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      color: pageBg(context),
      child: onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list),
    );
  }
}

/// Bloco branco com sombra suave (`.panel` / `.card` do site).
class Panel extends StatelessWidget {
  const Panel({this.title, this.subtitle, required this.children, super.key});

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelBg(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SpokenText(title!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SpokenText(subtitle!, style: TextStyle(color: mutedText(context), fontSize: 13)),
            ),
          ...children,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campos de formulário (rótulo em cima, como no site)
// ---------------------------------------------------------------------------

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpokenText(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
}

String? requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Preencha este campo.' : null;

class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.keyboard,
    this.maxLines = 1,
    this.obscure = false,
    this.readOnly = false,
    this.formatters,
    this.validator,
    this.suffix,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  final bool obscure;
  final bool readOnly;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label,
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: obscure ? 1 : maxLines,
        obscureText: obscure,
        readOnly: readOnly,
        inputFormatters: formatters,
        onChanged: onChanged,
        validator: validator ?? (required ? requiredValidator : null),
        decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
      ),
    );
  }
}

class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    super.key,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label,
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        validator: required ? (v) => v == null ? 'Selecione uma opção.' : null : null,
      ),
    );
  }
}

/// Equivale ao `datetime-local`.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool required;

  Future<void> _pick(BuildContext context) async {
    final base = value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      initialValue: value,
      validator: required ? (_) => value == null ? 'Preencha este campo.' : null : null,
      builder: (state) => _Labeled(
        label,
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pick(context),
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: state.errorText,
              suffixIcon: value == null || required
                  ? const Icon(Icons.calendar_today, size: 18)
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => onChanged(null),
                    ),
            ),
            child: Text(
              value == null ? 'dd/mm/aaaa --:--' : DateFormat('dd/MM/yyyy HH:mm').format(value!),
              style: TextStyle(color: value == null ? mutedText(context) : null),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botões (cores do site: primário, secundário, perigo, aviso)
// ---------------------------------------------------------------------------

class TcButton extends StatelessWidget {
  const TcButton(this.label, {required this.onPressed, this.color, this.small = false, this.icon, super.key});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool small;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: small ? 12 : 13.5),
      minimumSize: Size.zero,
      tapTargetSize: small ? MaterialTapTargetSize.shrinkWrap : null,
    );
    final text = Text(label);
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: text)
        : FilledButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18), label: text);
  }
}

class FormActions extends StatelessWidget {
  const FormActions({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, children: children);
}

Future<bool> confirmDialog(BuildContext context, String message, {String confirm = 'Excluir'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------------------
// Moeda: máscara "R$ 0,00" (como o campo Valor do site)
// ---------------------------------------------------------------------------

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

String formatBrl(num v) => _brl.format(v);

/// Converte "R$ 1.234,56" em 1234.56. Texto vazio vira 0.
double parseBrl(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.parse(digits) / 100;
}

class BrlInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final text = formatBrl(int.parse(digits) / 100);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// ---------------------------------------------------------------------------
// Tabela com ordenação A-Z / Z-A ao clicar no cabeçalho (tableFilters.js)
// ---------------------------------------------------------------------------

typedef Rec = Map<String, dynamic>;

class TCol {
  const TCol(this.label, this.value, {this.cell, this.sortable = true});

  final String label;
  final String Function(Rec) value;
  final Widget Function(BuildContext, Rec)? cell;
  final bool sortable;
}

class SortableTable extends StatefulWidget {
  const SortableTable({
    required this.columns,
    required this.rows,
    this.actions,
    this.emptyText = 'Nenhum registro encontrado.',
    super.key,
  });

  final List<TCol> columns;
  final List<Rec> rows;
  final Widget Function(BuildContext, Rec)? actions;
  final String emptyText;

  @override
  State<SortableTable> createState() => _SortableTableState();
}

class _SortableTableState extends State<SortableTable> {
  int? _sortCol;
  bool _asc = true;

  int _compare(String a, String b) {
    final na = num.tryParse(a), nb = num.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.select<PrefsService, bool>((p) => p.compactar);
    final dark = isDark(context);

    final rows = [...widget.rows];
    if (_sortCol != null) {
      final col = widget.columns[_sortCol!];
      rows.sort((x, y) => _asc ? _compare(col.value(x), col.value(y)) : _compare(col.value(y), col.value(x)));
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: SpokenText(widget.emptyText, style: TextStyle(color: mutedText(context)))),
      );
    }

    final headColor = dark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    final headText = dark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A);

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: DataTable(
            sortColumnIndex: _sortCol,
            sortAscending: _asc,
            headingRowColor: WidgetStatePropertyAll(headColor),
            headingTextStyle: TextStyle(color: headText, fontWeight: FontWeight.w700),
            dataRowMinHeight: compact ? 34 : 52,
            dataRowMaxHeight: compact ? 44 : 72,
            horizontalMargin: compact ? 8 : 12,
            columnSpacing: compact ? 14 : 24,
            dividerThickness: 1,
            columns: [
              for (var i = 0; i < widget.columns.length; i++)
                DataColumn(
                  label: Text(widget.columns[i].label),
                  onSort: widget.columns[i].sortable
                      ? (_, __) => setState(() {
                            if (_sortCol == i) {
                              _asc = !_asc;
                            } else {
                              _sortCol = i;
                              _asc = true;
                            }
                          })
                      : null,
                ),
              if (widget.actions != null) const DataColumn(label: Text('Ações')),
            ],
            rows: [
              for (final r in rows)
                DataRow(cells: [
                  for (final c in widget.columns)
                    DataCell(c.cell != null
                        ? c.cell!(context, r)
                        : Speak(c.value(r), child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(c.value(r), maxLines: 2, overflow: TextOverflow.ellipsis)))),
                  if (widget.actions != null) DataCell(widget.actions!(context, r)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botões Editar / Excluir das tabelas (laranja e vermelho do site).
class RowActions extends StatelessWidget {
  const RowActions({this.onEdit, this.onDelete, this.extra = const [], super.key});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null) TcButton('Editar', onPressed: onEdit, color: kWarning, small: true),
          if (onEdit != null && onDelete != null) const SizedBox(width: 8),
          if (onDelete != null) TcButton('Excluir', onPressed: onDelete, color: kDanger, small: true),
          for (final w in extra) ...[const SizedBox(width: 8), w],
        ],
      );
}

/// Célula de status do agendamento (cores de status.css).
class AgendamentoStatusCell extends StatelessWidget {
  const AgendamentoStatusCell(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFFEF3C7), fg = const Color(0xFF926F0E);
    if (status == 'Realizado') {
      bg = const Color(0xFFC4F3D2);
      fg = const Color(0xFF166534);
    } else if (status == 'Cancelado') {
      bg = const Color(0xBDD89A9A);
      fg = const Color(0xFF991B1B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
}


/// Foto de perfil (data URL base64) ou iniciais. O 1º do ranking do mês ganha anel dourado e coroa.
class TcAvatar extends StatelessWidget {
  const TcAvatar({this.foto, required this.nome, this.size = 44, this.lider = false, super.key});

  final String? foto;
  final String nome;
  final double size;
  final bool lider;

  Uint8List? get _bytes {
    final f = foto;
    if (f == null || !f.startsWith('data:image/')) return null;
    try {
      return base64Decode(f.substring(f.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    final iniciais = partes.map((p) => p[0]).join().toUpperCase();
    final bytes = _bytes;

    final circulo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF64748B),
        boxShadow: lider
            ? const [BoxShadow(color: Color(0xBFFACC15), blurRadius: 14, spreadRadius: 3)]
            : null,
        border: lider ? Border.all(color: const Color(0xFFFACC15), width: 3) : null,
        image: bytes == null ? null : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: bytes == null
          ? Text(iniciais.isEmpty ? '?' : iniciais,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * .38))
          : null,
    );

    return Semantics(
      label: lider ? '$nome, 1º lugar do ranking do mês' : nome,
      image: true,
      child: lider
          ? SizedBox(
              width: size,
              height: size + size * .45,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  circulo,
                  Positioned(top: 0, child: Text('👑', style: TextStyle(fontSize: size * .5))),
                ],
              ),
            )
          : circulo,
    );
  }
}
