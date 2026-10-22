import 'package:excel/excel.dart';

// Modelo Registro MMC: duas leituras por característica.
// Comparação inclusiva com tolerâncias, sem incerteza de medição.
class Medicao {
  final double leitura;
  final double nominal;
  final double toleranciaSuperior;
  final double toleranciaInferior;

  const Medicao({
    required this.leitura,
    required this.nominal,
    required this.toleranciaSuperior,
    required this.toleranciaInferior,
  });
}

double lerNumero(CellValue? valor, String local) {
  final double numero;
  if (valor is IntCellValue) {
    numero = valor.value.toDouble();
  } else if (valor is DoubleCellValue) {
    numero = valor.value;
  } else {
    throw FormatException('$local: esperado um número, encontrado "$valor".');
  }
  if (!numero.isFinite) {
    throw FormatException('$local: número inválido.');
  }
  return numero;
}

bool estaDentroDaTolerancia({
  required double erro,
  required double limiteInferior,
  required double limiteSuperior,
}) {
  // Margem computacional do double; não é uma tolerância metrológica.
  const epsilon = 1e-12;
  return erro >= limiteInferior - epsilon && erro <= limiteSuperior + epsilon;
}

Map<String, Object> processarPlanilha(List<int> bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException(
      'Não foi possível abrir o Excel. Envie um arquivo .xlsx válido.',
    );
  }
  final aba = excel.tables['Report'];
  if (aba == null) {
    throw const FormatException('A planilha precisa conter a aba "Report".');
  }

  final linhas = aba.rows;
  const cabecalhoEsperado = [
    'Characteristic',
    'Actual',
    'Nominal',
    'Upper Tol',
    'Lower Tol',
    'Deviation',
  ];
  if (linhas.length < 13) {
    throw const FormatException('Planilha sem o cabeçalho esperado.');
  }
  final cabecalho = linhas[12];
  for (var coluna = 0; coluna < cabecalhoEsperado.length; coluna++) {
    final texto = coluna < cabecalho.length
        ? cabecalho[coluna]?.value?.toString().trim()
        : null;
    if (texto != cabecalhoEsperado[coluna]) {
      throw FormatException(
        'Cabeçalho inválido na coluna ${coluna + 1}. '
        'Esperado: ${cabecalhoEsperado[coluna]}.',
      );
    }
  }

  final pontos = <String, List<Medicao>>{};
  for (var indice = 13; indice < linhas.length; indice++) {
    final linha = linhas[indice];
    final numeroLinha = indice + 1;
    if (linha.every((celula) => celula?.value == null)) continue;
    if (linha.length < 5) {
      throw FormatException('Linha $numeroLinha incompleta.');
    }
    final nomeCelula = linha[0]?.value;
    if (nomeCelula is! TextCellValue) {
      throw FormatException(
        'Linha $numeroLinha: nome da característica inválido.',
      );
    }
    final nome = nomeCelula.value.toString().trim();
    if (nome.isEmpty) {
      throw FormatException('Linha $numeroLinha: característica sem nome.');
    }
    final medicao = Medicao(
      leitura: lerNumero(linha[1]?.value, 'B$numeroLinha'),
      nominal: lerNumero(linha[2]?.value, 'C$numeroLinha'),
      toleranciaSuperior: lerNumero(linha[3]?.value, 'D$numeroLinha'),
      toleranciaInferior: lerNumero(linha[4]?.value, 'E$numeroLinha'),
    );
    if (medicao.toleranciaInferior > medicao.toleranciaSuperior) {
      throw FormatException('Linha $numeroLinha: tolerâncias invertidas.');
    }
    pontos.putIfAbsent(nome, () => []).add(medicao);
  }
  if (pontos.isEmpty) {
    throw const FormatException('Nenhuma medição encontrada.');
  }

  // Valida toda a entrada antes de emitir resultados.
  for (final entrada in pontos.entries) {
    final medicoes = entrada.value;
    if (medicoes.length != 2) {
      throw FormatException(
        '${entrada.key}: esperadas 2 leituras, '
        'encontradas ${medicoes.length}.',
      );
    }
    final primeira = medicoes[0];
    final segunda = medicoes[1];
    if (primeira.nominal != segunda.nominal ||
        primeira.toleranciaSuperior != segunda.toleranciaSuperior ||
        primeira.toleranciaInferior != segunda.toleranciaInferior) {
      throw FormatException(
        '${entrada.key}: nominal ou tolerâncias diferentes entre as leituras.',
      );
    }
    final media = (primeira.leitura + segunda.leitura) / 2;
    if (!media.isFinite || !(media - primeira.nominal).isFinite) {
      throw FormatException('${entrada.key}: resultado numérico inválido.');
    }
  }

  final resultados = <Map<String, Object>>[];
  var pontosDentro = 0;
  var pontosFora = 0;
  for (final entrada in pontos.entries) {
    final primeira = entrada.value[0];
    final segunda = entrada.value[1];
    final media = (primeira.leitura + segunda.leitura) / 2;
    // Recalcula o erro; não utiliza o desvio pré-calculado da coluna F.
    final erro = media - primeira.nominal;
    final dentro = estaDentroDaTolerancia(
      erro: erro,
      limiteInferior: primeira.toleranciaInferior,
      limiteSuperior: primeira.toleranciaSuperior,
    );
    if (dentro) {
      pontosDentro++;
    } else {
      pontosFora++;
    }
    final situacao = dentro ? 'DENTRO_DA_TOLERANCIA' : 'FORA_DA_TOLERANCIA';

    resultados.add({
      'caracteristica': entrada.key,
      'leitura1': primeira.leitura,
      'leitura2': segunda.leitura,
      'nominal': primeira.nominal,
      'media': media,
      'erro': erro,
      'toleranciaInferior': primeira.toleranciaInferior,
      'toleranciaSuperior': primeira.toleranciaSuperior,
      'situacao': situacao,
    });
  }

  return {
    'criterio': 'Tolerâncias inferior e superior, sem incerteza de medição.',
    'resumo': {
      'total': pontos.length,
      'dentroDaTolerancia': pontosDentro,
      'foraDaTolerancia': pontosFora,
      'parecer': pontosFora == 0 ? 'APROVADO' : 'REPROVADO',
    },
    'pontos': resultados,
  };
}
