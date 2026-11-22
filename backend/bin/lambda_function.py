"""AWS Lambda: emissão, persistência e validação de certificados Schulz."""

import base64
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import hashlib
import io
import json
import uuid
import zipfile

import boto3
import pandas as pd
from reportlab.graphics.barcode import qr
from reportlab.graphics.shapes import Drawing
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

FUSO_BR = timezone(timedelta(hours=-3))
dynamodb = boto3.resource('dynamodb', region_name='us-east-2')
tabela_certificados = dynamodb.Table('SchulzCertificados')


class DecimalEncoder(json.JSONEncoder):

  def default(self, obj):
    return float(obj) if isinstance(obj, Decimal) else super().default(obj)


def para_dynamodb(valor):
  if isinstance(valor, float):
    return Decimal(str(round(valor, 7)))
  if isinstance(valor, dict):
    return {k: para_dynamodb(v) for k, v in valor.items()}
  if isinstance(valor, list):
    return [para_dynamodb(v) for v in valor]
  return valor


def normalizar_codigo_certificado(valor):
  codigo = (valor or '').strip()
  if codigo.startswith('SCHULZ-CERT|'):
    partes = codigo.split('|')
    if len(partes) >= 2:
      return partes[1].strip()
  return codigo


def reparar_xlsx(conteudo):
  entrada, saida = io.BytesIO(conteudo), io.BytesIO()
  try:
    with (
        zipfile.ZipFile(entrada) as origem,
        zipfile.ZipFile(saida, 'w') as destino,
    ):
      for arquivo in origem.infolist():
        dados = origem.read(arquivo.filename)
        if arquivo.filename.endswith('.xml'):
          dados = (
              dados.decode('utf-8', 'ignore')
              .replace(
                  'http://purl.oclc.org/oai/openxmlformats/',
                  'http://schemas.openxmlformats.org/',
              )
              .encode('utf-8')
          )
        destino.writestr(arquivo, dados)
    saida.seek(0)
    return saida
  except zipfile.BadZipFile:
    entrada.seek(0)
    return entrada


def criar_qr_drawing(payload, tamanho=26 * mm):
  widget = qr.QrCodeWidget(payload)
  x0, y0, x1, y1 = widget.getBounds()
  largura, altura = x1 - x0, y1 - y0
  desenho = Drawing(
      tamanho,
      tamanho,
      transform=[tamanho / largura, 0, 0, tamanho / altura, 0, 0],
  )
  desenho.add(widget)
  return desenho


