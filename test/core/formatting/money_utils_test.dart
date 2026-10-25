import 'package:controle_a_receber/core/formatting/money_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyUtils.formatCents', () {
    test('formata no padrão brasileiro', () {
      expect(MoneyUtils.formatCents(0), 'R\$ 0,00');
      expect(MoneyUtils.formatCents(1), 'R\$ 0,01');
      expect(MoneyUtils.formatCents(99), 'R\$ 0,99');
      expect(MoneyUtils.formatCents(100), 'R\$ 1,00');
      expect(MoneyUtils.formatCents(12345), 'R\$ 123,45');
      expect(MoneyUtils.formatCents(123456), 'R\$ 1.234,56');
      expect(MoneyUtils.formatCents(100000000), 'R\$ 1.000.000,00');
    });

    test('formata o valor máximo', () {
      expect(MoneyUtils.formatCents(MoneyUtils.maxCents), 'R\$ 999.999.999,99');
    });

    test('formata valores negativos', () {
      expect(MoneyUtils.formatCents(-12345), '-R\$ 123,45');
    });

    test('permite omitir o símbolo', () {
      expect(MoneyUtils.formatCents(123456, withSymbol: false), '1.234,56');
      expect(MoneyUtils.formatCents(5, withSymbol: false), '0,05');
    });
  });

  group('MoneyUtils.parseCents: entradas válidas', () {
    test('com e sem símbolo e separadores', () {
      expect(MoneyUtils.parseCents('123,45'), 12345);
      expect(MoneyUtils.parseCents('R\$ 1.234,56'), 123456);
      expect(MoneyUtils.parseCents('R\$1.234,56'), 123456);
      expect(MoneyUtils.parseCents('r\$ 10'), 1000);
      expect(MoneyUtils.parseCents('R\$\u00A01.234,56'), 123456);
    });

    test('ignora espaços nas pontas', () {
      expect(MoneyUtils.parseCents('  10,50  '), 1050);
    });

    test('inteiros são reais, não centavos', () {
      expect(MoneyUtils.parseCents('1234'), 123400);
      expect(MoneyUtils.parseCents('0'), 0);
    });

    test('uma casa decimal vale dezenas de centavos', () {
      expect(MoneyUtils.parseCents('10,5'), 1050);
      expect(MoneyUtils.parseCents('0,5'), 50);
    });

    test('centavos pequenos', () {
      expect(MoneyUtils.parseCents('0,01'), 1);
      expect(MoneyUtils.parseCents('10,05'), 1005);
      expect(MoneyUtils.parseCents('0,00'), 0);
    });

    test('ponto é separador de milhar', () {
      expect(MoneyUtils.parseCents('1.000'), 100000);
      expect(MoneyUtils.parseCents('12.345.678,90'), 1234567890);
    });

    test('zeros à esquerda', () {
      expect(MoneyUtils.parseCents('007,50'), 750);
    });

    test('valor máximo', () {
      expect(MoneyUtils.parseCents('999.999.999,99'), MoneyUtils.maxCents);
    });

    test('valores que dão erro de arredondamento com double', () {
      expect(MoneyUtils.parseCents('0,29'), 29);
      expect(MoneyUtils.parseCents('1,15'), 115);
      expect(MoneyUtils.parseCents('4,35'), 435);
      expect(MoneyUtils.parseCents('19,90'), 1990);
    });
  });

  group('MoneyUtils.parseCents: entradas inválidas', () {
    test('lança FormatException', () {
      const invalid = [
        '',
        '   ',
        'abc',
        'R\$',
        '-10,00',
        '10,',
        ',50',
        '10,123',
        '1.5',
        '1.23',
        '1.2345,00',
        '1.234.56',
        '1,234.56',
        '1..000',
        '10,00,00',
        '1 234,56',
        '12a',
        'R\$ R\$ 10',
      ];
      for (final text in invalid) {
        expect(
          () => MoneyUtils.parseCents(text),
          throwsFormatException,
          reason: '"$text"',
        );
      }
    });

    test('rejeita valores acima do máximo', () {
      expect(
        () => MoneyUtils.parseCents('1.000.000.000,00'),
        throwsFormatException,
      );
      expect(() => MoneyUtils.parseCents('1000000000'), throwsFormatException);
      expect(
        () => MoneyUtils.parseCents('99999999999999999999'),
        throwsFormatException,
      );
    });
  });

  group('MoneyUtils.tryParseCents', () {
    test('devolve o valor quando válido', () {
      expect(MoneyUtils.tryParseCents('R\$ 1.234,56'), 123456);
    });

    test('devolve null quando inválido', () {
      expect(MoneyUtils.tryParseCents('abc'), isNull);
      expect(MoneyUtils.tryParseCents(''), isNull);
      expect(MoneyUtils.tryParseCents('-1,00'), isNull);
    });
  });

  group('MoneyUtils: ida e volta', () {
    test('parse(format(x)) == x para valores de referência', () {
      const samples = [0, 1, 99, 100, 12345, 123456, 100000000, 99999999999];
      for (final cents in samples) {
        expect(
          MoneyUtils.parseCents(MoneyUtils.formatCents(cents)),
          cents,
          reason: 'com símbolo: $cents',
        );
        expect(
          MoneyUtils.parseCents(
            MoneyUtils.formatCents(cents, withSymbol: false),
          ),
          cents,
          reason: 'sem símbolo: $cents',
        );
      }
    });

    test('ida e volta para todos os valores de 0 a 100000 centavos', () {
      for (var cents = 0; cents <= 100000; cents++) {
        expect(MoneyUtils.parseCents(MoneyUtils.formatCents(cents)), cents);
      }
    });
  });
}
