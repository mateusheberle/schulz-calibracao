@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Schulz S.A. - Sistema Automatizado de Calibracao Metrologica

echo ============================================================================
echo   SCHULZ S.A. - LABORATORIO CENTRAL DE METROLOGIA
echo   Inicializando Aplicacao de Emissao e Validacao de Certificados...
echo ============================================================================
echo.

python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if not errorlevel 1 goto USAR_PYTHON

py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if not errorlevel 1 goto USAR_PY

echo [ERRO] Python 3.10 ou superior nao encontrado no PATH do sistema.
echo Instale o Python 3.10+ marcando a opcao "Add Python to PATH" e tente novamente.
pause
exit /b 1

:USAR_PYTHON
set PY_CMD=python
goto VERIFICAR_VENV

:USAR_PY
set PY_CMD=py -3
goto VERIFICAR_VENV

:VERIFICAR_VENV
if exist "venv\Scripts\python.exe" goto VENV_PRONTO
echo [1/3] Criando ambiente virtual isolado venv...
%PY_CMD% -m venv venv
if errorlevel 1 goto ERRO_VENV
goto INSTALAR_DEPS

:VENV_PRONTO
echo [1/3] Ambiente virtual encontrado.

:INSTALAR_DEPS
echo [2/3] Ativando ambiente e instalando bibliotecas do requirements.txt...
call venv\Scripts\activate.bat
venv\Scripts\python.exe -m pip install --upgrade pip >nul 2>&1
venv\Scripts\python.exe -m pip install -r requirements.txt
if errorlevel 1 goto ERRO_PIP

echo.
echo [3/3] Iniciando servidor web local em http://127.0.0.1:5000 ...
echo       Pressione CTRL+C nesta janela para encerrar a aplicacao.
echo.

venv\Scripts\python.exe app.py
pause
exit /b 0

:ERRO_VENV
echo [ERRO] Nao foi possivel criar o ambiente virtual venv.
pause
exit /b 1

:ERRO_PIP
echo [ERRO] Falha ao instalar as dependencias listadas em requirements.txt.
pause
exit /b 1