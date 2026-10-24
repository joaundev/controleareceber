import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// PROTÓTIPO VISUAL (autocontido)
//
// Todos os acordos, pessoas e valores desta tela são FICTÍCIOS e existem só
// para demonstração. Nada é gravado: não há banco de dados nesta etapa.
// As regras abaixo (datas, dinheiro em centavos, parcelas e status) são uma
// versão simplificada, apenas para exibir o protótipo.
// =============================================================================

void main() {
  runApp(const ControleAReceberApp());
}

// ---------------------------------------------------------------------------
// Aplicativo e tema
// ---------------------------------------------------------------------------

const Color _kBackground = Color(0xFFF4F6F8);
const Color _kBorder = Color(0xFFE1E5EA);
const Color _kTextStrong = Color(0xFF1B2A33);
const Color _kTextMuted = Color(0xFF5F6B76);

class ControleAReceberApp extends StatelessWidget {
  const ControleAReceberApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F4E5F),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Controle a Receber',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _kBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: _kBackground,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
      ),
      home: const _HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Data civil simplificada (sem hora e sem fuso)
// ---------------------------------------------------------------------------

class _Date implements Comparable<_Date> {
  const _Date(this.year, this.month, this.day);

  factory _Date.fromDateTime(DateTime value) {
    return _Date(value.year, value.month, value.day);
  }

  factory _Date.today() => _Date.fromDateTime(DateTime.now());

  final int year;
  final int month;
  final int day;

  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  }

  static int _daysInMonth(int year, int month) {
    switch (month) {
      case 2:
        return _isLeapYear(year) ? 29 : 28;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
  }

  /// Soma meses preservando o dia; se o mês de destino for mais curto, usa o
  /// último dia dele (31/01 + 1 mês = 28/02 ou 29/02). Sempre calcule a partir
  /// da data original para o dia não "escorregar" entre os meses.
  _Date addMonths(int months) {
    final totalMonths = year * 12 + (month - 1) + months;
    final monthIndex = totalMonths % 12;
    final newYear = (totalMonths - monthIndex) ~/ 12;
    final newMonth = monthIndex + 1;
    final lastDay = _daysInMonth(newYear, newMonth);
    return _Date(newYear, newMonth, day > lastDay ? lastDay : day);
  }

  _Date addDays(int days) {
    // O construtor de DateTime normaliza dias fora do mês (ex.: dia 35).
    return _Date.fromDateTime(DateTime(year, month, day + days));
  }

  bool isBefore(_Date other) => compareTo(other) < 0;

  @override
  int compareTo(_Date other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is _Date &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);
}

// ---------------------------------------------------------------------------
// Dados de demonstração (fictícios) e regras simples de exibição
// ---------------------------------------------------------------------------

enum _InstallmentStatus { cancelled, paid, overdue, partial, pending }

enum _AgreementStatus { upToDate, overdue, paid, cancelled }

class _DemoInstallment {
  const _DemoInstallment({
    required this.number,
    required this.amountCents,
    required this.dueDate,
    required this.paidCents,
    required this.status,
  });

  final int number;
  final int amountCents;
  final _Date dueDate;
  final int paidCents;
  final _InstallmentStatus status;

  int get balanceCents {
    final balance = amountCents - paidCents;
    return balance < 0 ? 0 : balance;
  }

  bool get hasPartialPayment => paidCents > 0 && balanceCents > 0;
}

class _DemoAgreement {
  const _DemoAgreement({
    required this.personName,
    required this.description,
    required this.totalCents,
    required this.cancelled,
    required this.installments,
  });

  final String personName;
  final String description;
  final int totalCents;
  final bool cancelled;
  final List<_DemoInstallment> installments;

  int get receivedCents =>
      installments.fold<int>(0, (sum, item) => sum + item.paidCents);

  /// Saldo ainda a receber. Acordos cancelados não têm mais valor a receber.
  int get pendingCents => cancelled
      ? 0
      : installments.fold<int>(0, (sum, item) => sum + item.balanceCents);

