# Schulz S.A. — Automação da Emissão e Validação de Certificados de Calibração

Solução desenvolvida para o **Laboratório Central de Metrologia da Schulz S.A.** (Projeto Aplicado III — UniSENAI), consolidando as entregas da **AV 03** (Motor Metrológico), **AV 04** (Plataforma Web e Validador QR Code em Nuvem) e **AV 05** (Executável Local Automatizado `.bat`).

A aplicação automatiza a ingestão de planilhas `.xlsx` exportadas pelas Máquinas de Medição por Coordenadas (MMC), realiza o saneamento de dados e os cálculos metrológicos, emite o Certificado de Calibração oficial em PDF com QR Code vetorial e permite a validação instantânea de autenticidade no chão de fábrica.

* **Repositório Público (GitHub):** https://github.com/mateusheberle/schulz-calibracao
* **Plataforma Web em Nuvem (AWS CloudFront):** https://d2cwb6y5q96t5q.cloudfront.net

---

## Tecnologias e Arquitetura

* **Execução Local Automatizada (AV 05):**
  * `iniciar_aplicacao_schulz.bat`: script Windows para verificação de ambiente, criação de `venv`, instalação de dependências e inicialização automática.
  * **Python 3.10+ & Flask (`app.py`):** servidor web local (`http://127.0.0.1:5000`), API REST (`/processar`) e persistência local em JSON (`certificados_db.json`).
  * **Pandas & OpenPyXL:** reparo de estrutura OpenXML, detecção dinâmica de cabeçalho e higienização de planilhas `.xlsx`.
  * **ReportLab:** geração vetorial do certificado PDF e do QR Code de rastreabilidade.
  * **HTML/CSS/JS (`templates/index.html`):** interface web local responsiva em 4 etapas.
* **Arquitetura Cloud Serverless (AV 04):**
  * **Frontend (`frontend/`):** Flutter Web hospedado no Amazon S3 com distribuição HTTPS via CloudFront.
  * **Backend (`backend/`):** AWS Lambda (Python), API Gateway e Amazon DynamoDB operando dentro do AWS Free Tier.

---

## Como Executar Localmente (Script `.bat` — AV 05)

### Pré-requisitos
* Sistema operacional **Windows 10 ou 11**.
* **Python 3.10 ou superior** instalado e configurado no `PATH` do sistema (*"Add Python to PATH"*).

### Passo a passo

1. **Obter o repositório:**
   ```powershell
   git clone https://github.com/mateusheberle/schulz-calibracao
   cd schulz-calibracao
   ```
   *(Ou baixe o arquivo `.zip` pelo botão **Code > Download ZIP** no GitHub e extraia a pasta.)*

2. **Iniciar a aplicação com um duplo clique:**
   * Na pasta raiz do projeto, dê um duplo clique em **`iniciar_aplicacao_schulz.bat`**.
   * O script validará o Python 3.10+, criará o ambiente virtual `venv/`, instalará os pacotes listados em `requirements.txt` e abrirá automaticamente o navegador em **`http://127.0.0.1:5000`**.

3. **Processar planilha e emitir certificado:**
   * Na aba **1. Ingestão (MMC)**, selecione uma das planilhas de teste disponíveis na pasta `templates/planilhas teste/`.
   * Na aba **2. Minuta & Revisão**, confira as cotas processadas, o parecer final e clique em **Baixar Certificado Oficial (PDF com QR Code)**.
   * Na aba **3. Validador QR Code**, informe o código gerado (`SCH-AAAA-XXXXXX`) para validar a autenticidade e o hash SHA-256 do certificado.

---

## Regras de Ingestão e Cálculos Metrológicos

1. **Saneamento OpenXML e Limpeza:** O motor converte *namespaces* XML *Strict* para *Transitional* (compatibilidade com exportações MMC Carl Zeiss), localiza dinamicamente a linha de cabeçalho e descarta linhas vazias ou notas de rodapé.
2. **Média das Leituras ($\bar{x}$) e Erro Sistemático ($E$):**
   ```text
   Média (x̄) = (leitura 1 + leitura 2) / 2   [ou valor consolidado na coluna Actual]
   Erro (E)  = x̄ − Valor Nominal
   ```
3. **Validação contra o Limite de Erro Admissível (LEA):**
   ```text
   Tol. Inferior − 1e-7 ≤ Erro ≤ Tol. Superior + 1e-7
   ```
   *(A margem numérica `1e-7` evita falsos negativos por arredondamento de ponto flutuante e não substitui a incerteza de medição declarada no certificado.)*
4. **Parecer Metrológico Global:**
   * **`APROVADO`:** 100% das características avaliadas estão dentro da faixa de tolerância.
   * **`REPROVADO`:** uma ou mais características estão fora da tolerância.

---

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
