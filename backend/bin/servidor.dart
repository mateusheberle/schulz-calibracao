import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../lib/processador_calibracao.dart';

const limiteBytes = 5 * 1024 * 1024;
const origemFlutter = 'http://localhost:3000';

class FalhaHttp implements Exception {
  final int status;
  final String mensagem;
  const FalhaHttp(this.status, this.mensagem);
}

Future<void> responder(
  HttpRequest request,
  int status,
  Map<String, Object> dados,
) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(dados));
  await request.response.close();
}

Future<void> atender(HttpRequest request) async {
  final origem = request.headers.value('Origin');
  if (origem != null && origem != origemFlutter) {
    await responder(request, 403, {'erro': 'Origem não permitida.'});
    return;
  }
  if (origem == origemFlutter) {
    request.response.headers.set('Access-Control-Allow-Origin', origemFlutter);
    request.response.headers.set('Vary', 'Origin');
    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );
  }

  try {
    final caminho = request.uri.path;
    if (caminho != '/saude' && caminho != '/calibracoes/processar') {
      await responder(request, 404, {'erro': 'Rota não encontrada.'});
      return;
    }
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }
    final metodo = caminho == '/saude' ? 'GET' : 'POST';
    if (request.method != metodo) {
      request.response.headers.set('Allow', '$metodo, OPTIONS');
      await responder(request, 405, {'erro': 'Use o método $metodo.'});
      return;
    }
    if (caminho == '/saude') {
      await responder(request, 200, {'status': 'ok'});
      return;
    }

    // O corpo contém os bytes do Excel, não um formulário multipart.
    final tipo = request.headers.contentType?.mimeType;
    if (tipo != 'application/octet-stream' &&
        tipo !=
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      throw const FalhaHttp(
        415,
        'Envie o Excel como application/octet-stream.',
      );
    }
    if (request.headers.contentLength > limiteBytes) {
      throw const FalhaHttp(413, 'O arquivo deve ter no máximo 5 MiB.');
    }

    final buffer = BytesBuilder(copy: false);
    await for (final parte in request.timeout(const Duration(seconds: 30))) {
      if (buffer.length + parte.length > limiteBytes) {
        throw const FalhaHttp(413, 'O arquivo deve ter no máximo 5 MiB.');
      }
      buffer.add(parte);
    }
    if (buffer.length == 0) {
      throw const FalhaHttp(400, 'Nenhum arquivo recebido.');
    }

    final resultado = processarPlanilha(buffer.takeBytes());
    await responder(request, 200, resultado);
  } on FalhaHttp catch (erro) {
    await responder(request, erro.status, {'erro': erro.mensagem});
  } on FormatException catch (erro) {
    await responder(request, 422, {'erro': erro.message});
  } on TimeoutException {
    await responder(request, 408, {'erro': 'Tempo de envio excedido.'});
  } catch (erro, pilha) {
    stderr.writeln('$erro\n$pilha');
    await responder(request, 500, {'erro': 'Erro interno no processamento.'});
  }
}

Future<void> main() async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('API local: http://127.0.0.1:8080');
  print('Saúde: GET /saude');
  print('Excel: POST /calibracoes/processar');
  print('Flutter permitido: $origemFlutter');
  print('Para encerrar: Ctrl+C');
  await for (final request in servidor) {
    try {
      await atender(request);
    } catch (erro) {
      // Uma conexão encerrada pelo cliente não deve parar o servidor.
      stderr.writeln('Falha ao responder à conexão: $erro');
    }
  }
}
