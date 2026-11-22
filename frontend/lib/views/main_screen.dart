import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  static final _url = Uri.parse(
    'https://yj7d8y9al3.execute-api.us-east-2.amazonaws.com/processar',
  );
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
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'file': base64Encode(bytes),
              'fileName': _nome ?? 'Registro_MMC.xlsx',
            }),
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
              'Não foi possível conectar ao servidor da AWS. '
              'Verifique sua conexão com a internet.',
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
      final pdfBase64 = resultado['pdfBase64']?.toString();
      final certificadoId = resultado['certificadoId']?.toString();
      if (pdfBase64 == null ||
          pdfBase64.isEmpty ||
          certificadoId == null ||
          certificadoId.isEmpty) {
        throw const FormatException(
          'A API não retornou o certificado oficial.',
        );
      }
      await Printing.sharePdf(
        bytes: base64Decode(pdfBase64),
        filename: 'Certificado_$certificadoId.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificado oficial pronto para baixar.'),
          ),
        );
      }
    } catch (erro, pilha) {
      debugPrint('Falha ao baixar certificado oficial: $erro\n$pilha');
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
        return const QrcodeView();
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
