import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../theme/app_theme.dart';

typedef ArquivoRecebidoCallback =
    void Function(String nome, Uint8List? bytes, int tamanho);

class IngestaoView extends StatefulWidget {
  const IngestaoView({
    required this.nomeArquivo,
    required this.erro,
    required this.selecionando,
    required this.processando,
    required this.arquivoSelecionado,
    required this.onSelecionar,
    required this.onProcessar,
    required this.onArquivoRecebido,
    super.key,
  });

  final String? nomeArquivo;
  final String? erro;
  final bool selecionando;
  final bool processando;
  final bool arquivoSelecionado;
  final VoidCallback onSelecionar;
  final VoidCallback onProcessar;
  final ArquivoRecebidoCallback onArquivoRecebido;

  @override
  State<IngestaoView> createState() => _IngestaoViewState();
}

class _IngestaoViewState extends State<IngestaoView> {
  DropzoneViewController? _dropzoneController;
  bool _arrastandoArquivo = false;
  bool _mouseSobre = false;
  String? _erroDrop;

  Future<void> _receberArquivoDrop(DropzoneFileInterface arquivo) async {
    final controller = _dropzoneController;
    if (controller == null) {
      setState(() => _erroDrop = 'A área de upload ainda não está pronta.');
      return;
    }

    try {
      final nome = await controller.getFilename(arquivo);
      final tamanho = await controller.getFileSize(arquivo);
      final bytes = await controller.getFileData(arquivo);
      if (!mounted) return;
      setState(() => _erroDrop = null);
      widget.onArquivoRecebido(nome, bytes, tamanho);
    } catch (_) {
      if (mounted) {
        setState(() => _erroDrop = 'Não foi possível ler o arquivo arrastado.');
      }
    }
  }

  void _setArrastando(bool valor) {
    if (_arrastandoArquivo != valor) {
      setState(() => _arrastandoArquivo = valor);
    }
  }

