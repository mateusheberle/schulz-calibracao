import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/views/qrcode_view.dart';
import 'package:frontend/views/revisao_view.dart';

void main() {
  testWidgets('Exibe o upload MMC e aceita os formatos anunciados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(
      find.text('Ingestão de Arquivo de Medição (MMC Carl Zeiss)'),
      findsOneWidget,
    );
    expect(
      find.text('Upload do Relatório de Ensaio (.xlsx / .txt)'),
      findsOneWidget,
    );
    expect(find.textContaining('.xlsx ou .txt'), findsOneWidget);
    expect(find.text('Selecionar Arquivo do Computador'), findsOneWidget);
    expect(find.text('Metadados do Instrumento Detectados'), findsOneWidget);
    expect(find.text('Processar arquivo'), findsNothing);
    expect(find.text('APROVADO'), findsNothing);
    expect(find.text('REPROVADO'), findsNothing);
  });

  testWidgets('Exibe identificação, tolerâncias e dispara ação de PDF', (
    WidgetTester tester,
  ) async {
    var gerarPdfChamado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RevisaoView(
            nomeArquivo: 'relatorio_mmc.xlsx',
            resultado: {
              'identificacao': {
                'tag_patrimonial': '703.1208',
                'denominacao': 'Dispositivo de Controle',
                'setor_solicitante': 'Usinagem I',
              },
              'responsavel': {'nome': 'Responsável de teste'},
              'resumo': {
                'parecer': 'APROVADO',
                'total': 1,
                'dentro_da_tolerancia': 1,
                'fora_da_tolerancia': 0,
              },
              'pontos': [
                {
                  'caracteristica': 'Cota A',
                  'leitura1': 10.1,
                  'leitura2': 10.2,
                  'nominal': 10,
                  'media': 10.15,
                  'erro': 0.15,
                  'lower_tol': -0.2,
                  'upper_tol': 0.2,
                  'situacao': 'DENTRO_DA_TOLERANCIA',
                },
              ],
            },
            onGerarPdf: () async {
              gerarPdfChamado = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('703.1208'), findsOneWidget);
    expect(find.text('Dispositivo de Controle'), findsOneWidget);
    expect(find.text('Usinagem I'), findsOneWidget);
    expect(find.text('Responsável de teste'), findsOneWidget);
    expect(find.text('PARECER FINAL: INSTRUMENTO APROVADO'), findsOneWidget);
    expect(find.text('Baixar PDF (Rascunho)'), findsOneWidget);
    expect(
      find.textContaining('Este documento não tem validade oficial.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Baixar PDF (Rascunho)'));
    await tester.pump();

    expect(gerarPdfChamado, isTrue);
  });

  testWidgets('Não presume parecer quando os status estão indisponíveis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RevisaoView(
            resultado: {
              'pontos': [
                {
                  'caracteristica': 'Cota sem classificação',
                  'situacao': 'INDEFINIDA',
                },
              ],
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('Parecer indisponível'), findsOneWidget);
    expect(find.text('Não classificada'), findsOneWidget);
  });

  testWidgets('Consulta QR usa dados reais e não atesta autenticidade', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrcodeView(
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cota a');
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('DENTRO DA TOLERÂNCIA'), findsOneWidget);
    expect(find.textContaining('10,1000000'), findsOneWidget);
    expect(find.textContaining('Não confirma autenticidade'), findsOneWidget);
    expect(find.textContaining('Certificado Autêntico'), findsNothing);
    expect(find.textContaining('00091/2026'), findsNothing);
  });

  testWidgets('Consulta QR desconhecida não retorna certificado válido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrcodeView(
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'TAG-NAO-CADASTRADA');
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nenhuma característica correspondente'),
      findsOneWidget,
    );
    expect(find.textContaining('Certificado Autêntico'), findsNothing);
  });
}
