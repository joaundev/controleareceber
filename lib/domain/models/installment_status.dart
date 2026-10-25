/// Status calculado de uma parcela (nunca persistido).
enum InstallmentStatus {
  /// O acordo foi cancelado.
  cancelled,

  /// Saldo igual a zero.
  paid,

  /// Há saldo e o vencimento é anterior a hoje.
  overdue,

  /// Há pagamento válido, ainda há saldo e não está atrasada.
  partial,

  /// Sem pagamento válido e vencimento hoje ou futuro.
  pending,
}

/// Resultado do cálculo de status de uma parcela.
final class InstallmentStatusResult {
  const InstallmentStatusResult({
    required this.status,
    required this.paidCents,
    required this.balanceCents,
  });

  final InstallmentStatus status;

  /// Soma dos pagamentos não estornados.
  final int paidCents;

  /// Valor da parcela menos [paidCents], nunca negativo.
  ///
  /// Em parcelas canceladas, é apenas informativo: o saldo deixa de ser
  /// "a receber".
  final int balanceCents;

  /// Há pagamento válido e ainda existe saldo. Permite exibir "paga
  /// parcialmente" mesmo quando [status] é [InstallmentStatus.overdue].
  bool get hasPartialPayment => paidCents > 0 && balanceCents > 0;

  @override
  String toString() =>
      'InstallmentStatusResult(status: $status, paidCents: $paidCents, balanceCents: $balanceCents)';
}
