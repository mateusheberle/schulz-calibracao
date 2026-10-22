import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Dependências: file_picker 10.3.10 e http.
// Execute o Flutter em http://localhost:3000 (origem permitida pela API).
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calibração | Projeto Schulz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF174E80)),
        scaffoldBackgroundColor: const Color(0xFFF3F6FA),
      ),
      home: const CalibracaoPage(),
    );
  }
}

class CalibracaoPage extends StatefulWidget {
  const CalibracaoPage({super.key});

  @override
  State<CalibracaoPage> createState() => _CalibracaoPageState();
}

class _CalibracaoPageState extends State<CalibracaoPage> {
  static final _url = Uri.parse('http://127.0.0.1:8080/calibracoes/processar');
  static const _limite = 5 * 1024 * 1024;
  Uint8List? _bytes;
  String? _nome;
  String? _erro;
  Map<String, dynamic>? _resultado;
  bool _selecionando = false;
  bool _processando = false;
  final _rolagemTabela = ScrollController();
  http.Client? _cliente;

  bool get _ocupado => _selecionando || _processando;

  @override
  void dispose() {
    _cliente?.close();
    _rolagemTabela.dispose();
    super.dispose();
  }

  Future<void> _selecionar() async {
    if (_ocupado) return;
    setState(() => _selecionando = true);
    try {
      final selecao = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || selecao == null) return;
      final arquivo = selecao.files.single;
      final bytes = arquivo.bytes;
      String? erro;
      if (!arquivo.name.toLowerCase().endsWith('.xlsx')) {
        erro = 'Selecione uma planilha no formato .xlsx.';
      } else if (bytes == null || bytes.isEmpty) {
        erro = 'O arquivo está vazio ou não pôde ser lido.';
      } else if (arquivo.size > _limite || bytes.length > _limite) {
        erro = 'O arquivo deve ter no máximo 5 MiB.';
      }
      setState(() {
        _erro = erro;
        _resultado = null;
        _nome = erro == null ? arquivo.name : null;
        _bytes = erro == null ? bytes : null;
      });
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

  Future<void> _processar() async {
    final bytes = _bytes;
    if (_ocupado || bytes == null) return;
    setState(() {
      _processando = true;
      _erro = null;
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
                'Não foi possível processar a planilha (HTTP ${resposta.statusCode}).',
          );
        }
        return;
      }
      _validarResposta(dados);
      if (mounted) setState(() => _resultado = dados);
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
              'rodando na porta 8080 e se esta página está em http://localhost:3000.',
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

  String _numero(dynamic valor) =>
      (valor as num).toStringAsFixed(7).replaceAll('.', ',');

  Widget _indicador(String titulo, String valor, Color cor) => Container(
    width: 210,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo),
        const SizedBox(height: 8),
        Text(
          valor,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado;
    final resumo = resultado?['resumo'] as Map<String, dynamic>?;
    final pontos = resultado?['pontos'] as List?;
    return Scaffold(
      appBar: AppBar(title: const Text('Projeto Schulz | Calibração')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Análise de calibração',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Importe o registro MMC para avaliar as medições e suas tolerâncias.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Selecione a planilha',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Modelo Registro MMC • Excel .xlsx • Até 5 MiB',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _ocupado ? null : _selecionar,
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _selecionando
                                    ? 'Abrindo...'
                                    : 'Selecionar Excel',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _ocupado || _bytes == null
                                  ? null
                                  : _processar,
                              icon: const Icon(Icons.play_arrow),
                              label: Text(
                                _processando
                                    ? 'Processando...'
                                    : 'Processar planilha',
                              ),
                            ),
                          ],
                        ),
                        if (_nome != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Arquivo: $_nome',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (_processando) ...[
                          const SizedBox(height: 20),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          const Text('Aguarde a análise das medições...'),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFFFFE8E6),
                      child: Text(
                        _erro!,
                        style: const TextStyle(color: Color(0xFF9F2020)),
                      ),
                    ),
                  ),
                ],
                if (resumo != null && pontos != null) ...[
                  const SizedBox(height: 28),
                  const Text(
                    '2. Resultado da análise',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _indicador(
                        'Características',
                        '${resumo['total']}',
                        Colors.blueGrey,
                      ),
                      _indicador(
                        'Dentro da tolerância',
                        '${resumo['dentroDaTolerancia']}',
                        Colors.green.shade800,
                      ),
                      _indicador(
                        'Fora da tolerância',
                        '${resumo['foraDaTolerancia']}',
                        Colors.red.shade800,
                      ),
                      _indicador(
                        'Parecer final',
                        '${resumo['parecer']}',
                        resumo['parecer'] == 'APROVADO'
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Critério: ${resultado!['criterio']}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Valores em mm. Exibição com 7 casas decimais. '
                    'Role a tabela horizontalmente para ver todas as colunas.',
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Scrollbar(
                      controller: _rolagemTabela,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _rolagemTabela,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Característica')),
                            DataColumn(label: Text('Leitura 1'), numeric: true),
                            DataColumn(label: Text('Leitura 2'), numeric: true),
                            DataColumn(label: Text('Nominal'), numeric: true),
                            DataColumn(label: Text('Média'), numeric: true),
                            DataColumn(label: Text('Erro'), numeric: true),
                            DataColumn(
                              label: Text('Tol. inferior'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('Tol. superior'),
                              numeric: true,
                            ),
                            DataColumn(label: Text('Situação')),
                          ],
                          rows: pontos.map((ponto) {
                            final dentro =
                                ponto['situacao'] == 'DENTRO_DA_TOLERANCIA';
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(ponto['caracteristica'] as String),
                                ),
                                for (final chave in [
                                  'leitura1',
                                  'leitura2',
                                  'nominal',
                                  'media',
                                  'erro',
                                  'toleranciaInferior',
                                  'toleranciaSuperior',
                                ])
                                  DataCell(Text(_numero(ponto[chave]))),
                                DataCell(
                                  Text(
                                    dentro
                                        ? 'Dentro da tolerância'
                                        : 'Fora da tolerância',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: dentro
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
