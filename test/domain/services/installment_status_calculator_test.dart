import 'package:controle_a_receber/core/clock/civil_date.dart';
import 'package:controle_a_receber/core/clock/clock.dart';
import 'package:controle_a_receber/domain/models/installment_status.dart';
import 'package:controle_a_receber/domain/models/payment_entry.dart';
import 'package:controle_a_receber/domain/services/installment_status_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// "Hoje" fixo nos testes: 10/03/2026.
final _today = CivilDate(2026, 3, 10);
final _yesterday = CivilDate(2026, 3, 9);
final _tomorrow = CivilDate(2026, 3, 11);

InstallmentStatusResult _calculate({
  int amount = 10000,
  required CivilDate due,
  List<PaymentEntry> payments = const [],
  bool cancelled = false,
  CivilDate? today,
}) {
  final calculator = InstallmentStatusCalculator(FixedClock(today ?? _today));
  return calculator.calculate(
    installmentAmountCents: amount,
    dueDate: due,
    payments: payments,
    agreementCancelled: cancelled,
  );
}

void main() {
  group('pendente', () {
    test('vencimento futuro sem pagamentos', () {
      final result = _calculate(due: _tomorrow);
      expect(result.status, InstallmentStatus.pending);
      expect(result.paidCents, 0);
      expect(result.balanceCents, 10000);
      expect(result.hasPartialPayment, isFalse);
    });

    test('vencer hoje não é atraso', () {
      final result = _calculate(due: _today);
      expect(result.status, InstallmentStatus.pending);
    });
  });

  group('atrasada', () {
    test('venceu ontem sem pagamentos', () {
      final result = _calculate(due: _yesterday);
      expect(result.status, InstallmentStatus.overdue);
      expect(result.balanceCents, 10000);
      expect(result.hasPartialPayment, isFalse);
    });

    test('virada de ano: venceu em 31/12 e hoje é 01/01', () {
      final result = _calculate(
        due: CivilDate(2025, 12, 31),
        today: CivilDate(2026, 1, 1),
      );
      expect(result.status, InstallmentStatus.overdue);
    });

    test('pagamento parcial com vencimento passado continua atrasada', () {
      final result = _calculate(
        due: _yesterday,
        payments: const [PaymentEntry(amountCents: 4000)],
      );
      expect(result.status, InstallmentStatus.overdue);
      expect(result.paidCents, 4000);
      expect(result.balanceCents, 6000);
      expect(result.hasPartialPayment, isTrue);
    });
  });

  group('parcial', () {
    test('pagamento parcial antes do vencimento', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [PaymentEntry(amountCents: 4000)],
      );
      expect(result.status, InstallmentStatus.partial);
      expect(result.paidCents, 4000);
      expect(result.balanceCents, 6000);
      expect(result.hasPartialPayment, isTrue);
    });

    test('pagamento parcial no dia do vencimento', () {
      final result = _calculate(
        due: _today,
        payments: const [PaymentEntry(amountCents: 4000)],
      );
      expect(result.status, InstallmentStatus.partial);
    });

    test('vários pagamentos parciais somam', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [
          PaymentEntry(amountCents: 3000),
          PaymentEntry(amountCents: 2000),
        ],
      );
      expect(result.status, InstallmentStatus.partial);
      expect(result.paidCents, 5000);
      expect(result.balanceCents, 5000);
    });

    test('falta 1 centavo', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [PaymentEntry(amountCents: 9999)],
      );
      expect(result.status, InstallmentStatus.partial);
      expect(result.balanceCents, 1);
    });
  });

  group('paga', () {
    test('um pagamento do valor total', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [PaymentEntry(amountCents: 10000)],
      );
      expect(result.status, InstallmentStatus.paid);
      expect(result.paidCents, 10000);
      expect(result.balanceCents, 0);
      expect(result.hasPartialPayment, isFalse);
    });

    test('vários pagamentos que completam o valor', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [
          PaymentEntry(amountCents: 3000),
          PaymentEntry(amountCents: 3000),
          PaymentEntry(amountCents: 4000),
        ],
      );
      expect(result.status, InstallmentStatus.paid);
      expect(result.balanceCents, 0);
    });

    test('paga com atraso continua paga', () {
      final result = _calculate(
        due: CivilDate(2026, 1, 10),
        payments: const [PaymentEntry(amountCents: 10000)],
      );
      expect(result.status, InstallmentStatus.paid);
    });

    test('paga antes do vencimento', () {
      final result = _calculate(
        due: CivilDate(2026, 12, 10),
        payments: const [PaymentEntry(amountCents: 10000)],
      );
      expect(result.status, InstallmentStatus.paid);
    });

    test(
      'soma acima do valor (dado inconsistente) vira paga com saldo zero',
      () {
        final result = _calculate(
          due: _tomorrow,
          payments: const [PaymentEntry(amountCents: 10001)],
        );
        expect(result.status, InstallmentStatus.paid);
        expect(result.paidCents, 10001);
        expect(result.balanceCents, 0);
      },
    );
  });

  group('pagamentos estornados', () {
    test('pagamento estornado não conta e o saldo volta', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [PaymentEntry(amountCents: 10000, isReversed: true)],
      );
      expect(result.status, InstallmentStatus.pending);
      expect(result.paidCents, 0);
      expect(result.balanceCents, 10000);
      expect(result.hasPartialPayment, isFalse);
    });

    test(
      'estorno de pagamento integral em parcela vencida volta a atrasada',
      () {
        final result = _calculate(
          due: _yesterday,
          payments: const [PaymentEntry(amountCents: 10000, isReversed: true)],
        );
        expect(result.status, InstallmentStatus.overdue);
      },
    );

    test('estorno parcial deixa a parcela parcial', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [
          PaymentEntry(amountCents: 6000),
          PaymentEntry(amountCents: 4000, isReversed: true),
        ],
      );
      expect(result.status, InstallmentStatus.partial);
      expect(result.paidCents, 6000);
      expect(result.balanceCents, 4000);
    });

    test('pagamento correto depois de um estornado quita a parcela', () {
      final result = _calculate(
        due: _tomorrow,
        payments: const [
          PaymentEntry(amountCents: 10000, isReversed: true),
          PaymentEntry(amountCents: 10000),
        ],
      );
      expect(result.status, InstallmentStatus.paid);
      expect(result.paidCents, 10000);
    });
  });

  group('acordo cancelado', () {
    test('cancelada sem pagamentos', () {
      final result = _calculate(due: _tomorrow, cancelled: true);
      expect(result.status, InstallmentStatus.cancelled);
    });

    test('cancelada tem prioridade sobre atrasada', () {
      final result = _calculate(due: _yesterday, cancelled: true);
      expect(result.status, InstallmentStatus.cancelled);
    });

    test('cancelada preserva o valor já pago', () {
      final result = _calculate(
        due: _yesterday,
        cancelled: true,
        payments: const [PaymentEntry(amountCents: 4000)],
      );
      expect(result.status, InstallmentStatus.cancelled);
      expect(result.paidCents, 4000);
      expect(result.balanceCents, 6000);
      expect(result.hasPartialPayment, isTrue);
    });

    test('parcela quitada de acordo cancelado também aparece como cancelada '
        '(prioridade da seção 9 da documentação)', () {
      final result = _calculate(
        due: _tomorrow,
        cancelled: true,
        payments: const [PaymentEntry(amountCents: 10000)],
      );
      expect(result.status, InstallmentStatus.cancelled);
      expect(result.paidCents, 10000);
    });
  });

  group('relógio injetável', () {
    test('o mesmo vencimento muda de status conforme a data de hoje', () {
      final due = CivilDate(2026, 3, 10);
      expect(
        _calculate(due: due, today: CivilDate(2026, 3, 10)).status,
        InstallmentStatus.pending,
      );
      expect(
        _calculate(due: due, today: CivilDate(2026, 3, 11)).status,
        InstallmentStatus.overdue,
      );
    });
  });

  group('validação de entrada', () {
    test('rejeita valor de parcela zero ou negativo', () {
      expect(() => _calculate(amount: 0, due: _tomorrow), throwsArgumentError);
      expect(() => _calculate(amount: -1, due: _tomorrow), throwsArgumentError);
    });

    test('rejeita pagamento com valor zero ou negativo', () {
      expect(
        () => _calculate(
          due: _tomorrow,
          payments: const [PaymentEntry(amountCents: 0)],
        ),
        throwsArgumentError,
      );
      expect(
        () => _calculate(
          due: _tomorrow,
          payments: const [PaymentEntry(amountCents: -500)],
        ),
        throwsArgumentError,
      );
    });
  });
}
