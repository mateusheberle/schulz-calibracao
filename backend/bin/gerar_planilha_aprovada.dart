import 'dart:io';

import 'package:excel/excel.dart';

void main() {
  final original = File('exemplos/registro_mmc.xlsx');
  final excel = Excel.decodeBytes(original.readAsBytesSync());
  final aba = excel.tables['Report'];

  if (aba == null) {
    throw StateError('Aba Report não encontrada.');
  }

  var alteradas = 0;

  for (var linha = 13; linha < aba.maxRows; linha++) {
    final nome = aba
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: linha))
        .value
        ?.toString();

    if (nome != null && nome.contains('POSIÇÃO')) {
      aba
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: linha))
          .value = DoubleCellValue(
        0.05,
      );

      alteradas++;
    }
  }

  if (alteradas != 12) {
    throw StateError(
      'Esperadas 12 leituras de posição, encontradas $alteradas.',
    );
  }

  final bytes = excel.encode();

  if (bytes == null) {
    throw StateError('Não foi possível gerar a planilha.');
  }

  final destino = File('exemplos/registro_mmc_teste_aprovado.xlsx');
  destino.writeAsBytesSync(bytes);

  print('Planilha de teste criada: ${destino.path}');
  print('$alteradas leituras simuladas. Original preservado.');
}
