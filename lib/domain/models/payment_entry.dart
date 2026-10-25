/// Dados de um pagamento necessários para calcular o status da parcela.
final class PaymentEntry {
  const PaymentEntry({required this.amountCents, this.isReversed = false});

  /// Valor pago, em centavos (sempre maior que zero).
  final int amountCents;

  /// Pagamentos estornados são ignorados no cálculo do saldo.
  final bool isReversed;
}
