import '../../core/clock/civil_date.dart';
import '../models/installment_limits.dart';

/// Gera vencimentos mensais.
abstract final class MonthlyDueDateGenerator {
  /// Devolve [count] vencimentos, o primeiro igual a [firstDueDate].
  ///
  /// Cada data é calculada a partir da data original, sem acumular erros:
  /// 31/01 gera 28/02 (29/02 em ano bissexto), volta a 31/03 e segue 30/04.
  ///
  /// Lança [ArgumentError] se [count] estiver fora de 1 a 120.
  static List<CivilDate> generate({
    required CivilDate firstDueDate,
    required int count,
  }) {
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
    return List<CivilDate>.generate(
      count,
      (index) => firstDueDate.addMonths(index),
      growable: false,
    );
  }
}
