import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/parecer_banner.dart';

class RevisaoView extends StatefulWidget {
  const RevisaoView({
    required this.resultado,
    this.nomeArquivo,
    this.gerandoPdf = false,
    this.erroPdf,
    this.onGerarPdf,
    super.key,
  });

  final Map<String, dynamic>? resultado;
  final String? nomeArquivo;
  final bool gerandoPdf;
  final String? erroPdf;
  final Future<void> Function()? onGerarPdf;

  @override
  State<RevisaoView> createState() => _RevisaoViewState();
}

class _RevisaoViewState extends State<RevisaoView> {
  final _rolagemTabela = ScrollController();

  @override
  void dispose() {
    _rolagemTabela.dispose();
    super.dispose();
  }

  Map<dynamic, dynamic> _mapa(dynamic valor) =>
      valor is Map ? valor : const <dynamic, dynamic>{};

  dynamic _obterValor(Map<dynamic, dynamic> mapa, List<String> chaves) {
    for (final chave in chaves) {
      final valor = mapa[chave];
      if (valor != null) return valor;
    }
    return null;
  }

  String _textoCampo(
    Map<dynamic, dynamic> resultado,
    Map<dynamic, dynamic> identificacao,
    List<String> chaves,
  ) {
    final valor =
        _obterValor(identificacao, chaves) ?? _obterValor(resultado, chaves);
    final texto = valor?.toString().trim();
    return texto == null || texto.isEmpty ? 'Não informado' : texto;
  }

  String _formatarNumero(dynamic valor) {
    if (valor is num && valor.isFinite) {
      return valor.toStringAsFixed(7).replaceAll('.', ',');
    }
    if (valor is String) {
      final numero = num.tryParse(valor.trim().replaceAll(',', '.'));
      if (numero != null && numero.isFinite) {
        return numero.toStringAsFixed(7).replaceAll('.', ',');
      }
    }
    return '-';
  }

  String _formatarContagem(dynamic valor, int fallback) {
    if (valor is int && valor >= 0) return '$valor';
    if (valor is num && valor.isFinite && valor >= 0) {
      return valor.toInt().toString();
    }
    return '$fallback';
  }

  bool? _statusDoPonto(Map<dynamic, dynamic> ponto) {
    final status = _obterValor(ponto, [
      'situacao',
      'status',
    ])?.toString().trim().toUpperCase();
    if (status == 'DENTRO_DA_TOLERANCIA' ||
        status == 'DENTRO DA TOLERÂNCIA' ||
        status == 'OK') {
      return true;
    }
    if (status == 'FORA_DA_TOLERANCIA' ||
        status == 'FORA DA TOLERÂNCIA' ||
        status == 'NOK') {
      return false;
    }
    return null;
  }

