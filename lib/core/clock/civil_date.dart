/// Data civil (ano, mês e dia), sem hora e sem fuso horário.
///
/// Vencimentos e datas de pagamento são datas civis: "10/03" continua sendo
/// "10/03" mesmo que o aparelho mude de fuso. Por isso o domínio não faz
/// aritmética de datas com [DateTime], que carrega fuso e horário de verão.
final class CivilDate implements Comparable<CivilDate> {
  static const int minYear = 1;
  static const int maxYear = 9999;

  static const List<int> _daysPerMonth = [
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, //
  ];

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Lança [ArgumentError] se a data não existir (por exemplo, 30/02).
  CivilDate(this.year, this.month, this.day) {
    if (year < minYear || year > maxYear) {
      throw ArgumentError.value(
        year,
        'year',
        'O ano deve estar entre $minYear e $maxYear',
      );
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'O mês deve estar entre 1 e 12',
      );
    }
    final lastDay = daysInMonth(year, month);
    if (day < 1 || day > lastDay) {
      throw ArgumentError.value(
        day,
        'day',
        'O dia deve estar entre 1 e $lastDay para $month/$year',
      );
    }
  }

  /// Usa os campos de [value] como estão, sem converter de fuso. Para obter
  /// "hoje", passe um [DateTime] local (por exemplo, `DateTime.now()`).
  factory CivilDate.fromDateTime(DateTime value) {
    return CivilDate(value.year, value.month, value.day);
  }

  /// Interpreta estritamente o formato `yyyy-MM-dd`.
  ///
  /// Lança [FormatException] se o texto não estiver nesse formato ou se a
  /// data não existir.
  factory CivilDate.parse(String source) {
    final match = _isoPattern.firstMatch(source);
    if (match == null) {
      throw FormatException('Data inválida: esperado yyyy-MM-dd', source);
    }
    try {
      return CivilDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      throw FormatException('Data inexistente', source);
    }
  }

  final int year;
  final int month;
  final int day;

  static bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  }

  static int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'O mês deve estar entre 1 e 12',
      );
    }
    if (month == 2 && isLeapYear(year)) {
      return 29;
    }
    return _daysPerMonth[month - 1];
  }

  /// Soma [months] meses (aceita negativos) preservando o dia sempre que
  /// possível. Se o mês de destino for mais curto, usa o último dia dele.
  ///
  /// Exemplo: 31/01 + 1 mês = 28/02 (ou 29/02 em ano bissexto).
  ///
  /// Para gerar uma série de vencimentos, chame sempre a partir da data
  /// original (`base.addMonths(i)`), nunca a partir da data anterior; caso
  /// contrário o dia "escorrega" (31/01 → 28/02 → 28/03...).
  CivilDate addMonths(int months) {
    final totalMonths = year * 12 + (month - 1) + months;
    final monthIndex = totalMonths % 12; // Em Dart, sempre >= 0 aqui.
    final newYear = (totalMonths - monthIndex) ~/ 12;
    final newMonth = monthIndex + 1;
    final lastDay = daysInMonth(newYear, newMonth);
    return CivilDate(newYear, newMonth, day > lastDay ? lastDay : day);
  }

  bool isBefore(CivilDate other) => compareTo(other) < 0;

  bool isAfter(CivilDate other) => compareTo(other) > 0;

  /// Formato `yyyy-MM-dd`, o mesmo usado para persistir datas civis.
  String toIso() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  int compareTo(CivilDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is CivilDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
