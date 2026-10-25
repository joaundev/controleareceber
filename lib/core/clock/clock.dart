import 'civil_date.dart';

/// Abstração do relógio. O domínio nunca chama `DateTime.now()` diretamente;
/// recebe um [Clock], o que permite testar com datas fixas.
abstract class Clock {
  const Clock();

  /// Instante atual em UTC, para timestamps de auditoria.
  DateTime nowUtc();

  /// Data civil de hoje no fuso local do aparelho.
  CivilDate today();
}

/// Relógio real, usado pelo aplicativo.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  CivilDate today() => CivilDate.fromDateTime(DateTime.now());
}

/// Relógio com data fixa, para testes.
///
/// [today] e [nowUtc] são independentes: informe os dois se um teste
/// depender da relação entre eles.
class FixedClock extends Clock {
  FixedClock(CivilDate today, {DateTime? nowUtc})
    : _today = today,
      _nowUtc = nowUtc ?? DateTime.utc(today.year, today.month, today.day, 12) {
    if (!_nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'Deve ser um DateTime UTC');
    }
  }

  final CivilDate _today;
  final DateTime _nowUtc;

  @override
  DateTime nowUtc() => _nowUtc;

  @override
  CivilDate today() => _today;
}
