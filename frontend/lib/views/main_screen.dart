import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import '../widgets/sidebar_widget.dart';
import 'historico_view.dart';
import 'ingestao_view.dart';
import 'qrcode_view.dart';
import 'revisao_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static final _url = Uri.parse('http://127.0.0.1:8080/calibracoes/processar');
  static const _limite = 5 * 1024 * 1024;

  Uint8List? _bytes;
  String? _nome;
  String? _erro;
  Map<String, dynamic>? _resultado;
  bool _selecionando = false;
  bool _processando = false;
  bool _gerandoPdf = false;
  String? _erroPdf;
  int _abaSelecionada = 0;
  http.Client? _cliente;

  bool get _ocupado => _selecionando || _processando;

  @override
  void dispose() {
    _cliente?.close();
    super.dispose();
  }

  Future<void> _selecionarArquivo() async {
    if (_ocupado) return;
    setState(() => _selecionando = true);
    try {
      final selecao = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'txt'],
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || selecao == null) return;

      final arquivo = selecao.files.single;
      _receberArquivo(arquivo.name, arquivo.bytes, arquivo.size);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = 'Não foi possível abrir o arquivo. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _selecionando = false);
    }
  }

  void _receberArquivo(String nome, Uint8List? bytes, int tamanho) {
    final extensao = nome.toLowerCase().split('.').last;
    String? erro;
    if (!['xlsx', 'txt'].contains(extensao)) {
      erro = 'Selecione um arquivo no formato .xlsx ou .txt.';
    } else if (bytes == null || bytes.isEmpty) {
      erro = 'O arquivo está vazio ou não pôde ser lido.';
    } else if (tamanho > _limite || bytes.length > _limite) {
      erro = 'O arquivo deve ter no máximo 5 MiB.';
    }

    setState(() {
      _erro = erro;
      _erroPdf = null;
      _resultado = null;
      _nome = erro == null ? nome : null;
      _bytes = erro == null ? bytes : null;
    });
  }

  Future<void> _processarPlanilha() async {
    final bytes = _bytes;
    if (_ocupado || bytes == null) return;
    if (_nome?.toLowerCase().endsWith('.txt') ?? false) {
      setState(
        () => _erro =
            'O arquivo .txt foi aceito, mas o processador atual analisa '
            'apenas planilhas .xlsx.',
      );
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
      _erroPdf = null;
      _resultado = null;
    });

    final cliente = http.Client();
    _cliente = cliente;
    try {
      final resposta = await cliente
          .post(
            _url,
            headers: {'Content-Type': 'application/octet-stream'},
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (dados is! Map<String, dynamic>) {
        throw const FormatException('Resposta inválida.');
      }
      if (resposta.statusCode != 200) {
        if (mounted) {
          setState(
            () => _erro =
                dados['erro']?.toString() ??
                'Não foi possível processar a planilha '
                    '(HTTP ${resposta.statusCode}).',
          );
        }
        return;
      }

      _validarResposta(dados);
      if (mounted) {
        setState(() {
          _resultado = dados;
          _abaSelecionada = 1;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _erro = 'O processamento demorou demais. Tente novamente.',
        );
      }
    } on http.ClientException {
      if (mounted) {
        setState(
          () => _erro =
              'Não foi possível acessar a API. Verifique se o backend está '
              'rodando na porta 8080 e se esta página está em '
              'http://localhost:3000.',
        );
      }
    } on FormatException {
      if (mounted) {
        setState(
          () => _erro = 'A API retornou uma resposta em formato inesperado.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = 'Falha ao processar o arquivo. Tente novamente.',
        );
      }
    } finally {
      cliente.close();
      _cliente = null;
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _gerarCertificadoPdf() async {
    final resultado = _resultado;
    if (_gerandoPdf || resultado == null) return;

    setState(() {
      _gerandoPdf = true;
      _erroPdf = null;
    });

    try {
      final documento = _criarDocumentoPdf(resultado);
      final bytes = await documento.save();
      final baseNome = (_nome ?? 'calibracao')
          .replaceAll(RegExp(r'\.[^.]+$'), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'rascunho_certificado_$baseNome.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rascunho PDF pronto para salvar ou compartilhar.'),
          ),
        );
      }
    } catch (erro, pilha) {
      debugPrint('Falha ao gerar rascunho do certificado: $erro\n$pilha');
      if (mounted) {
        setState(
          () => _erroPdf =
              'Não foi possível gerar ou abrir o PDF. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
  }

  pw.Document _criarDocumentoPdf(Map<String, dynamic> resultado) {
    final resumo = _pdfMap(resultado['resumo'] ?? resultado);
    final pontosBrutos = resultado['pontos'] ?? resultado['caracteristicas'];
    final pontos = pontosBrutos is List
        ? pontosBrutos.map(_pdfMap).toList()
        : <Map<dynamic, dynamic>>[];
    final parecer =
        _pdfObter(resumo, [
          'parecer',
          'parecerFinal',
          'situacaoGeral',
        ])?.toString().toUpperCase() ??
        'INDISPONÍVEL';
    final identificacao = _pdfMap(
      _pdfObter(resultado, ['identificacao', 'instrumento', 'metadados']),
    );
    final responsavel = _pdfMap(
      _pdfObter(resultado, ['responsavel', 'signatario', 'signatário']),
    );
    final tag = _pdfCampo(identificacao, resultado, [
      'tagPatrimonial',
      'tag_patrimonial',
      'tag',
      'assetTag',
    ]);
    final denominacao = _pdfCampo(identificacao, resultado, [
      'denominacao',
      'denominação',
      'descricaoInstrumento',
      'instrumentName',
    ]);
    final setor = _pdfCampo(identificacao, resultado, [
      'setorSolicitante',
      'setor_solicitante',
      'setor',
    ]);
    final signatario = _pdfCampo(responsavel, resultado, [
      'nome',
      'signatario',
      'signatário',
      'responsavel',
      'responsável',
    ]);
    final criterio =
        _pdfObter(resultado, ['criterio', 'criterioAvaliacao'])?.toString() ??
        'Tolerâncias inferior e superior, sem incerteza de medição.';

    final documento = pw.Document();
    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF002B49)),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SCHULZ S.A. | CERTIFICADO DE CALIBRACAO - RASCUNHO',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF002B49),
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'SEM VALIDADE OFICIAL',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFFE35205),
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 14),
          pw.Text(
            'Relatorio de calibracao',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            color: const PdfColor.fromInt(0xFFFFF3E0),
            child: pw.Text(
              'RASCUNHO PARA CONFERENCIA - NAO E UM CERTIFICADO OFICIAL. '
              'A API atual nao fornece todos os dados de identificacao e '
              'validacao do signatario.',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF8A4B08),
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFFE2E8F0),
            ),
            children: [
              _pdfLinha([
                'Tag patrimonial',
                'Denominacao',
                'Setor solicitante',
                'Responsavel / signatario',
                'Arquivo de origem',
              ], cabecalho: true),
              _pdfLinha([
                tag,
                denominacao,
                setor,
                signatario,
                _nome ?? 'Nao informado',
              ]),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Parecer: $parecer | Total: ${_pdfObter(resumo, ['total', 'totalCaracteristicas']) ?? pontos.length} '
            '| Dentro: ${_pdfObter(resumo, ['dentroDaTolerancia', 'dentro_da_tolerancia']) ?? '-'} '
            '| Fora: ${_pdfObter(resumo, ['foraDaTolerancia', 'fora_da_tolerancia']) ?? '-'}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Criterio: $criterio',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFFCBD5E0),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.6),
              1: const pw.FlexColumnWidth(0.9),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(0.9),
              4: const pw.FlexColumnWidth(0.9),
              5: const pw.FlexColumnWidth(0.9),
              6: const pw.FlexColumnWidth(0.9),
              7: const pw.FlexColumnWidth(0.9),
              8: const pw.FlexColumnWidth(1.2),
            },
            children: [
              _pdfLinha(const [
                'Caracteristica',
                'Leitura 1',
                'Leitura 2',
                'Nominal',
                'Media',
                'Erro',
                'Tol. inferior',
                'Tol. superior',
                'Status',
              ], cabecalho: true),
              for (final ponto in pontos)
                _pdfLinha([
                  _pdfObter(ponto, [
                        'caracteristica',
                        'characteristic',
                        'nome',
                      ])?.toString() ??
                      '-',
                  _pdfNumero(ponto, ['leitura1', 'leitura_1', 'actual1']),
                  _pdfNumero(ponto, ['leitura2', 'leitura_2', 'actual2']),
                  _pdfNumero(ponto, ['nominal']),
                  _pdfNumero(ponto, ['media', 'mean']),
                  _pdfNumero(ponto, ['erro', 'deviation']),
                  _pdfNumero(ponto, [
                    'toleranciaInferior',
                    'tolerancia_inferior',
                    'lowerTol',
                    'lower_tol',
                  ]),
                  _pdfNumero(ponto, [
                    'toleranciaSuperior',
                    'tolerancia_superior',
                    'upperTol',
                    'upper_tol',
                  ]),
                  _pdfSituacao(ponto),
                ]),
            ],
          ),
        ],
      ),
    );
    return documento;
  }

  pw.TableRow _pdfLinha(List<String> valores, {bool cabecalho = false}) {
    final corTexto = PdfColor.fromInt(cabecalho ? 0xFF002B49 : 0xFF263746);
    return pw.TableRow(
      decoration: cabecalho
          ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9))
          : null,
      children: [
        for (final valor in valores)
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              valor,
              style: pw.TextStyle(
                color: corTexto,
                fontSize: cabecalho ? 8 : 7.5,
                fontWeight: cabecalho
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  Map<dynamic, dynamic> _pdfMap(dynamic valor) =>
      valor is Map ? valor : const <dynamic, dynamic>{};

  dynamic _pdfObter(Map<dynamic, dynamic> mapa, List<String> chaves) {
    for (final chave in chaves) {
      final valor = mapa[chave];
      if (valor != null) return valor;
    }
    return null;
  }

  String _pdfCampo(
    Map<dynamic, dynamic> preferencial,
    Map<dynamic, dynamic> alternativa,
    List<String> chaves,
  ) {
    final valor =
        _pdfObter(preferencial, chaves) ?? _pdfObter(alternativa, chaves);
    final texto = valor?.toString().trim();
    return texto == null || texto.isEmpty ? 'Nao informado' : texto;
  }

  String _pdfNumero(Map<dynamic, dynamic> ponto, List<String> chaves) {
    final valor = _pdfObter(ponto, chaves);
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

  String _pdfSituacao(Map<dynamic, dynamic> ponto) {
    final status = _pdfObter(ponto, [
      'situacao',
      'status',
    ])?.toString().toUpperCase();
    if (status == 'DENTRO_DA_TOLERANCIA' ||
        status == 'DENTRO DA TOLERÂNCIA' ||
        status == 'OK') {
      return 'DENTRO DA TOLERANCIA';
    }
    if (status == 'FORA_DA_TOLERANCIA' ||
        status == 'FORA DA TOLERÂNCIA' ||
        status == 'NOK') {
      return 'FORA DA TOLERANCIA';
    }
    return 'NAO CLASSIFICADA';
  }

  void _validarResposta(Map<String, dynamic> dados) {
    final resumo = dados['resumo'];
    final pontos = dados['pontos'];
    if (resumo is! Map<String, dynamic> ||
        pontos is! List ||
        pontos.isEmpty ||
        dados['criterio'] is! String) {
      throw const FormatException('Resposta incompleta.');
    }
    for (final chave in ['total', 'dentroDaTolerancia', 'foraDaTolerancia']) {
      if (resumo[chave] is! int || (resumo[chave] as int) < 0) {
        throw const FormatException('Resumo inválido.');
      }
    }
    if (!['APROVADO', 'REPROVADO'].contains(resumo['parecer']) ||
        resumo['total'] != pontos.length ||
        resumo['total'] !=
            resumo['dentroDaTolerancia'] + resumo['foraDaTolerancia']) {
      throw const FormatException('Resumo inconsistente.');
    }
    for (final ponto in pontos) {
      if (ponto is! Map<String, dynamic> ||
          ponto['caracteristica'] is! String ||
          ![
            'DENTRO_DA_TOLERANCIA',
            'FORA_DA_TOLERANCIA',
          ].contains(ponto['situacao'])) {
        throw const FormatException('Ponto inválido.');
      }
      for (final chave in [
        'leitura1',
        'leitura2',
        'nominal',
        'media',
        'erro',
        'toleranciaInferior',
        'toleranciaSuperior',
      ]) {
        final valor = ponto[chave];
        if (valor is! num || !valor.isFinite) {
          throw const FormatException('Valor numérico inválido.');
        }
      }
    }
  }

  Widget _conteudoDaAba() {
    switch (_abaSelecionada) {
      case 0:
        return IngestaoView(
          nomeArquivo: _nome,
          erro: _erro,
          selecionando: _selecionando,
          processando: _processando,
          arquivoSelecionado: _bytes != null,
          onSelecionar: _selecionarArquivo,
          onProcessar: _processarPlanilha,
          onArquivoRecebido: _receberArquivo,
        );
      case 1:
        return RevisaoView(
          resultado: _resultado,
          nomeArquivo: _nome,
          gerandoPdf: _gerandoPdf,
          erroPdf: _erroPdf,
          onGerarPdf: _gerarCertificadoPdf,
        );
      case 2:
        return QrcodeView(resultado: _resultado);
      case 3:
        return const HistoricoView();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ampla = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: AppTheme.cinzaFundo,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildHeader(context),
      ),
      bottomNavigationBar: ampla
          ? null
          : SidebarWidget(
              selectedIndex: _abaSelecionada,
              onDestinationSelected: (index) {
                setState(() => _abaSelecionada = index);
              },
              compact: true,
            ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (ampla)
                  SidebarWidget(
                    selectedIndex: _abaSelecionada,
                    onDestinationSelected: (index) {
                      setState(() => _abaSelecionada = index);
                    },
                  ),
                if (ampla)
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppTheme.cinzaBorda,
                  ),
                Expanded(child: _conteudoDaAba()),
              ],
            ),
          ),
          Container(
            height: 40,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.cinzaBorda)),
            ),
            child: const Text(
              'SCHULZ S.A. - Planta Joinville/SC | Projeto Aplicado III - UniSENAI Digital (Equipe nº 03)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718096), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final exibirLaboratorio = largura >= 720;
    final exibirPerfil = largura >= 560;

    return Container(
      color: AppTheme.azulEscuro,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'SCHULZ ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'S.A.',
                        style: TextStyle(color: AppTheme.laranjaSchulz),
                      ),
                    ],
                  ),
                ),
                if (exibirLaboratorio) ...[
                  const SizedBox(width: 16),
                  Container(height: 24, width: 1, color: Colors.white30),
                  const SizedBox(width: 16),
                  const Flexible(
                    child: Text(
                      'Laboratório Central de Metrologia',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (exibirPerfil) ...[
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'João Carlos Oliveira',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Signatário Autorizado',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.laranjaSchulz,
              child: Text(
                'JC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
