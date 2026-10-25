import 'package:controle_a_receber/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre o aplicativo Controle a Receber', (tester) async {
    await tester.pumpWidget(const ControleAReceberApp());

    expect(find.text('Controle a Receber'), findsOneWidget);
    expect(find.text('Dados de demonstração'), findsOneWidget);
    expect(find.text('Total a receber'), findsOneWidget);
    expect(find.text('Em atraso'), findsWidgets);
    expect(find.text('Recebido'), findsOneWidget);
    expect(find.text('Acordos'), findsOneWidget);
    expect(find.text('Novo acordo'), findsOneWidget);
  });
}