  void _setMouseSobre(bool valor) {
    if (_mouseSobre != valor) {
      setState(() => _mouseSobre = valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = widget.selecionando || widget.processando;
    final erro = _erroDrop ?? widget.erro;
    final emDestaque = _arrastandoArquivo || _mouseSobre;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingestão de Arquivo de Medição (MMC Carl Zeiss)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.azulEscuro,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: AppTheme.azulEscuro,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Upload do Relatório de Ensaio (.xlsx / .txt)',
                              style: TextStyle(
                                color: AppTheme.azulEscuro,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Dropzone Refinada
                      MouseRegion(
                        cursor: ocupado
                            ? SystemMouseCursors.forbidden
                            : SystemMouseCursors.click,
                        onEnter: (_) => _setMouseSobre(true),
                        onExit: (_) => _setMouseSobre(false),
                        child: GestureDetector(
                          onTap: ocupado ? null : widget.onSelecionar,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            height: 260,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _arrastandoArquivo
                                  ? const Color(0xFFFFF7ED) // Warm Orange Tint
                                  : _mouseSobre
                                  ? const Color(0xFFF8FAFC) // Soft Slate Tint
                                  : const Color(0xFFFAFCFE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: CustomPaint(
                              foregroundPainter: _BordaTracejada(
                                cor: _arrastandoArquivo
                                    ? AppTheme.laranjaSchulz
                                    : _mouseSobre
                                    ? AppTheme.azulMedio
                                    : const Color(0xFFCBD5E0),
                                raio: 10,
                                larguraLinha: emDestaque ? 2.0 : 1.5,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // HTML Dropzone Overlay (Apenas Web)
                                  if (kIsWeb)
                                    DropzoneView(
                                      operation: DragOperation.copy,
                                      cursor: CursorType.pointer,
                                      onCreated: (controller) {
                                        _dropzoneController = controller;
                                      },
                                      onHover: () => _setArrastando(true),
                                      onLeave: () => _setArrastando(false),
                                      onDropFile: (arquivo) {
                                        _setArrastando(false);
                                        _receberArquivoDrop(arquivo);
                                      },
                                      onError: (_) {
                                        _setArrastando(false);
                                        setState(() {
                                          _erroDrop =
                                              'Não foi possível receber o arquivo arrastado.';
                                        });
                                      },
                                    ),

                                  // Conteúdo Visual Fluido
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedScale(
                                            scale: emDestaque ? 1.08 : 1.0,
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            curve: Curves.easeOutBack,
                                            child: Icon(
                                              _arrastandoArquivo
                                                  ? Icons.file_download_outlined
                                                  : _mouseSobre
                                                  ? Icons.cloud_upload_outlined
                                                  : Icons.cloud_upload,
                                              color: _arrastandoArquivo
                                                  ? AppTheme.laranjaSchulz
                                                  : _mouseSobre
                                                  ? AppTheme.azulMedio
                                                  : AppTheme.laranjaSchulz,
                                              size: 46,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            style: TextStyle(
                                              color: _arrastandoArquivo
                                                  ? AppTheme.laranjaSchulz
                                                  : AppTheme.azulEscuro,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              fontFamily: 'Roboto',
                                            ),
                                            child: Text(
                                              widget.nomeArquivo ??
                                                  (_arrastandoArquivo
                                                      ? 'Solte o arquivo para adicioná-lo'
                                                      : 'Arraste e solte a planilha da MMC aqui'),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Compatível com saídas brutas da MMC Tag 500.011 • .xlsx ou .txt',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          FilledButton.icon(
                                            onPressed: ocupado
                                                ? null
                                                : widget.onSelecionar,
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.laranjaSchulz,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 14,
                                                  ),
                                              elevation: _mouseSobre ? 2 : 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.folder_open_outlined,
                                              size: 18,
                                            ),
                                            label: Text(
                                              widget.selecionando
                                                  ? 'Abrindo...'
                                                  : 'Selecionar Arquivo do Computador',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (widget.nomeArquivo != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.attach_file,
                                size: 20,
                                color: AppTheme.azulMedio,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Arquivo selecionado: ${widget.nomeArquivo}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.azulEscuro,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: ocupado ? null : widget.onProcessar,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.azulEscuro,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  widget.processando
                                      ? 'Processando...'
                                      : 'Processar arquivo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (widget.processando) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          color: AppTheme.laranjaSchulz,
                          backgroundColor: Color(0xFFFED7AA),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aguarde a análise das medições...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.azulEscuro,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Metadados do Instrumento Detectados',
                            style: TextStyle(
                              color: AppTheme.azulEscuro,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final colunas = constraints.maxWidth >= 760
                              ? 4
                              : constraints.maxWidth >= 480
                              ? 2
                              : 1;
                          final largura =
                              (constraints.maxWidth - (colunas - 1) * 20) /
                              colunas;
                          return Wrap(
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              _Metadado(
                                largura: largura,
                                rotulo: 'Tag Patrimonial:',
                                valor: widget.nomeArquivo == null
                                    ? 'Aguardando arquivo'
                                    : 'Será identificada no processamento',
                              ),
                              _Metadado(
                                largura: largura,
                                rotulo: 'Denominação:',
                                valor: 'Não identificada',
                              ),
                              _Metadado(
                                largura: largura,
                                rotulo: 'Setor Solicitante:',
                                valor: 'Não identificado',
                              ),
                              _Metadado(
                                largura: largura,
                                rotulo: 'Padrão Vinculado:',
                                valor: 'Não identificado',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (erro != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.vermelhoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.vermelhoBorda),
                    ),
                    child: Text(
                      erro,
                      style: const TextStyle(color: AppTheme.vermelhoTexto),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metadado extends StatelessWidget {
  const _Metadado({
    required this.largura,
    required this.rotulo,
    required this.valor,
  });

  final double largura;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largura,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: const TextStyle(color: Color(0xFF718096), fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              color: AppTheme.azulEscuro,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BordaTracejada extends CustomPainter {
  const _BordaTracejada({
    required this.cor,
    required this.raio,
    this.larguraLinha = 1.5,
  });

  final Color cor;
  final double raio;
  final double larguraLinha;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(raio)),
      );
    final paint = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = larguraLinha;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 7).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_BordaTracejada oldDelegate) =>
      oldDelegate.cor != cor ||
      oldDelegate.raio != raio ||
      oldDelegate.larguraLinha != larguraLinha;
}
