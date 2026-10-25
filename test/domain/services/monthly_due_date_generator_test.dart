import 'package:controle_a_receber/core/clock/civil_date.dart';
import 'package:controle_a_receber/domain/services/monthly_due_date_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlyDueDateGenerator', () {
    test('uma parcela devolve apenas a primeira data', () {
      final dates = MonthlyDueDateGenerator.generate(
        firstDueDate: CivilDate(2026, 5, 20),
        count: 1,
      );
      expect(dates, [CivilDate(2026, 5, 20)]);
    });

    test('dia 31 em ano comum', () {
      final dates = MonthlyDueDateGenerator.generate(
        firstDueDate: CivilDate(2026, 1, 31),
        count: 5,
      );
      expect(dates, [
        CivilDate(2026, 1, 31),
        CivilDate(2026, 2, 28),
        CivilDate(2026, 3, 31),
        CivilDate(2026, 4, 30),
        CivilDate(2026, 5, 31),
      ]);
    });

    test('dia 31 em ano bissexto', () {
      final dates = MonthlyDueDateGenerator.generate(
        firstDueDate: CivilDate(2028, 1, 31),
        count: 3,
      );
      expect(dates, [
        CivilDate(2028, 1, 31),
        CivilDate(2028, 2, 29),
        CivilDate(2028, 3, 31),
      ]);
    });

    test('dias 29 e 30 em fevereiro', () {
      expect(
        MonthlyDueDateGenerator.generate(
          firstDueDate: CivilDate(2026, 1, 30),
          count: 3,
        ),
        [
          CivilDate(2026, 1, 30),
          CivilDate(2026, 2, 28),
          CivilDate(2026, 3, 30),
        ],
      );
      expect(
        MonthlyDueDateGenerator.generate(
          firstDueDate: CivilDate(2026, 1, 29),
          count: 3,
        ),
        [
          CivilDate(2026, 1, 29),
          CivilDate(2026, 2, 28),
          CivilDate(2026, 3, 29),
        ],
      );
    });

    test('começar em 29/02 de ano bissexto', () {
      final dates = MonthlyDueDateGenerator.generate(
        firstDueDate: CivilDate(2028, 2, 29),
        count: 13,
      );
      expect(dates.first, CivilDate(2028, 2, 29));
      expect(dates[1], CivilDate(2028, 3, 29));
      expect(dates.last, CivilDate(2029, 2, 28));
    });

    test('virada de ano', () {
      expect(
        MonthlyDueDateGenerator.generate(
          firstDueDate: CivilDate(2026, 11, 15),
          count: 4,
        ),
        [
          CivilDate(2026, 11, 15),
          CivilDate(2026, 12, 15),
          CivilDate(2027, 1, 15),
          CivilDate(2027, 2, 15),
        ],
      );
      expect(
        MonthlyDueDateGenerator.generate(
          firstDueDate: CivilDate(2026, 12, 31),
          count: 3,
        ),
        [
          CivilDate(2026, 12, 31),
          CivilDate(2027, 1, 31),
          CivilDate(2027, 2, 28),
        ],
      );
    });

    test('o dia não escorrega depois de um mês curto', () {
      final dates = MonthlyDueDateGenerator.generate(
        firstDueDate: CivilDate(2026, 8, 31),
        count: 7,
      );
      expect(dates, [
        CivilDate(2026, 8, 31),
        CivilDate(2026, 9, 30),
        CivilDate(2026, 10, 31),
        CivilDate(2026, 11, 30),
        CivilDate(2026, 12, 31),
        CivilDate(2027, 1, 31),
        CivilDate(2027, 2, 28),
      ]);
    });

    test('120 parcelas, uma por mês, sem pular nem repetir meses', () {
      final first = CivilDate(2026, 1, 31);
      final dates = MonthlyDueDateGenerator.generate(
        firstDueDate: first,
        count: 120,
      );

      expect(dates, hasLength(120));
      expect(dates.first, first);
      expect(dates.last, CivilDate(2035, 12, 31));

      for (var i = 0; i < dates.length; i++) {
        final date = dates[i];
        final monthsFromFirst =
            (date.year * 12 + date.month) - (first.year * 12 + first.month);
        expect(monthsFromFirst, i, reason: 'parcela ${i + 1}');
        expect(
          date.day,
          first.day <= CivilDate.daysInMonth(date.year, date.month)
              ? first.day
              : CivilDate.daysInMonth(date.year, date.month),
          reason: 'dia da parcela ${i + 1}',
        );
      }
    });

    test('as datas são estritamente crescentes', () {
      final dates = MonthlyDueDateGenerator.generate(
        firstDueDate: CivilDate(2026, 1, 31),
        count: 36,
      );
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isTrue, reason: 'índice $i');
      }
    });

    test('rejeita quantidade fora de 1 a 120', () {
      for (final count in [0, -1, 121]) {
        expect(
          () => MonthlyDueDateGenerator.generate(
            firstDueDate: CivilDate(2026, 1, 1),
            count: count,
          ),
          throwsArgumentError,
          reason: 'count = $count',
        );
      }
    });
  });
}