  Widget _buildIndicadorCard({
    required String titulo,
    required String valor,
    required Color corTexto,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cinzaBorda),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: corTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampo(String titulo, String valor) {
    return SizedBox(
      width: 240,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              valor,
              style: const TextStyle(
                color: AppTheme.azulEscuro,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultado = widget.resultado;
    final resumo = _mapa(resultado?['resumo'] ?? resultado);
    final valoresPontos = resultado?['pontos'] ?? resultado?['caracteristicas'];
    final pontos = valoresPontos is List ? valoresPontos : const <dynamic>[];

    if (resultado == null || pontos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.azulEscuro.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  size: 56,
                  color: AppTheme.azulMedio,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'A revisão aparecerá aqui',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.azulEscuro,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Envie uma planilha MMC na aba Ingestão para consultar as cotas e o parecer metrológico.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final resumoParecer = _obterValor(resumo, [
      'parecer',
      'parecerFinal',
      'situacaoGeral',
    ])?.toString().trim().toUpperCase();
    final statusPontos = pontos
        .map((item) => _statusDoPonto(_mapa(item)))
        .toList();
    final parecer = resumoParecer == 'APROVADO' || resumoParecer == 'REPROVADO'
        ? resumoParecer
        : statusPontos.every((status) => status != null)
        ? (statusPontos.every((status) => status == true)
              ? 'APROVADO'
              : 'REPROVADO')
        : null;
    final dentroCalculado = statusPontos
        .where((status) => status == true)
        .length;
    final foraCalculado = statusPontos
        .where((status) => status == false)
        .length;
    final total = _formatarContagem(
      _obterValor(resumo, ['total', 'totalCaracteristicas', 'quantidade']),
      pontos.length,
    );
    final dentroTolerancia = _formatarContagem(
      _obterValor(resumo, [
        'dentroDaTolerancia',
        'dentro_da_tolerancia',
        'conformes',
      ]),
      dentroCalculado,
    );
    final foraTolerancia = _formatarContagem(
      _obterValor(resumo, [
        'foraDaTolerancia',
        'fora_da_tolerancia',
        'naoConformes',
      ]),
      foraCalculado,
    );

    final identificacao = _mapa(
      _obterValor(resultado, ['identificacao', 'instrumento', 'metadados']),
    );
    final responsavel = _mapa(
      _obterValor(resultado, ['responsavel', 'signatario', 'signatário']),
    );
    final tag = _textoCampo(resultado, identificacao, [
      'tagPatrimonial',
      'tag_patrimonial',
      'tag',
      'assetTag',
    ]);
    final denominacao = _textoCampo(resultado, identificacao, [
      'denominacao',
      'denominação',
      'descricaoInstrumento',
      'instrumentName',
    ]);
    final setor = _textoCampo(resultado, identificacao, [
      'setorSolicitante',
      'setor_solicitante',
      'setor',
    ]);
    final signatario = _textoCampo(resultado, responsavel, [
      'nome',
      'signatario',
      'signatário',
      'responsavel',
      'responsável',
    ]);

    final criterio =
        _obterValor(resultado, ['criterio', 'criterioAvaliacao'])?.toString() ??
        'Tolerâncias inferior e superior, sem incerteza de medição.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revisão das cotas',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.azulEscuro,
                                fontSize: 24,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Confira os resultados calculados para cada característica.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onGerarPdf != null) ...[
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: widget.gerandoPdf ? null : widget.onGerarPdf,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.azulEscuro,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: widget.gerandoPdf
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(
                        widget.gerandoPdf
                            ? 'Gerando PDF...'
                            : 'Baixar PDF (Rascunho)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.erroPdf != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.vermelhoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.vermelhoBorda),
                    ),
                    child: Text(
                      widget.erroPdf!,
                      style: const TextStyle(color: AppTheme.vermelhoTexto),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: AppTheme.azulEscuro,
                            size: 19,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Identificação do instrumento e ensaio',
                            style: TextStyle(
                              color: AppTheme.azulEscuro,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          _buildCampo(
                            'Arquivo de origem',
                            widget.nomeArquivo ?? 'Não informado',
                          ),
                          _buildCampo('Tag patrimonial', tag),
                          _buildCampo('Denominação', denominacao),
                          _buildCampo('Setor solicitante', setor),
                          _buildCampo('Responsável / signatário', signatario),
                        ],
                      ),
                      const Text(
                        'Rascunho: os metadados e o signatário não são fornecidos pela API atual. Este documento não tem validade oficial.',
                        style: TextStyle(
                          color: Color(0xFF8A4B08),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (parecer != null)
                ParecerBanner(isAprovado: parecer == 'APROVADO')
              else
                const Card(
                  color: Color(0xFFFFF7E6),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Parecer indisponível: os dados não informam um parecer geral nem classificam todas as cotas.',
                      style: TextStyle(color: Color(0xFF8A4B08)),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildIndicadorCard(
                    titulo: 'Características',
                    valor: total,
                    corTexto: AppTheme.azulEscuro,
                  ),
                  _buildIndicadorCard(
                    titulo: 'Dentro da tolerância',
                    valor: dentroTolerancia,
                    corTexto: AppTheme.verdeTexto,
                  ),
                  _buildIndicadorCard(
                    titulo: 'Fora da tolerância',
                    valor: foraTolerancia,
                    corTexto: AppTheme.vermelhoTexto,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Critério: $criterio',
                style: const TextStyle(
                  color: AppTheme.azulEscuro,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Valores em mm. Exibição com 7 casas decimais. Role a tabela horizontalmente para ver todas as colunas.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppTheme.cinzaBorda),
                ),
                clipBehavior: Clip.antiAlias,
                color: Colors.white,
                child: Scrollbar(
                  controller: _rolagemTabela,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _rolagemTabela,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8FAFC),
                      ),
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 52,
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.azulEscuro,
                        fontSize: 14,
                      ),
                      columns: const [
                        DataColumn(label: Text('Característica')),
                        DataColumn(label: Text('Leitura 1'), numeric: true),
                        DataColumn(label: Text('Leitura 2'), numeric: true),
                        DataColumn(label: Text('Nominal'), numeric: true),
                        DataColumn(label: Text('Média'), numeric: true),
                        DataColumn(label: Text('Erro'), numeric: true),
                        DataColumn(label: Text('Tol. inferior'), numeric: true),
                        DataColumn(label: Text('Tol. superior'), numeric: true),
                        DataColumn(label: Text('Situação')),
                      ],
                      rows: pontos.map((dynamic item) {
                        final ponto = _mapa(item);
                        final dentro = _statusDoPonto(ponto);
                        final caracteristica =
                            _obterValor(ponto, [
                              'caracteristica',
                              'characteristic',
                              'nome',
                            ]) ??
                            '-';
                        final l1 = _obterValor(ponto, [
                          'leitura1',
                          'leitura_1',
                          'actual1',
                        ]);
                        final l2 = _obterValor(ponto, [
                          'leitura2',
                          'leitura_2',
                          'actual2',
                        ]);
                        final nominal = _obterValor(ponto, ['nominal']);
                        final media = _obterValor(ponto, ['media', 'mean']);
                        final erroVal = _obterValor(ponto, [
                          'erro',
                          'deviation',
                        ]);
                        final tolInf = _obterValor(ponto, [
                          'toleranciaInferior',
                          'lowerTol',
                          'lower_tol',
                          'tolerancia_inferior',
                        ]);
                        final tolSup = _obterValor(ponto, [
                          'toleranciaSuperior',
                          'upperTol',
                          'upper_tol',
                          'tolerancia_superior',
                        ]);

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '$caracteristica',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.azulEscuro,
                                ),
                              ),
                            ),
                            DataCell(Text(_formatarNumero(l1))),
                            DataCell(Text(_formatarNumero(l2))),
                            DataCell(Text(_formatarNumero(nominal))),
                            DataCell(Text(_formatarNumero(media))),
                            DataCell(Text(_formatarNumero(erroVal))),
                            DataCell(Text(_formatarNumero(tolInf))),
                            DataCell(Text(_formatarNumero(tolSup))),
                            DataCell(
                              Text(
                                dentro == true
                                    ? 'Dentro da tolerância'
                                    : dentro == false
                                    ? 'Fora da tolerância'
                                    : 'Não classificada',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: dentro == true
                                      ? AppTheme.verdeTexto
                                      : dentro == false
                                      ? AppTheme.vermelhoTexto
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
