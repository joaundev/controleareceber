import '../../core/clock/civil_date.dart';
import '../../core/clock/clock.dart';
import '../models/installment_status.dart';
import '../models/payment_entry.dart';

/// Calcula o status de uma parcela. O status nunca é persistido.
///
/// Ordem de prioridade: cancelada > paga > atrasada > parcial > pendente.
final class InstallmentStatusCalculator {
  const InstallmentStatusCalculator(this._clock);

  final Clock _clock;

  /// Lança [ArgumentError] se o valor da parcela ou de qualquer pagamento
  /// não for maior que zero.
  InstallmentStatusResult calculate({
    required int installmentAmountCents,
    required CivilDate dueDate,
    required Iterable<PaymentEntry> payments,
    bool agreementCancelled = false,
  }) {
    if (installmentAmountCents <= 0) {
      throw ArgumentError.value(
        installmentAmountCents,
        'installmentAmountCents',
        'O valor da parcela deve ser maior que zero',
      );
    }

    var paidCents = 0;
    for (final payment in payments) {
      if (payment.amountCents <= 0) {
        throw ArgumentError.value(
          payment.amountCents,
          'payments',
          'O valor de um pagamento deve ser maior que zero',
        );
      }
      if (!payment.isReversed) {
        paidCents += payment.amountCents;
      }
    }

    // O saldo nunca fica negativo. Pagamentos acima do valor da parcela são
    // barrados na gravação; aqui só nos protegemos de dados inconsistentes.
    final rawBalance = installmentAmountCents - paidCents;
    final balanceCents = rawBalance < 0 ? 0 : rawBalance;

    return InstallmentStatusResult(
      status: _statusFor(
        agreementCancelled: agreementCancelled,
        balanceCents: balanceCents,
        paidCents: paidCents,
        dueDate: dueDate,
      ),
      paidCents: paidCents,
      balanceCents: balanceCents,
    );
  }

  InstallmentStatus _statusFor({
    required bool agreementCancelled,
    required int balanceCents,
    required int paidCents,
    required CivilDate dueDate,
  }) {
    if (agreementCancelled) return InstallmentStatus.cancelled;
    if (balanceCents == 0) return InstallmentStatus.paid;
    // Vencer hoje não é atraso; o atraso começa no dia seguinte.
    if (dueDate.isBefore(_clock.today())) return InstallmentStatus.overdue;
    if (paidCents > 0) return InstallmentStatus.partial;
    return InstallmentStatus.pending;
  }
}
