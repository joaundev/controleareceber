import 'package:controle_a_receber/core/clock/civil_date.dart';
import 'package:controle_a_receber/core/formatting/money_utils.dart';
import 'package:controle_a_receber/domain/models/installment_draft.dart';
import 'package:controle_a_receber/domain/services/installment_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstallmentGenerator.splitAmount', () {
    test('divisão exata', () {
      expect(InstallmentGenerator.splitAmount(totalCents: 10000, count: 4), [
        2500,
        2500,
        2500,
        2500,
      ]);
    });

    test('centavos restantes vão para as primeiras parcelas', () {
      expect(InstallmentGenerator.splitAmount(totalCents: 10000, count: 3), [
        3334,
        3333,
        3333,
      ]);
      expect(InstallmentGenerator.splitAmount(totalCents: 10001, count: 4), [
        2501,
        2500,
        2500,
        2500,
      ]);
      expect(InstallmentGenerator.splitAmount(totalCents: 10002, count: 4), [
        2501,
        2501,
        2500,
        2500,
      ]);
      expect(InstallmentGenerator.splitAmount(totalCents: 10003, count: 4), [
        2501,
        2501,
        2501,
        2500,
      ]);
      expect(InstallmentGenerator.splitAmount(totalCents: 7, count: 3), [
        3,
        2,
        2,
      ]);
    });

    test('uma parcela recebe tudo', () {
      expect(InstallmentGenerator.splitAmount(totalCents: 1, count: 1), [1]);
      expect(InstallmentGenerator.splitAmount(totalCents: 12345, count: 1), [
        12345,
      ]);
    });

    test('total igual à quantidade dá 1 centavo por parcela', () {
      expect(InstallmentGenerator.splitAmount(totalCents: 5, count: 5), [
        1,
        1,
        1,
        1,
        1,
      ]);
    });

    test('valor máximo em 120 parcelas', () {
      final amounts = InstallmentGenerator.splitAmount(
        totalCents: MoneyUtils.maxCents,
        count: 120,
      );
      expect(
        amounts.fold<int>(0, (sum, value) => sum + value),
        MoneyUtils.maxCents,
      );
      expect(amounts[38], 833333334); // Última parcela com centavo extra.
      expect(amounts[39], 833333333);
    });

    test('a soma é exata, a diferença é de no máximo 1 centavo e as '
        'parcelas maiores vêm primeiro', () {
      const totals = [
        120,
        121,
        199,
        1000,
        9999,
        10000,
        12345,
        1000003,
        99999999999,
      ];
      for (var count = 1; count <= 120; count++) {
        for (final total in totals) {
          final amounts = InstallmentGenerator.splitAmount(
            totalCents: total,
            count: count,
          );
          final reason = 'total=$total count=$count';

          expect(amounts, hasLength(count), reason: reason);
          expect(
            amounts.fold<int>(0, (sum, value) => sum + value),
            total,
            reason: reason,
          );
          expect(amounts.every((value) => value >= 1), isTrue, reason: reason);

          final biggest = amounts.reduce((a, b) => a > b ? a : b);
          final smallest = amounts.reduce((a, b) => a < b ? a : b);
          expect(biggest - smallest <= 1, isTrue, reason: reason);

          for (var i = 1; i < amounts.length; i++) {
            expect(amounts[i - 1] >= amounts[i], isTrue, reason: reason);
          }
        }
      }
    });

    test('rejeita quantidade fora de 1 a 120', () {
      for (final count in [0, -1, 121]) {
        expect(
          () =>
              InstallmentGenerator.splitAmount(totalCents: 10000, count: count),
          throwsArgumentError,
          reason: 'count = $count',
        );
      }
    });

    test('rejeita total zero ou negativo', () {
      expect(
        () => InstallmentGenerator.splitAmount(totalCents: 0, count: 1),
        throwsArgumentError,
      );
      expect(
        () => InstallmentGenerator.splitAmount(totalCents: -100, count: 1),
        throwsArgumentError,
      );
    });

    test('rejeita total menor que 1 centavo por parcela', () {
      expect(
        () => InstallmentGenerator.splitAmount(totalCents: 3, count: 5),
        throwsArgumentError,
      );
    });

    test('rejeita total acima do máximo', () {
      expect(
        () => InstallmentGenerator.splitAmount(
          totalCents: MoneyUtils.maxCents + 1,
          count: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('InstallmentGenerator.generate', () {
    test('combina valores e vencimentos mensais', () {
      final drafts = InstallmentGenerator.generate(
        totalCents: 10000,
        count: 3,
        firstDueDate: CivilDate(2026, 1, 31),
      );
      expect(drafts, [
        InstallmentDraft(
          number: 1,
          amountCents: 3334,
          dueDate: CivilDate(2026, 1, 31),
        ),
        InstallmentDraft(
          number: 2,
          amountCents: 3333,
          dueDate: CivilDate(2026, 2, 28),
        ),
        InstallmentDraft(
          number: 3,
          amountCents: 3333,
          dueDate: CivilDate(2026, 3, 31),
        ),
      ]);
    });

    test('acordo de uma parcela', () {
      final drafts = InstallmentGenerator.generate(
        totalCents: 50000,
        count: 1,
        firstDueDate: CivilDate(2026, 6, 10),
      );
      expect(drafts, [
        InstallmentDraft(
          number: 1,
          amountCents: 50000,
          dueDate: CivilDate(2026, 6, 10),
        ),
      ]);
    });

    test('120 parcelas: numeração sequencial e soma igual ao total', () {
      final drafts = InstallmentGenerator.generate(
        totalCents: 1000003,
        count: 120,
        firstDueDate: CivilDate(2026, 1, 31),
      );
      expect(drafts, hasLength(120));
      expect(
        drafts.map((draft) => draft.number),
        List<int>.generate(120, (index) => index + 1),
      );
      expect(
        drafts.fold<int>(0, (sum, draft) => sum + draft.amountCents),
        1000003,
      );
    });

    test('repassa as validações de quantidade e valor', () {
      expect(
        () => InstallmentGenerator.generate(
          totalCents: 10000,
          count: 0,
          firstDueDate: CivilDate(2026, 1, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => InstallmentGenerator.generate(
          totalCents: 2,
          count: 3,
          firstDueDate: CivilDate(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('InstallmentDraft', () {
    test('igualdade por valor', () {
      final a = InstallmentDraft(
        number: 1,
        amountCents: 100,
        dueDate: CivilDate(2026, 1, 1),
      );
      final b = InstallmentDraft(
        number: 1,
        amountCents: 100,
        dueDate: CivilDate(2026, 1, 1),
      );
      final c = InstallmentDraft(
        number: 2,
        amountCents: 100,
        dueDate: CivilDate(2026, 1, 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