  int get overdueCents => installments
      .where((item) => item.status == _InstallmentStatus.overdue)
      .fold<int>(0, (sum, item) => sum + item.balanceCents);

  /// Primeira parcela com saldo, ou `null` se não houver (quitado/cancelado).
  _DemoInstallment? get nextInstallment {
    if (cancelled) return null;
    for (final item in installments) {
      if (item.balanceCents > 0) return item;
    }
    return null;
  }

  _AgreementStatus get status {
    if (cancelled) return _AgreementStatus.cancelled;
    if (installments.every((item) => item.status == _InstallmentStatus.paid)) {
      return _AgreementStatus.paid;
    }
    if (installments.any((item) => item.status == _InstallmentStatus.overdue)) {
      return _AgreementStatus.overdue;
    }
    return _AgreementStatus.upToDate;
  }
}

/// Divide [totalCents] em [count] valores inteiros cuja soma é exata; os
/// centavos que sobram vão para as primeiras parcelas.
List<int> _splitCents(int totalCents, int count) {
  final base = totalCents ~/ count;
  final remainder = totalCents % count;
  return List<int>.generate(
    count,
    (index) => index < remainder ? base + 1 : base,
    growable: false,
  );
}

/// Prioridade: cancelada > paga > atrasada > parcial > pendente.
/// Vencer hoje não é atraso.
_InstallmentStatus _statusOf({
  required int amountCents,
  required int paidCents,
  required _Date dueDate,
  required _Date today,
  required bool cancelled,
}) {
  final balance = amountCents - paidCents;
  if (cancelled) return _InstallmentStatus.cancelled;
  if (balance <= 0) return _InstallmentStatus.paid;
  if (dueDate.isBefore(today)) return _InstallmentStatus.overdue;
  if (paidCents > 0) return _InstallmentStatus.partial;
  return _InstallmentStatus.pending;
}

_DemoAgreement _buildDemoAgreement({
  required _Date today,
  required String personName,
  required String description,
  required int totalCents,
  required int installmentCount,
  required _Date firstDueDate,
  Set<int> paidInFull = const {},
  Map<int, int> partialPayments = const {},
  bool cancelled = false,
}) {
  final amounts = _splitCents(totalCents, installmentCount);

  final installments = List<_DemoInstallment>.generate(installmentCount, (
    index,
  ) {
    final number = index + 1;
    final amount = amounts[index];
    final paid = paidInFull.contains(number)
        ? amount
        : (partialPayments[number] ?? 0);
    final dueDate = firstDueDate.addMonths(index);
    return _DemoInstallment(
      number: number,
      amountCents: amount,
      dueDate: dueDate,
      paidCents: paid,
      status: _statusOf(
        amountCents: amount,
        paidCents: paid,
        dueDate: dueDate,
        today: today,
        cancelled: cancelled,
      ),
    );
  }, growable: false);

  return _DemoAgreement(
    personName: personName,
    description: description,
    totalCents: totalCents,
    cancelled: cancelled,
    installments: installments,
  );
}

