import '../../core/clock/civil_date.dart';

/// Parcela calculada, ainda não persistida. Usada na prévia do acordo.
final class InstallmentDraft {
  const InstallmentDraft({
    required this.number,
    required this.amountCents,
    required this.dueDate,
  });

  /// Número da parcela, começando em 1.
  final int number;
  final int amountCents;
  final CivilDate dueDate;

  @override
  bool operator ==(Object other) {
    return other is InstallmentDraft &&
        other.number == number &&
        other.amountCents == amountCents &&
        other.dueDate == dueDate;
  }

  @override
  int get hashCode => Object.hash(number, amountCents, dueDate);

  @override
  String toString() =>
      'InstallmentDraft(number: $number, amountCents: $amountCents, dueDate: $dueDate)';
}
