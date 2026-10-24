import 'dart:io';

// import 'ler_planilha.dart' show estaDentroDaTolerancia;
import 'package:backend/processador_calibracao.dart'
    show estaDentroDaTolerancia;

void main() {
  var falhas = 0;

  void verificar({
    required String nome,
    required double erro,
    required double inferior,
    required double superior,
    required bool esperado,
  }) {
    final resultado = estaDentroDaTolerancia(
      erro: erro,
      limiteInferior: inferior,
      limiteSuperior: superior,
    );

    if (resultado == esperado) {
      print('OK: $nome');
    } else {
      falhas++;
      print(
        'FALHOU: $nome — '
        'esperado: $esperado, recebido: $resultado',
      );
    }
  }

  verificar(
    nome: 'Erro zero dentro da tolerância',
    erro: 0,
    inferior: -0.01,
    superior: 0.01,
    esperado: true,
  );

  verificar(
    nome: 'Erro exatamente no limite superior',
    erro: 0.01,
    inferior: -0.01,
    superior: 0.01,
    esperado: true,
  );

  verificar(
    nome: 'Erro exatamente no limite inferior',
    erro: -0.01,
    inferior: -0.01,
    superior: 0.01,
    esperado: true,
  );

  verificar(
    nome: 'Erro acima do limite superior',
    erro: 0.010001,
    inferior: -0.01,
    superior: 0.01,
    esperado: false,
  );

  verificar(
    nome: 'Erro abaixo do limite inferior',
    erro: -0.010001,
    inferior: -0.01,
    superior: 0.01,
    esperado: false,
  );

  verificar(
    nome: 'Erro dentro da tolerância unilateral',
    erro: 0.05,
    inferior: 0,
    superior: 0.1,
    esperado: true,
  );

  verificar(
    nome: 'Erro negativo fora da tolerância unilateral',
    erro: -0.001,
    inferior: 0,
    superior: 0.1,
    esperado: false,
  );

  verificar(
    nome: 'Imprecisão de double no limite',
    erro: 0.1 + 0.2,
    inferior: 0,
    superior: 0.3,
    esperado: true,
  );

  print('\nTestes concluídos. Falhas: $falhas');

  if (falhas > 0) {
    exitCode = 1;
  }
}