def gerar_pdf(certificado, payload_qr):
  buffer = io.BytesIO()
  doc = SimpleDocTemplate(
      buffer,
      pagesize=A4,
      leftMargin=15 * mm,
      rightMargin=15 * mm,
      topMargin=15 * mm,
      bottomMargin=15 * mm,
  )
  estilos = getSampleStyleSheet()
  titulo = ParagraphStyle(
      'titulo',
      parent=estilos['Heading1'],
      fontSize=15,
      textColor=colors.HexColor('#0B2545'),
  )
  secao = ParagraphStyle(
      'secao',
      parent=estilos['Heading2'],
      fontSize=11,
      textColor=colors.HexColor('#0B2545'),
      spaceBefore=8,
      spaceAfter=4,
  )
  texto = ParagraphStyle(
      'texto',
      parent=estilos['Normal'],
      fontSize=8.5,
      textColor=colors.HexColor('#4A5568'),
  )

  meta, resumo = certificado['metadados'], certificado['resumo']
  cabecalho = [
      Paragraph(
          '<b>SCHULZ S.A. — Laboratório Central de Metrologia</b>', titulo
      ),
      Paragraph(
          f"<b>Certificado de Calibração nº {certificado['certificadoId']}</b><br/>"
          f"Emissão: {certificado['dataEmissao']}<br/>"
          f"Hash: {certificado['hashValidacao'][:24]}...",
          texto,
      ),
  ]
  topo = Table(
      [[cabecalho, criar_qr_drawing(payload_qr)]],
      colWidths=[150 * mm, 30 * mm],
  )
  topo.setStyle(
      TableStyle([
          ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
          ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
          ('LINEBELOW', (0, 0), (-1, 0), 1.5, colors.HexColor('#0B2545')),
      ])
  )

  identificacao = [
      [
          'Tag Patrimonial:',
          meta['tagPatrimonial'],
          'Setor:',
          meta['setorSolicitante'],
      ],
      [
          'Denominação:',
          meta['denominacao'],
          'Padrão:',
          meta['padraoVinculado'],
      ],
      [
          'Procedimento:',
          'ITL-0026 (Rev. 2) — Temp. Ref. 20°C',
          'Incerteza:',
          '0,002 mm',
      ],
  ]
  tabela_meta = Table(
      identificacao, colWidths=[35 * mm, 55 * mm, 38 * mm, 52 * mm]
  )
  tabela_meta.setStyle(
      TableStyle([
          ('FONTSIZE', (0, 0), (-1, -1), 8),
          ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
          ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),
          ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F7FAFC')),
          ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E0')),
          ('PADDING', (0, 0), (-1, -1), 4),
      ])
  )

  aprovado = resumo['parecer'] == 'APROVADO'
  cor = colors.HexColor('#22543D' if aprovado else '#822727')
  banner = Table(
      [[f"PARECER FINAL: INSTRUMENTO {resumo['parecer']}"]], colWidths=[180 * mm]
  )
  banner.setStyle(
      TableStyle([
          (
              'BACKGROUND',
              (0, 0),
              (-1, -1),
              colors.HexColor('#C6F6D5' if aprovado else '#FED7D7'),
          ),
          ('TEXTCOLOR', (0, 0), (-1, -1), cor),
          ('FONTNAME', (0, 0), (-1, -1), 'Helvetica-Bold'),
          ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
          ('BOX', (0, 0), (-1, -1), 1, cor),
          ('PADDING', (0, 0), (-1, -1), 6),
      ])
  )

  linhas = [[
      'Característica',
      'Nominal',
      'Média',
      'Erro',
      'Tol. Inf.',
      'Tol. Sup.',
      'Situação',
  ]]
  for ponto in certificado['pontos']:
    linhas.append([
        ponto['caracteristica'][:26],
        *(
            f'{ponto[c]:.4f}'
            for c in [
                'nominal',
                'media',
                'erro',
                'toleranciaInferior',
                'toleranciaSuperior',
            ]
        ),
        (
            'APROVADO'
            if ponto['situacao'] == 'DENTRO_DA_TOLERANCIA'
            else 'FORA TOL.'
        ),
    ])

  medidas = Table(
      linhas,
      colWidths=[48 * mm, 21 * mm, 23 * mm, 21 * mm, 21 * mm, 21 * mm, 25 * mm],
      repeatRows=1,
  )
  estilo = [
      ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#0B2545')),
      ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
      ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
      ('FONTSIZE', (0, 0), (-1, -1), 7.5),
      ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#CBD5E0')),
      ('PADDING', (0, 0), (-1, -1), 3.5),
      ('ALIGN', (1, 1), (-2, -1), 'RIGHT'),
      ('ALIGN', (-1, 1), (-1, -1), 'CENTER'),
  ]
  for indice, ponto in enumerate(certificado['pontos'], 1):
    cor_status = (
        '#2F855A'
        if ponto['situacao'] == 'DENTRO_DA_TOLERANCIA'
        else '#C53030'
    )
    estilo.append(
        ('TEXTCOLOR', (-1, indice), (-1, indice), colors.HexColor(cor_status))
    )
  medidas.setStyle(TableStyle(estilo))

  elementos = [
      topo,
      Spacer(1, 5 * mm),
      Paragraph('1. Identificação do Instrumento', secao),
      tabela_meta,
      Spacer(1, 5 * mm),
      banner,
      Spacer(1, 5 * mm),
      Paragraph('2. Resultados das Medições (mm)', secao),
      medidas,
      Spacer(1, 8 * mm),
      Paragraph(
          f"<b>Signatário Autorizado:</b> {meta['signatario']}<br/>"
          '<i>Documento assinado eletronicamente. Valide pelo QR Code ou'
          f" informe <b>{certificado['certificadoId']}</b> no Validador"
          ' Web.</i>',
          texto,
      ),
  ]
  doc.build(elementos)
  return buffer.getvalue()


def extrair_arquivo(body):
  if isinstance(body, bytes):
    return body, 'Registro_MMC.xlsx'
  texto = (body or '').strip()
  if texto.startswith('{'):
    dados = json.loads(texto)
    nome = (
        dados.get('fileName') or dados.get('nomeArquivo') or 'Registro_MMC.xlsx'
    )
    return base64.b64decode(dados.get('file', '')), nome
  decodificado = base64.b64decode(texto)
  try:
    dados = json.loads(decodificado.decode('utf-8'))
    nome = (
        dados.get('fileName') or dados.get('nomeArquivo') or 'Registro_MMC.xlsx'
    )
    return base64.b64decode(dados.get('file', '')), nome
  except (UnicodeDecodeError, json.JSONDecodeError):
    return decodificado, 'Registro_MMC.xlsx'