/// Acordos fictícios, com datas relativas a hoje para que o protótipo sempre
/// mostre parcelas atrasadas, pendentes, parciais e pagas.
List<_DemoAgreement> _buildDemoAgreements(_Date today) {
  return [
    _buildDemoAgreement(
      today: today,
      personName: 'Carlos Mendes',
      description: 'Empréstimo para reforma da cozinha',
      totalCents: 600000,
      installmentCount: 6,
      firstDueDate: today.addDays(-75),
      paidInFull: {1, 2},
    ),
    _buildDemoAgreement(
      today: today,
      personName: 'Fernanda Alves',
      description: 'Curso de inglês pago em duas vezes',
      totalCents: 100000,
      installmentCount: 2,
      firstDueDate: today.addDays(-30),
      partialPayments: {1: 20000},
    ),
    _buildDemoAgreement(
      today: today,
      personName: 'Ana Paula Souza',
      description: 'Venda de notebook usado',
      totalCents: 240000,
      installmentCount: 4,
      firstDueDate: today.addDays(-20),
      paidInFull: {1},
      partialPayments: {2: 20000},
    ),
    _buildDemoAgreement(
      today: today,
      personName: 'Roberto Lima',
      description: 'Aluguel de equipamento de som',
      totalCents: 80000,
      installmentCount: 1,
      firstDueDate: today.addDays(5),
    ),
    _buildDemoAgreement(
      today: today,
      personName: 'Mariana Costa',
      description: 'Mensalidade de aulas particulares',
      totalCents: 150000,
      installmentCount: 3,
      firstDueDate: today.addDays(-80),
      paidInFull: {1, 2, 3},
    ),
    _buildDemoAgreement(
      today: today,
      personName: 'João Pereira',
      description: 'Conserto de moto (acordo cancelado)',
      totalCents: 90000,
      installmentCount: 3,
      firstDueDate: today.addDays(-50),
      paidInFull: {1},
      cancelled: true,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Formatação e estilos
// ---------------------------------------------------------------------------

/// Formata centavos como "R$ 1.234,56", sem usar `double`.
String _formatMoney(int cents) {
  final absolute = cents.abs();
  final reais = (absolute ~/ 100).toString();
  final centavos = (absolute % 100).toString().padLeft(2, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    final remaining = reais.length - i;
    buffer.write(reais[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  final sign = cents < 0 ? '-' : '';
  return '${sign}R\$ ${buffer.toString()},$centavos';
}

String _formatDate(_Date date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

enum _Tone { danger, success, warning, info, neutral }

({Color background, Color foreground}) _toneColors(_Tone tone) {
  return switch (tone) {
    _Tone.danger => (
      background: const Color(0xFFFCE8E6),
      foreground: const Color(0xFFB3261E),
    ),
    _Tone.success => (
      background: const Color(0xFFE3F2E9),
      foreground: const Color(0xFF1E6B3C),
    ),
    _Tone.warning => (
      background: const Color(0xFFFFF1D6),
      foreground: const Color(0xFF8A5A00),
    ),
    _Tone.info => (
      background: const Color(0xFFE3EEF5),
      foreground: const Color(0xFF24566F),
    ),
    _Tone.neutral => (
      background: const Color(0xFFECEEF1),
      foreground: const Color(0xFF5A6169),
    ),
  };
}

({String label, _Tone tone}) _agreementBadge(_AgreementStatus status) {
  return switch (status) {
    _AgreementStatus.overdue => (label: 'Em atraso', tone: _Tone.danger),
    _AgreementStatus.upToDate => (label: 'Em dia', tone: _Tone.info),
    _AgreementStatus.paid => (label: 'Quitado', tone: _Tone.success),
    _AgreementStatus.cancelled => (label: 'Cancelado', tone: _Tone.neutral),
  };
}

({String label, _Tone tone}) _installmentBadge(_DemoInstallment installment) {
  return switch (installment.status) {
    _InstallmentStatus.overdue => (
      label: installment.hasPartialPayment ? 'Atrasada (parcial)' : 'Atrasada',
      tone: _Tone.danger,
    ),
    _InstallmentStatus.partial => (label: 'Parcial', tone: _Tone.warning),
    _InstallmentStatus.pending => (label: 'Pendente', tone: _Tone.info),
    _InstallmentStatus.paid => (label: 'Paga', tone: _Tone.success),
    _InstallmentStatus.cancelled => (label: 'Cancelada', tone: _Tone.neutral),
  };
}

String _dueLabel(_DemoAgreement agreement) {
  if (agreement.cancelled) return 'Cancelado';
  final next = agreement.nextInstallment;
  if (next == null) return 'Quitado';
  final date = _formatDate(next.dueDate);
  return next.status == _InstallmentStatus.overdue
      ? 'Venceu em $date'
      : 'Vence em $date';
}

// ---------------------------------------------------------------------------
// Componentes reutilizáveis
// ---------------------------------------------------------------------------

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _kBorder),
      ),
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: colors.foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.message,
    required this.tone,
    this.title,
  });

  final IconData icon;
  final String message;
  final _Tone tone;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);
    final textTheme = Theme.of(context).textTheme;
    final heading = title;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading != null)
                  Text(
                    heading,
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return const _InfoBox(
      icon: Icons.info_outline,
      tone: _Tone.warning,
      title: 'Dados de demonstração',
      message: 'Pessoas, acordos e valores são fictícios e nada é salvo neste protótipo.',
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trailingText = trailing;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _kTextStrong,
            ),
          ),
        ),
        if (trailingText != null)
          Text(
            trailingText,
            style: textTheme.bodySmall?.copyWith(color: _kTextMuted),
          ),
      ],
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool alignEnd;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodySmall?.copyWith(color: _kTextMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? _kTextStrong,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(_Tone.info);
    return CircleAvatar(
      radius: 22,
      backgroundColor: colors.background,
      child: Text(
        _initials(name),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: colors.foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tela inicial
// ---------------------------------------------------------------------------

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late final List<_DemoAgreement> _agreements = _buildDemoAgreements(
    _Date.today(),
  );

  void _openDetails(_DemoAgreement agreement) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AgreementDetailPage(agreement: agreement),
      ),
    );
  }

  void _openNewAgreement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _NewAgreementPage()));
  }

  @override
  Widget build(BuildContext context) {
    final totalToReceive = _agreements.fold<int>(
      0,
      (sum, agreement) => sum + agreement.pendingCents,
    );
    final overdue = _agreements.fold<int>(
      0,
      (sum, agreement) => sum + agreement.overdueCents,
    );
    final received = _agreements.fold<int>(
      0,
      (sum, agreement) => sum + agreement.receivedCents,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle a Receber'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: _StatusBadge(label: 'Demonstração', tone: _Tone.warning),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const _DemoBanner(),
          const SizedBox(height: 16),
          _SummarySection(
            totalToReceiveCents: totalToReceive,
            overdueCents: overdue,
            receivedCents: received,
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Acordos',
            trailing: '${_agreements.length} de exemplo',
          ),
          const SizedBox(height: 8),
          for (final agreement in _agreements) ...[
            _AgreementCard(
              agreement: agreement,
              onTap: () => _openDetails(agreement),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewAgreement,
        icon: const Icon(Icons.add),
        label: const Text('Novo acordo'),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.totalToReceiveCents,
    required this.overdueCents,
    required this.receivedCents,
  });

  final int totalToReceiveCents;
  final int overdueCents;
  final int receivedCents;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryCard(
          title: 'Total a receber',
          value: _formatMoney(totalToReceiveCents),
          caption: 'Inclui as parcelas em atraso',
          icon: Icons.account_balance_wallet_outlined,
          tone: _Tone.info,
          large: true,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Em atraso',
                value: _formatMoney(overdueCents),
                icon: Icons.warning_amber_rounded,
                tone: _Tone.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Recebido',
                value: _formatMoney(receivedCents),
                icon: Icons.check_circle_outline,
                tone: _Tone.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
    this.caption,
    this.large = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final _Tone tone;
  final String? caption;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = _toneColors(tone);
    final captionText = caption;

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: colors.foreground),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _kTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: (large ? textTheme.headlineMedium : textTheme.titleLarge)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _kTextStrong,
                    ),
              ),
            ),
            if (captionText != null) ...[
              const SizedBox(height: 4),
              Text(
                captionText,
                style: textTheme.bodySmall?.copyWith(color: _kTextMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgreementCard extends StatelessWidget {
  const _AgreementCard({required this.agreement, required this.onTap});

  final _DemoAgreement agreement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badge = _agreementBadge(agreement.status);
    final isOverdue = agreement.status == _AgreementStatus.overdue;

    return _SurfaceCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(name: agreement.personName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agreement.personName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _kTextStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        agreement.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: _kTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(label: badge.label, tone: badge.tone),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabeledValue(
                    label: 'Valor pendente',
                    value: _formatMoney(agreement.pendingCents),
                  ),
                ),
                Expanded(
                  child: _LabeledValue(
                    label: 'Vencimento',
                    value: _dueLabel(agreement),
                    alignEnd: true,
                    valueColor: isOverdue
                        ? _toneColors(_Tone.danger).foreground
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detalhes do acordo
// ---------------------------------------------------------------------------

class _AgreementDetailPage extends StatelessWidget {
  const _AgreementDetailPage({required this.agreement});

  final _DemoAgreement agreement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badge = _agreementBadge(agreement.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do acordo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _DemoBanner(),
          const SizedBox(height: 16),
          _SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Avatar(name: agreement.personName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agreement.personName,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _kTextStrong,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              agreement.description,
                              style: textTheme.bodyMedium?.copyWith(
                                color: _kTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(label: badge.label, tone: badge.tone),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: _kBorder),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledValue(
                          label: 'Valor total',
                          value: _formatMoney(agreement.totalCents),
                        ),
                      ),
                      Expanded(
                        child: _LabeledValue(
                          label: 'Recebido',
                          value: _formatMoney(agreement.receivedCents),
                          valueColor: _toneColors(_Tone.success).foreground,
                        ),
                      ),
                      Expanded(
                        child: _LabeledValue(
                          label: 'Pendente',
                          value: _formatMoney(agreement.pendingCents),
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (agreement.cancelled) ...[
            const SizedBox(height: 12),
            const _InfoBox(
              icon: Icons.block,
              tone: _Tone.neutral,
              title: 'Acordo cancelado',
              message: 'Os pagamentos já recebidos continuam registrados. As parcelas restantes não são mais cobradas.',
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Parcelas',
            trailing: '${agreement.installments.length} parcelas',
          ),
          const SizedBox(height: 8),
          for (final installment in agreement.installments) ...[
            _InstallmentTile(
              installment: installment,
              totalInstallments: agreement.installments.length,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({
    required this.installment,
    required this.totalInstallments,
  });

  final _DemoInstallment installment;
  final int totalInstallments;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badge = _installmentBadge(installment);
    final colors = _toneColors(badge.tone);

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.background,
                  child: Text(
                    '${installment.number}',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parcela ${installment.number} de $totalInstallments',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _kTextStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vence em ${_formatDate(installment.dueDate)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: _kTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMoney(installment.amountCents),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _kTextStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(label: badge.label, tone: badge.tone),
                  ],
                ),
              ],
            ),
            if (installment.paidCents > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: _kBorder),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pago ${_formatMoney(installment.paidCents)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: _toneColors(_Tone.success).foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'Saldo ${_formatMoney(installment.balanceCents)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: _kTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulário de novo acordo (somente visual)
// ---------------------------------------------------------------------------

class _NewAgreementPage extends StatefulWidget {
  const _NewAgreementPage();

  @override
  State<_NewAgreementPage> createState() => _NewAgreementPageState();
}

class _NewAgreementPageState extends State<_NewAgreementPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  _Date? _firstDueDate;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalController.dispose();
    _countController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _firstDueDate;
    final initial = current == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime(current.year, current.month, current.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Primeiro vencimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (picked == null || !mounted) return;

    final date = _Date.fromDateTime(picked);
    setState(() {
      _firstDueDate = date;
      _dateController.text = _formatDate(date);
    });
  }

  void _submit() {
    // Protótipo: nenhuma validação nem gravação é feita.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Protótipo: nenhum acordo foi criado nem salvo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo acordo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _InfoBox(
            icon: Icons.info_outline,
            tone: _Tone.warning,
            title: 'Formulário de demonstração',
            message:
                'Os campos não são validados e nada é salvo neste protótipo.',
          ),
          const SizedBox(height: 16),
          _SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome da pessoa',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Ex.: Empréstimo, venda, serviço...',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _totalController,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Valor total',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _countController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Quantidade de parcelas',
                      helperText: 'De 1 a 120 parcelas mensais',
                      prefixIcon: Icon(Icons.format_list_numbered),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Primeiro vencimento',
                      hintText: 'dd/mm/aaaa',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('Criar acordo'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Demonstração: ao tocar em "Criar acordo", nada é salvo.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: _kTextMuted),
          ),
        ],
      ),
    );
  }
}
