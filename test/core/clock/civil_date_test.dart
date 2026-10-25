import 'package:controle_a_receber/core/clock/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CivilDate: criação e validação', () {
    test('aceita uma data válida', () {
      final date = CivilDate(2026, 3, 31);
      expect(date.year, 2026);
      expect(date.month, 3);
      expect(date.day, 31);
    });

    test('aceita 29/02 em anos bissextos', () {
      expect(() => CivilDate(2028, 2, 29), returnsNormally);
      expect(() => CivilDate(2000, 2, 29), returnsNormally);
    });

    test('rejeita datas inexistentes', () {
      final invalid = <List<int>>[
        [2026, 2, 29],
        [2026, 2, 30],
        [1900, 2, 29],
        [2100, 2, 29],
        [2026, 4, 31],
        [2026, 0, 10],
        [2026, 13, 10],
        [2026, 1, 0],
        [2026, 1, 32],
        [0, 1, 1],
        [10000, 1, 1],
      ];
      for (final parts in invalid) {
        expect(
          () => CivilDate(parts[0], parts[1], parts[2]),
          throwsArgumentError,
          reason: parts.toString(),
        );
      }
    });

    test('fromDateTime usa ano, mês e dia do DateTime informado', () {
      expect(
        CivilDate.fromDateTime(DateTime(2026, 3, 10, 23, 59)),
        CivilDate(2026, 3, 10),
      );
    });
  });

  group('CivilDate: anos bissextos e dias do mês', () {
    test('isLeapYear', () {
      expect(CivilDate.isLeapYear(2024), isTrue);
      expect(CivilDate.isLeapYear(2028), isTrue);
      expect(CivilDate.isLeapYear(2000), isTrue);
      expect(CivilDate.isLeapYear(1900), isFalse);
      expect(CivilDate.isLeapYear(2100), isFalse);
      expect(CivilDate.isLeapYear(2026), isFalse);
    });

    test('daysInMonth', () {
      expect(CivilDate.daysInMonth(2026, 1), 31);
      expect(CivilDate.daysInMonth(2026, 2), 28);
      expect(CivilDate.daysInMonth(2028, 2), 29);
      expect(CivilDate.daysInMonth(2026, 4), 30);
      expect(CivilDate.daysInMonth(2026, 12), 31);
    });

    test('daysInMonth rejeita mês inválido', () {
      expect(() => CivilDate.daysInMonth(2026, 0), throwsArgumentError);
      expect(() => CivilDate.daysInMonth(2026, 13), throwsArgumentError);
    });
  });

  group('CivilDate: comparação e igualdade', () {
    test('isBefore e isAfter comparam ano, mês e dia', () {
      expect(CivilDate(2025, 12, 31).isBefore(CivilDate(2026, 1, 1)), isTrue);
      expect(CivilDate(2026, 1, 31).isBefore(CivilDate(2026, 2, 1)), isTrue);
      expect(CivilDate(2026, 3, 9).isBefore(CivilDate(2026, 3, 10)), isTrue);
      expect(CivilDate(2026, 3, 11).isAfter(CivilDate(2026, 3, 10)), isTrue);
    });

    test('datas iguais não são antes nem depois', () {
      final a = CivilDate(2026, 3, 10);
      final b = CivilDate(2026, 3, 10);
      expect(a.isBefore(b), isFalse);
      expect(a.isAfter(b), isFalse);
      expect(a.compareTo(b), 0);
    });

    test('igualdade e hashCode por valor', () {
      expect(CivilDate(2026, 1, 1), CivilDate(2026, 1, 1));
      expect(CivilDate(2026, 1, 1).hashCode, CivilDate(2026, 1, 1).hashCode);
      expect(CivilDate(2026, 1, 1), isNot(CivilDate(2026, 1, 2)));
      expect({CivilDate(2026, 1, 1), CivilDate(2026, 1, 1)}.length, 1);
    });

    test('ordena cronologicamente', () {
      final dates = [
        CivilDate(2026, 3, 1),
        CivilDate(2025, 12, 31),
        CivilDate(2026, 1, 15),
      ]..sort();
      expect(dates, [
        CivilDate(2025, 12, 31),
        CivilDate(2026, 1, 15),
        CivilDate(2026, 3, 1),
      ]);
    });
  });

  group('CivilDate: formato yyyy-MM-dd', () {
    test('toIso preenche com zeros', () {
      expect(CivilDate(2026, 3, 5).toIso(), '2026-03-05');
      expect(CivilDate(5, 1, 1).toIso(), '0005-01-01');
      expect(CivilDate(2026, 3, 5).toString(), '2026-03-05');
    });

    test('parse lê o formato estrito', () {
      expect(CivilDate.parse('2026-03-05'), CivilDate(2026, 3, 5));
      expect(CivilDate.parse('2028-02-29'), CivilDate(2028, 2, 29));
    });

    test('parse e toIso são inversos', () {
      final date = CivilDate(2031, 12, 31);
      expect(CivilDate.parse(date.toIso()), date);
    });

    test('parse rejeita formatos e datas inválidos', () {
      const invalid = [
        '',
        '2026-3-5',
        '05/03/2026',
        '2026-02-30',
        '2026-13-01',
        '0000-01-01',
        '2026-03-05 ',
        ' 2026-03-05',
        '2026-03-05T10:00:00',
      ];
      for (final text in invalid) {
        expect(
          () => CivilDate.parse(text),
          throwsFormatException,
          reason: '"$text"',
        );
      }
    });
  });

  group('CivilDate.addMonths', () {
    test('dia 31 em ano comum', () {
      final base = CivilDate(2026, 1, 31);
      expect(base.addMonths(1), CivilDate(2026, 2, 28));
      expect(base.addMonths(2), CivilDate(2026, 3, 31));
      expect(base.addMonths(3), CivilDate(2026, 4, 30));
    });

    test('dia 31 em ano bissexto', () {
      expect(CivilDate(2028, 1, 31).addMonths(1), CivilDate(2028, 2, 29));
    });

    test(
      '29/02 mais 12 meses cai em 28/02 se o ano de destino não é bissexto',
      () {
        expect(CivilDate(2028, 2, 29).addMonths(12), CivilDate(2029, 2, 28));
      },
    );

    test('29/02 mais 48 meses volta a 29/02', () {
      expect(CivilDate(2028, 2, 29).addMonths(48), CivilDate(2032, 2, 29));
    });

    test('virada de ano', () {
      expect(CivilDate(2026, 12, 15).addMonths(1), CivilDate(2027, 1, 15));
      expect(CivilDate(2026, 11, 30).addMonths(3), CivilDate(2027, 2, 28));
    });

    test('zero e 120 meses', () {
      expect(CivilDate(2026, 1, 15).addMonths(0), CivilDate(2026, 1, 15));
      expect(CivilDate(2026, 6, 10).addMonths(120), CivilDate(2036, 6, 10));
    });

    test('meses negativos', () {
      expect(CivilDate(2026, 3, 31).addMonths(-1), CivilDate(2026, 2, 28));
      expect(CivilDate(2026, 1, 31).addMonths(-1), CivilDate(2025, 12, 31));
    });

    test('estourar o ano máximo lança ArgumentError', () {
      expect(() => CivilDate(9999, 12, 1).addMonths(1), throwsArgumentError);
    });
  });
}
