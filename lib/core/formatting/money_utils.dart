/// Interpreta e formata dinheiro em centavos (`int`) no padrão brasileiro.
///
/// Nenhum método usa `double`: todo o processamento é feito com texto e
/// inteiros, evitando erros como 4,35 * 100 = 434,99999...
abstract final class MoneyUtils {
  /// Maior valor aceito: R$ 999.999.999,99.
  static const int maxCents = 99999999999;

  static const int _maxReaisDigits = 9;

  static final RegExp _symbolPrefix = RegExp(
    r'^R\$[\s\u00A0]*',
    caseSensitive: false,
  );

  // Parte inteira: só dígitos, ou grupos de milhar com ponto (1.234.567).
  // Parte decimal: vírgula e 1 ou 2 dígitos.
  static final RegExp _brazilianNumber = RegExp(
    r'^(\d+|\d{1,3}(?:\.\d{3})+)(?:,(\d{1,2}))?$',
  );

  static final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');

  /// Converte texto brasileiro em centavos.
  ///
  /// Aceita, com ou sem o prefixo `R$`: `1234`, `1234,5`, `1234,56`,
  /// `1.234,56`. O ponto só é aceito como separador de milhar (grupos de
  /// exatamente 3 dígitos), então `1.000` significa mil reais e `1.5` é
  /// rejeitado por ser ambíguo.
  ///
  /// Não aceita valores negativos. Lança [FormatException] para texto
  /// inválido ou acima de [maxCents].
  static int parseCents(String input) {
    final text = input.trim().replaceFirst(_symbolPrefix, '').trim();
    final match = _brazilianNumber.firstMatch(text);
    if (match == null) {
      throw FormatException('Valor inválido. Use o formato 1.234,56', input);
    }

    final reaisDigits = match
        .group(1)!
        .replaceAll('.', '')
        .replaceFirst(_leadingZeros, '');
    if (reaisDigits.length > _maxReaisDigits) {
      throw FormatException(
        'Valor acima do máximo de R\$ 999.999.999,99',
        input,
      );
    }

    var centavos = 0;
    final fraction = match.group(2);
    if (fraction != null) {
      centavos = int.parse(fraction);
      if (fraction.length == 1) {
        centavos *= 10; // "10,5" significa 10 reais e 50 centavos.
      }
    }

    final cents = int.parse(reaisDigits) * 100 + centavos;
    if (cents > maxCents) {
      throw FormatException(
        'Valor acima do máximo de R\$ 999.999.999,99',
        input,
      );
    }
    return cents;
  }

  /// Como [parseCents], mas devolve `null` em vez de lançar exceção.
  static int? tryParseCents(String input) {
    try {
      return parseCents(input);
    } on FormatException {
      return null;
    }
  }

  /// Formata centavos como `R$ 1.234,56` (ou `1.234,56` se [withSymbol] for
  /// falso, útil para campos de edição). Valores negativos saem como
  /// `-R$ 1,00`.
  static String formatCents(int cents, {bool withSymbol = true}) {
    final absolute = cents.abs();
    final reais = absolute ~/ 100;
    final centavos = absolute % 100;

    final body =
        '${_groupThousands(reais.toString())},${centavos.toString().padLeft(2, '0')}';
    final sign = cents < 0 ? '-' : '';
    return withSymbol ? '${sign}R\$ $body' : '$sign$body';
  }

  static String _groupThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}
