@echo off
setlocal
cd /d "%~dp0\.."

if not exist ".venv\Scripts\python.exe" (
  echo Missing virtual environment at .venv
  exit /b 1
)

if not exist ".env" (
  echo Missing .env file. Copy .env.example to .env and update DB credentials.
  exit /b 1
)

.venv\Scripts\python.exe backend\app.py
endlocal
