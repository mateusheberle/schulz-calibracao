import 'dart:io';

import 'package:backend/processador_calibracao.dart';
import 'package:test/test.dart';

void main() {
  test('Processa a planilha de exemplo e confere os resultados', () {
    final arquivo = File('exemplos/registro_mmc.xlsx');

    expect(
      arquivo.existsSync(),
      isTrue,
      reason: 'A planilha de exemplo precisa existir.',
    );

    final resultado = processarPlanilha(arquivo.readAsBytesSync());

    final resumo = resultado['resumo'] as Map;
    final pontos = resultado['pontos'] as List;

    // Resultado esperado para a planilha original do repositório.
    expect(resumo['total'], 14);
    expect(resumo['dentroDaTolerancia'], 8);
    expect(resumo['foraDaTolerancia'], 6);
    expect(resumo['parecer'], 'REPROVADO');
    expect(pontos.length, 14);

    final planicidade =
        pontos.firstWhere(
              (ponto) => ponto['caracteristica'] == 'PLANICIDADE_REF',
            )
            as Map;

    // (0,002167 + 0,002267) / 2 = 0,002217
    expect(planicidade['media'], closeTo(0.002217, 1e-12));

    // Média − nominal: 0,002217 − 0 = 0,002217
    expect(planicidade['erro'], closeTo(0.002217, 1e-12));
    expect(planicidade['situacao'], 'DENTRO_DA_TOLERANCIA');

    final diametro =
        pontos.firstWhere(
              (ponto) => ponto['caracteristica'] == '62P_DIÂMETRO 1',
            )
            as Map;

    // Confere também um ponto cujo nominal é diferente de zero.
    expect(diametro['media'], closeTo(6.0787295, 1e-12));
    expect(diametro['erro'], closeTo(0.0037295, 1e-12));
    expect(diametro['situacao'], 'DENTRO_DA_TOLERANCIA');
  });
}
