import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class HistoricoView extends StatefulWidget {
  const HistoricoView({super.key});

  @override
  State<HistoricoView> createState() => _HistoricoViewState();
}

class _HistoricoViewState extends State<HistoricoView> {
  static final _url = Uri.parse(
    'https://yj7d8y9al3.execute-api.us-east-2.amazonaws.com/processar',
  );

  late Future<List<dynamic>> _historico;

  @override
  void initState() {
    super.initState();
    _historico = _carregar();
  }

  Future<List<dynamic>> _carregar() async {
    final resposta = await http.get(_url).timeout(const Duration(seconds: 30));
    final dados =
        jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    if (resposta.statusCode != 200) {
      throw Exception(dados['erro'] ?? 'Falha na consulta.');
    }
    return dados['historico'] as List<dynamic>? ?? [];
  }

  void _recarregar() {
    setState(() {
      _historico = _carregar();
    });
  }

  void _copiarCodigo(String codigo) {
    Clipboard.setData(ClipboardData(text: codigo));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Código $codigo copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _historico,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Não foi possível carregar o histórico: ${snapshot.error}',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _recarregar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final itens = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: () async {
            _recarregar();
            await _historico;
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Histórico de calibrações',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    tooltip: 'Atualizar histórico',
                    onPressed: _recarregar,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (itens.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhum certificado emitido.'),
                  ),
                ),
              ...itens.map((bruto) {
                final item = Map<String, dynamic>.from(bruto as Map);
                final resumo = Map<String, dynamic>.from(
                  item['resumo'] as Map? ?? {},
                );
                final codigo =
                    item['certificadoId']?.toString() ?? 'Sem código';
                final aprovado = resumo['parecer'] == 'APROVADO';

                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.description_outlined,
                      color: aprovado
                          ? AppTheme.verdeTexto
                          : AppTheme.vermelhoTexto,
                    ),
                    title: Row(
                      children: [
                        Text(
                          codigo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copiar código',
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => _copiarCodigo(codigo),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${item['dataEmissao'] ?? ''}\n${item['arquivoOrigem'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      resumo['parecer']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: aprovado
                            ? AppTheme.verdeTexto
                            : AppTheme.vermelhoTexto,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
