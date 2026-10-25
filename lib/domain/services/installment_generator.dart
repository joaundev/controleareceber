import '../../core/clock/civil_date.dart';
import '../../core/formatting/money_utils.dart';
import '../models/installment_draft.dart';
import '../models/installment_limits.dart';
import 'monthly_due_date_generator.dart';

/// Divide o valor de um acordo em parcelas.
abstract final class InstallmentGenerator {
  /// Divide [totalCents] em [count] valores cuja soma é exatamente
  /// [totalCents].
  ///
  /// Os centavos que sobram da divisão inteira vão, um a um, para as
  /// primeiras parcelas. Exemplo: 10000 em 3 → [3334, 3333, 3333].
  ///
  /// Lança [ArgumentError] se [count] estiver fora de 1 a 120, se
  /// [totalCents] for menor que [count] (mínimo de 1 centavo por parcela) ou
  /// se passar de [MoneyUtils.maxCents].
  static List<int> splitAmount({required int totalCents, required int count}) {
    _validateCount(count);
    if (totalCents <= 0) {
      throw ArgumentError.value(
        totalCents,
        'totalCents',
        'O valor total deve ser maior que zero',
      );
    }
    if (totalCents > MoneyUtils.maxCents) {
      throw ArgumentError.value(
        totalCents,
        'totalCents',
        'O valor total excede o máximo permitido',
      );
    }
    if (totalCents < count) {
      throw ArgumentError.value(
        totalCents,
        'totalCents',
        'O valor total deve permitir pelo menos 1 centavo por parcela',
      );
    }

    final base = totalCents ~/ count;
    final remainder = totalCents % count;
    return List<int>.generate(
      count,
      (index) => index < remainder ? base + 1 : base,
      growable: false,
    );
  }

  /// Gera as parcelas (número, valor e vencimento mensal) de um acordo.
  static List<InstallmentDraft> generate({
    required int totalCents,
    required int count,
    required CivilDate firstDueDate,
  }) {
    final amounts = splitAmount(totalCents: totalCents, count: count);
    final dueDates = MonthlyDueDateGenerator.generate(
      firstDueDate: firstDueDate,
      count: count,
    );
    return List<InstallmentDraft>.generate(
      count,
      (index) => InstallmentDraft(
        number: index + 1,
        amountCents: amounts[index],
        dueDate: dueDates[index],
      ),
      growable: false,
    );
  }

  static void _validateCount(int count) {
    if (count < InstallmentLimits.minInstallments ||
        count > InstallmentLimits.maxInstallments) {
      throw ArgumentError.value(
        count,
        'count',
        'A quantidade de parcelas deve estar entre '
            '${InstallmentLimits.minInstallments} e '
            '${InstallmentLimits.maxInstallments}',
      );
    }
  }
}
