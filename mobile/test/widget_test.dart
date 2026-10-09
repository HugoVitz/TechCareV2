import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techcare_mobile/widgets/format.dart';
import 'package:techcare_mobile/widgets/ui.dart';

// Testes de unidade das funções de formatação (não dependem de plugins nativos).
void main() {
  test('money formata em reais com separadores brasileiros', () {
    expect(money(1234.5), contains('1.234,50'));
    expect(money(null), contains('0,00'));
  });

  test('formatDate trata nulo, texto inválido e ISO', () {
    expect(formatDate(null), '-');
    expect(formatDate('abc'), '-');
    expect(formatDate('2026-10-05T10:00:00'), '05/10/2026');
  });

  test('statusColor diferencia os principais status', () {
    expect(statusColor('Concluída'), isNot(statusColor('Aberta')));
    expect(statusColor('Cancelada'), isNot(statusColor('Em andamento')));
    expect(statusColor('Aberta'), isA<Color>());
  });

  test('máscara de moeda: converte texto em valor e de volta', () {
    expect(parseBrl('R\$ 1.234,56'), 1234.56);
    expect(parseBrl(''), 0);
    expect(formatBrl(15), contains('15,00'));
  });

  test('hexColor lê as cores das Configurações', () {
    expect(hexColor('#2563eb'), const Color(0xFF2563EB));
    expect(hexColor('invalida'), const Color(0xFF2563EB));
  });
}