def processar_planilha(bytes_arquivo):
  arquivo = reparar_xlsx(bytes_arquivo)
  bruto = pd.read_excel(arquivo, sheet_name=0, header=None)
  cabecalho = next(
      (
          i
          for i, linha in bruto.head(25).iterrows()
          if any(
              str(v).strip().lower()
              in {
                  'characteristic',
                  'característica',
                  'parâmetro',
                  'parametro',
                  'nominal',
              }
              for v in linha.values
              if pd.notna(v)
          )
      ),
      13,
  )
  arquivo.seek(0)
  dados = pd.read_excel(arquivo, sheet_name=0, skiprows=cabecalho)
  dados.columns = [str(c).strip().lower() for c in dados.columns]

  pontos, dentro, fora = [], 0, 0
  for _, linha in dados.iterrows():
    caract = str(
        linha.get('characteristic')
        or linha.get('característica')
        or linha.get('parâmetro')
        or linha.get('elemento')
        or ''
    ).strip()
    if (
        not caract
        or caract.lower() in {'nan', 'none'}
        or any(
            t in caract.lower()
            for t in ['nota', 'incerteza', 'observação', 'obs:']
        )
    ):
      continue
    try:
      nominal = float(linha.get('nominal', 0))
      leitura = float(
          linha.get('actual', linha.get('medido', linha.get('leitura', 0))) or 0
      )
      inferior = float(linha.get('lower tol', linha.get('tol -', 0)) or 0)
      superior = float(linha.get('upper tol', linha.get('tol +', 0)) or 0)
    except (ValueError, TypeError):
      continue

    erro = leitura - nominal
    situacao = (
        'DENTRO_DA_TOLERANCIA'
        if inferior - 1e-7 <= erro <= superior + 1e-7
        else 'FORA_DA_TOLERANCIA'
    )
    dentro += situacao == 'DENTRO_DA_TOLERANCIA'
    fora += situacao == 'FORA_DA_TOLERANCIA'
    pontos.append({
        'caracteristica': caract,
        'nominal': nominal,
        'leitura1': leitura,
        'leitura2': leitura,
        'media': leitura,
        'erro': erro,
        'toleranciaInferior': inferior,
        'toleranciaSuperior': superior,
        'situacao': situacao,
    })
  return pontos, dentro, fora


def resposta(status, headers, dados):
  return {
      'statusCode': status,
      'headers': headers,
      'body': json.dumps(dados, cls=DecimalEncoder),
  }


def lambda_handler(event, context):
  headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Content-Type': 'application/json',
  }
  metodo = event.get('httpMethod') or event.get('requestContext', {}).get(
      'http', {}
  ).get('method', 'POST')
  if metodo == 'OPTIONS':
    return {'statusCode': 200, 'headers': headers, 'body': ''}

  try:
    if metodo == 'GET':
      parametros = event.get('queryStringParameters') or {}
      cert_id = normalizar_codigo_certificado(
          parametros.get('id') or parametros.get('certificadoId')
      )
      if cert_id:
        certificado = tabela_certificados.get_item(
            Key={'certificadoId': cert_id}
        ).get('Item')
        if not certificado:
          return resposta(
              404,
              headers,
              {
                  'sucesso': False,
                  'valido': False,
                  'erro': f'Certificado {cert_id} não encontrado.',
              },
          )
        return resposta(
            200,
            headers,
            {'sucesso': True, 'valido': True, 'certificado': certificado},
        )

      itens = tabela_certificados.scan().get('Items', [])
      itens.sort(
          key=lambda x: x.get('timestampIso', x.get('dataEmissao', '')),
          reverse=True,
      )
      return resposta(
          200,
          headers,
          {'sucesso': True, 'total': len(itens), 'historico': itens},
      )

    bytes_arquivo, nome = extrair_arquivo(event.get('body'))
    if not bytes_arquivo:
      return resposta(
          400,
          headers,
          {'sucesso': False, 'erro': 'Corpo da requisição está vazio.'},
      )

    pontos, dentro, fora = processar_planilha(bytes_arquivo)
    agora = datetime.now(FUSO_BR)
    cert_id = f'SCH-{agora:%Y}-{uuid.uuid4().hex[:6].upper()}'
    emissao = agora.strftime('%d/%m/%Y %H:%M:%S')
    parecer = 'APROVADO' if pontos and not fora else 'REPROVADO'
    hash_validacao = hashlib.sha256(
        f'{cert_id}:{parecer}:{len(pontos)}:{emissao}'.encode()
    ).hexdigest()

    certificado = {
        'certificadoId': cert_id,
        'dataEmissao': emissao,
        'timestampIso': agora.isoformat(),
        'arquivoOrigem': nome,
        'hashValidacao': hash_validacao,
        'metadados': {
            'tagPatrimonial': 'MMC-500.011',
            'denominacao': 'Tridimensional MMC Carl Zeiss',
            'setorSolicitante': 'Laboratório Central de Metrologia',
            'padraoVinculado': 'Bloco Padrão Inc. #04',
            'signatario': 'João Carlos Gomes de Oliveira',
        },
        'resumo': {
            'parecer': parecer,
            'total': len(pontos),
            'dentroDaTolerancia': dentro,
            'foraDaTolerancia': fora,
        },
        'pontos': pontos,
    }

    tabela_certificados.put_item(Item=para_dynamodb(certificado))
    payload = f'SCHULZ-CERT|{cert_id}|{parecer}|{hash_validacao[:12]}'
    pdf = gerar_pdf(certificado, payload)

    return resposta(
        200,
        headers,
        {
            **certificado,
            'sucesso': True,
            'qrCodePayload': payload,
            'pdfBase64': base64.b64encode(pdf).decode('utf-8'),
            'criterio': (
                'Tolerâncias inferior e superior com validação float (1e-7).'
            ),
            'dados': pontos,
        },
    )
  except Exception as erro:
    return resposta(
        400,
        headers,
        {'sucesso': False, 'erro': f'Erro no processamento: {erro}'},
    )