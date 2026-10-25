import 'package:controle_a_receber/core/clock/civil_date.dart';
import 'package:controle_a_receber/core/clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FixedClock', () {
    test('today devolve sempre a data informada', () {
      final clock = FixedClock(CivilDate(2026, 3, 10));
      expect(clock.today(), CivilDate(2026, 3, 10));
      expect(clock.today(), CivilDate(2026, 3, 10));
    });

    test('nowUtc padrão é meio-dia UTC da data informada', () {
      final clock = FixedClock(CivilDate(2026, 3, 10));
      expect(clock.nowUtc(), DateTime.utc(2026, 3, 10, 12));
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('aceita um nowUtc explícito', () {
      final instant = DateTime.utc(2026, 3, 10, 23, 59, 30);
      final clock = FixedClock(CivilDate(2026, 3, 10), nowUtc: instant);
      expect(clock.nowUtc(), instant);
    });

    test('rejeita nowUtc que não seja UTC', () {
      expect(
        () => FixedClock(
          CivilDate(2026, 3, 10),
          nowUtc: DateTime(2026, 3, 10, 8),
        ),
        throwsArgumentError,
      );
    });

    test('relógios diferentes dão datas diferentes', () {
      final Clock before = FixedClock(CivilDate(2026, 3, 10));
      final Clock after = FixedClock(CivilDate(2026, 3, 11));
      expect(before.today(), isNot(after.today()));
    });
  });

  group('SystemClock', () {
    test('nowUtc devolve um DateTime em UTC', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });

    test('today é a data local atual', () {
      final before = CivilDate.fromDateTime(DateTime.now());
      final today = const SystemClock().today();
      final after = CivilDate.fromDateTime(DateTime.now());

      // Comparar com os dois lados evita falha se o teste rodar na virada
      // do dia.
      expect(today.compareTo(before) >= 0, isTrue);
      expect(today.compareTo(after) <= 0, isTrue);
    });
  });
}
