import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QrcodeView extends StatefulWidget {
  const QrcodeView({this.resultado, super.key});

  final Map<String, dynamic>? resultado;

  @override
  State<QrcodeView> createState() => _QrcodeViewState();
}

class _QrcodeViewState extends State<QrcodeView> {
  final TextEditingController _codeController = TextEditingController();
  Map<dynamic, dynamic>? _pontoEncontrado;
  bool _buscaExecutada = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Map<dynamic, dynamic> _mapa(dynamic valor) =>
      valor is Map ? valor : const <dynamic, dynamic>{};

  String _normalizar(String valor) =>
      valor.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  void _validarRegistroLocal() {
    final consulta = _codeController.text.trim();
    if (consulta.isEmpty) {
      setState(() {
        _buscaExecutada = true;
        _pontoEncontrado = null;
      });
      return;
    }

    final pontosBrutos =
        widget.resultado?['pontos'] ?? widget.resultado?['caracteristicas'];
    final pontos = pontosBrutos is List ? pontosBrutos : const <dynamic>[];
    final chaveConsulta = _normalizar(consulta);
    Map<dynamic, dynamic>? encontrado;

    for (final item in pontos) {
      final ponto = _mapa(item);
      final chavePonto =
          ponto['caracteristica'] ??
          ponto['characteristic'] ??
          ponto['nome'] ??
          ponto['name'];
      if (chavePonto != null &&
          _normalizar(chavePonto.toString()) == chaveConsulta) {
        encontrado = ponto;
        break;
      }
    }

    setState(() {
      _buscaExecutada = true;
      _pontoEncontrado = encontrado;
    });
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
    return 'Não informado';
  }

  bool? _statusDoPonto(Map<dynamic, dynamic> ponto) {
    final status = (ponto['situacao'] ?? ponto['status'])
        ?.toString()
        .trim()
        .toUpperCase();
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

  Widget _buildResultadoLocal() {
    final ponto = _pontoEncontrado;
    if (!_buscaExecutada) return const SizedBox.shrink();

    if (_codeController.text.trim().isEmpty) {
      return _buildAviso(
        'Informe uma característica para consultar os dados da planilha carregada.',
      );
    }

    if (widget.resultado == null) {
      return _buildAviso(
        'Não há medições carregadas. Processe uma planilha na aba Ingestão para realizar uma consulta demonstrativa.',
      );
    }

    if (ponto == null) {
      return _buildAviso(
        'Nenhuma característica correspondente foi encontrada na planilha carregada. Esta consulta não pesquisa certificados emitidos.',
        erro: true,
      );
    }

    final situacao = _statusDoPonto(ponto);
    final cor = situacao == true
        ? AppTheme.verdeTexto
        : situacao == false
        ? AppTheme.vermelhoTexto
        : const Color(0xFF8A4B08);
    final fundo = situacao == true
        ? AppTheme.verdeBg
        : situacao == false
        ? AppTheme.vermelhoBg
        : const Color(0xFFFFF7E6);
    final nome =
        ponto['caracteristica'] ??
        ponto['characteristic'] ??
        ponto['nome'] ??
        ponto['name'] ??
        'Não identificada';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                situacao == true
                    ? Icons.check_circle_outline
                    : situacao == false
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline,
                color: cor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resultado local: ${situacao == true
                      ? 'DENTRO DA TOLERÂNCIA'
                      : situacao == false
                      ? 'FORA DA TOLERÂNCIA'
                      : 'STATUS INDISPONÍVEL'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Característica: $nome',
            style: TextStyle(color: cor, fontWeight: FontWeight.w600),
          ),
          Text(
            'Valor nominal: ${_formatarNumero(ponto['nominal'])}',
            style: TextStyle(color: cor),
          ),
          Text(
            'Média calculada: ${_formatarNumero(ponto['media'] ?? ponto['mean'])}',
            style: TextStyle(color: cor),
          ),
          Text(
            'Erro: ${_formatarNumero(ponto['erro'] ?? ponto['deviation'])}',
            style: TextStyle(color: cor),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta demonstrativa dos dados da planilha atual. Não confirma autenticidade, assinatura ou validade de certificado.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildAviso(String mensagem, {bool erro = false}) {
    final cor = erro ? AppTheme.vermelhoTexto : const Color(0xFF475569);
    final fundo = erro ? AppTheme.vermelhoBg : const Color(0xFFF1F5F9);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: erro ? AppTheme.vermelhoBorda : AppTheme.cinzaBorda,
        ),
      ),
      child: Text(mensagem, style: TextStyle(color: cor, height: 1.4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            elevation: 1,
            shadowColor: const Color(0x14002B49),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.cinzaBorda),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.azulEscuro.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 48,
                      color: AppTheme.azulEscuro,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Validador de QR Code',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.azulEscuro,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Consulte uma característica da planilha de calibração carregada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAviso(
                    'Modo demonstrativo: não há leitura por câmera nem serviço de consulta/autenticação de certificados conectado.',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cinzaBorda),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Consulta local demonstrativa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.azulEscuro,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final campo = TextField(
                              controller: _codeController,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText:
                                    'Nome da característica (ex.: Cota A)',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _validarRegistroLocal(),
                            );
                            final botao = FilledButton.icon(
                              onPressed: _validarRegistroLocal,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.azulEscuro,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('Consultar'),
                            );

                            if (constraints.maxWidth < 480) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  campo,
                                  const SizedBox(height: 10),
                                  botao,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: campo),
                                const SizedBox(width: 12),
                                botao,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_buscaExecutada) ...[
                    const SizedBox(height: 20),
                    _buildResultadoLocal(),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cinzaBorda),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF64748B),
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Uma consulta oficial por Tag/Hash exige um cadastro de certificados e um serviço de validação. Esses recursos ainda não estão disponíveis nesta aplicação.',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
