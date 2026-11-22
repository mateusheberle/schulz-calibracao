import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

class QrcodeView extends StatefulWidget {
  const QrcodeView({super.key});

  @override
  State<QrcodeView> createState() => _QrcodeViewState();
}

class _QrcodeViewState extends State<QrcodeView> {
  static final _url = Uri.parse(
    'https://yj7d8y9al3.execute-api.us-east-2.amazonaws.com/processar',
  );
  final _codigo = TextEditingController();
  Map<String, dynamic>? _certificado;
  String? _erro;
  bool _consultando = false;
  bool _cameraAtiva = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  String _extrairCodigo(String entrada) {
    final texto = entrada.trim();
    if (texto.startsWith('SCHULZ-CERT|')) {
      final partes = texto.split('|');
      if (partes.length >= 2) return partes[1].trim();
    }
    return texto;
  }

  Future<void> _consultar([String? valorLido]) async {
    final id = _extrairCodigo(valorLido ?? _codigo.text);
    if (id.isEmpty) {
      setState(() => _erro = 'Informe o código do certificado.');
      return;
    }

    _codigo.text = id;
    setState(() {
      _consultando = true;
      _cameraAtiva = false;
      _erro = null;
      _certificado = null;
    });

    try {
      final resposta = await http
          .get(_url.replace(queryParameters: {'id': id}))
          .timeout(const Duration(seconds: 30));
      final dados =
          jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;

      if (resposta.statusCode != 200 || dados['valido'] != true) {
        throw Exception(dados['erro'] ?? 'Certificado inválido.');
      }

      if (mounted) {
        setState(
          () => _certificado = Map<String, dynamic>.from(
            dados['certificado'] as Map,
          ),
        );
      }
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível validar o certificado: $erro');
      }
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificado = _certificado;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 52,
                    color: AppTheme.azulEscuro,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Validador de QR Code',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escaneie o QR Code com a câmera ou informe o código SCH-AAAA-XXXXXX.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _cameraAtiva = !_cameraAtiva),
                    icon: Icon(
                      _cameraAtiva ? Icons.videocam_off : Icons.qr_code_scanner,
                    ),
                    label: Text(
                      _cameraAtiva ? 'Fechar câmera' : 'Ler QR Code com câmera',
                    ),
                  ),
                  if (_cameraAtiva) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 260,
                      width: 320,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MobileScanner(
                          onDetect: (captura) {
                            final codigo = captura.barcodes.firstOrNull?.rawValue;
                            if (codigo != null && !_consultando) {
                              _consultar(codigo);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codigo,
                          onSubmitted: (_) => _consultar(),
                          decoration: const InputDecoration(
                            labelText: 'Código ou leitura do QR Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _consultando ? null : _consultar,
                        child: _consultando
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Validar'),
                      ),
                    ],
                  ),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _erro!,
                        style: const TextStyle(color: AppTheme.vermelhoTexto),
                      ),
                    ),
                  if (certificado != null) _resultado(certificado),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultado(Map<String, dynamic> certificado) {
    final resumo = Map<String, dynamic>.from(
      certificado['resumo'] as Map? ?? {},
    );
    final metadados = Map<String, dynamic>.from(
      certificado['metadados'] as Map? ?? {},
    );
    final aprovado = resumo['parecer'] == 'APROVADO';

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: aprovado ? AppTheme.verdeBg : AppTheme.vermelhoBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CERTIFICADO VÁLIDO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: aprovado ? AppTheme.verdeTexto : AppTheme.vermelhoTexto,
            ),
          ),
          const SizedBox(height: 8),
          Text('Código: ${certificado['certificadoId']}'),
          Text('Emissão: ${certificado['dataEmissao']}'),
          Text(
            'Instrumento: ${metadados['tagPatrimonial'] ?? '-'} — '
            '${metadados['denominacao'] ?? '-'}',
          ),
          Text('Arquivo de origem: ${certificado['arquivoOrigem'] ?? '-'}'),
          Text('Parecer: ${resumo['parecer']}'),
          Text('Hash: ${certificado['hashValidacao']}'),
        ],
      ),
    );
  }
}