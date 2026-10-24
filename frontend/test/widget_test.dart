import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Exibe a tela inicial e exige selecionar uma planilha', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Análise de calibração'), findsOneWidget);
    expect(find.text('Selecionar Excel'), findsOneWidget);
    expect(find.text('Processar planilha'), findsOneWidget);

    final botaoProcessar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Processar planilha'),
    );

    expect(botaoProcessar.onPressed, isNull);
    expect(find.text('APROVADO'), findsNothing);
    expect(find.text('REPROVADO'), findsNothing);
  });
}
