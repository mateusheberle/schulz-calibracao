import sys
import os

# Se o lambda_function.py estiver dentro da pasta 'bin', use a linha abaixo:
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../bin')))

import base64
import json
from lambda_function import lambda_handler

# 1. Carrega uma planilha real de testes que está no seu projeto
path_planilha = "exemplos/registro_mmc_teste_aprovado.xlsx"  # Ajuste o caminho conforme seu arquivo

with open(path_planilha, "rb") as f:
    file_bytes = f.read()

# Converte o arquivo para a string Base64 que o Flutter enviaria
file_b64 = base64.b64encode(file_bytes).decode('utf-8')

# 2. Monta o evento simulado que o AWS API Gateway entrega ao Lambda
mock_event = {
    "httpMethod": "POST",
    "body": json.dumps({"file": file_b64})
}

# 3. Invoca o handler localmente sem precisar da AWS
print("--- EXECUTANDO TESTE LOCAL DO LAMBDA ---")
resposta = lambda_handler(mock_event, None)

print(f"\nStatus Code: {resposta['statusCode']}")
print("Body retornado:")
print(json.dumps(json.loads(resposta['body']), indent=2, ensure_ascii=False))