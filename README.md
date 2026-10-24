# Schulz — Análise de Calibração

MVP desenvolvido para a atividade AV3 de Projeto Aplicado III, com o tema Automação da Emissão de Certificados de Calibração.

A aplicação recebe uma planilha no modelo Registro MMC, calcula a média das leituras e o erro por característica, verifica as tolerâncias e apresenta o parecer final.

## Tecnologias

- Flutter Web: interface.
- Dart: API HTTP e processamento.
- `excel`: leitura de arquivos `.xlsx`.
- `file_picker`: seleção de arquivos.
- `http`: comunicação entre frontend e backend.

## Fluxo da aplicação

1. O usuário seleciona uma planilha `.xlsx`.
2. O frontend envia os bytes para a API.
3. O backend valida a estrutura e as medições.
4. O processador calcula médias, erros e classificações.
5. A API retorna os resultados em JSON.
6. A interface apresenta os pontos avaliados e o parecer final.

O processamento ocorre em memória, sem armazenamento em banco de dados.

## Formato de entrada

O MVP aceita arquivos de até 5 MiB no modelo Registro MMC:

- Aba obrigatória: `Report`.
- Cabeçalho na linha 13.
- Dados a partir da linha 14.
- Exatamente duas leituras por característica.
- Nominal e tolerâncias iguais nas duas leituras.

Colunas esperadas:

| Coluna | Cabeçalho | Uso |
|---|---|---|
| A | Characteristic | Identificação da característica |
| B | Actual | Leitura medida |
| C | Nominal | Referência utilizada no cálculo |
| D | Upper Tol | Limite superior do erro |
| E | Lower Tol | Limite inferior do erro |
| F | Deviation | Não utilizado no cálculo; o erro é recalculado |

## Regras de cálculo

Para cada característica:

```text
Média = (leitura 1 + leitura 2) / 2
Erro = média − nominal
```

O ponto está dentro da tolerância quando:

```text
tolerância inferior ≤ erro ≤ tolerância superior
```

A comparação inclui os limites e utiliza uma margem computacional de
`1e-12` para imprecisões de ponto flutuante. Essa margem não representa
incerteza de medição.

O parecer final será:

- `APROVADO`: todos os pontos dentro da tolerância.
- `REPROVADO`: pelo menos um ponto fora da tolerância.

### Relação com o material da atividade

A Aula 02, páginas 7 e 8, apresenta a comparação do valor obtido com:

```text
Limite mínimo = nominal − |Tol. −|
Limite máximo = nominal + |Tol. +|
```

Para as tolerâncias fornecidas no Registro MMC, com limite inferior
negativo ou zero e superior positivo, essa regra equivale à comparação
do erro utilizada pelo MVP.

Quando os limites são simétricos, a comparação também equivale a
`|erro| ≤ LEA`. Para os intervalos unilaterais, são preservados os
limites da planilha.

O MVP não inclui a incerteza de medição na decisão.

## Como executar

### Pré-requisitos

- Flutter com suporte Web.
- Dart compatível com a restrição `^3.8.1`.
- Google Chrome.
- Git, caso o projeto seja obtido por clonagem.

### Obter o projeto

```bash
git clone https://github.com/mateusheberle/schulz-calibracao.git
cd schulz-calibracao
```

### Iniciar o backend

Em um terminal, a partir da raiz do projeto:

```bash
cd backend
dart pub get
dart run bin/servidor.dart
```

Verificação da API:

http://127.0.0.1:8080/saude

Resposta esperada:

```json
{"status":"ok"}
```

Mantenha esse terminal aberto.

### Iniciar o frontend

Em outro terminal, a partir da raiz do projeto:

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 3000
```

A origem permitida pela API é `http://localhost:3000`.
Use esse endereço e essa porta para executar a interface.

### Processar a planilha

1. Clique em **Selecionar Excel**.
2. Escolha `backend/exemplos/registro_mmc.xlsx`.
3. Clique em **Processar planilha**.

Resultado esperado para a planilha original:

| Características | Dentro | Fora | Parecer |
|---:|---:|---:|---|
| 14 | 8 | 6 | REPROVADO |

## Rotas da API

| Método | Rota | Finalidade |
|---|---|---|
| GET | `/saude` | Verificar disponibilidade |
| POST | `/calibracoes/processar` | Processar o Excel |

O POST recebe os bytes do arquivo no corpo da requisição, com
`Content-Type: application/octet-stream`. Não utiliza formulário multipart.

Arquivos inválidos são rejeitados, sem emissão de parecer.

## Evidências

Capturas dos testes executados:

| Evidência | Arquivo |
|---|---|
| Testes de tolerância | [Visualizar](docs/evidencias/01.png) |
| Teste de processamento | [Visualizar](docs/evidencias/02.png) |
| Resultado reprovado | [Visualizar](docs/evidencias/04.png) |
| Resultado aprovado com dados simulados | [Visualizar](docs/evidencias/05.png) |
| Rejeição de arquivo inválido | [Visualizar](docs/evidencias/06.png) |
| Teste da tela inicial | [Visualizar](docs/evidencias/07.png) |
