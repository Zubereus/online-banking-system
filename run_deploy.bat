@echo off
setlocal

REM Always run from this project folder
cd /d "%~dp0"

set "FLASK_PORT=8080"
set "PYTHON_EXE=%~dp0.venv\Scripts\python.exe"
set "MYSQLD_EXE=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe"
set "MYSQL_INI=C:\ProgramData\MySQL\MySQL Server 8.4\my.ini"

if not exist "%PYTHON_EXE%" (
	echo [ERROR] Missing Python virtual environment at .venv
	echo Create or restore .venv first.
	exit /b 1
)

if not exist "%~dp0.env" (
	echo [ERROR] Missing .env file.
	echo Copy .env.example to .env and update DB credentials.
	exit /b 1
)

echo [INFO] Checking MySQL service...
set "MYSQL_FOUND=0"
set "MYSQL_RUNNING=0"

for %%S in (MySQL80 MySQL MariaDB MySQL57) do (
	sc query "%%S" >nul 2>&1
	if not errorlevel 1 (
		set "MYSQL_FOUND=1"
		echo [INFO] Found service %%S
		sc query "%%S" | findstr /I "RUNNING" >nul
		if errorlevel 1 (
			echo [INFO] Starting %%S...
			net start "%%S" >nul 2>&1
			if errorlevel 1 (
				echo [WARN] Could not start %%S automatically.
				echo [WARN] Will try direct mysqld startup fallback.
			) else (
				echo [OK] %%S started.
				set "MYSQL_RUNNING=1"
			)
		) else (
			echo [OK] %%S is already running.
			set "MYSQL_RUNNING=1"
		)
		goto :mysql_done
	)
)

:mysql_done
if "%MYSQL_FOUND%"=="0" (
	echo [WARN] No known MySQL service name found.
	echo [WARN] Will try direct mysqld startup fallback.
)

if "%MYSQL_RUNNING%"=="0" (
	echo [INFO] Attempting direct MySQL startup via mysqld.exe...
	if exist "%MYSQLD_EXE%" (
		if exist "%MYSQL_INI%" (
			start "MySQL Server" "%MYSQLD_EXE%" --defaults-file="%MYSQL_INI%"
		) else (
			echo [ERROR] Missing MySQL config file: %MYSQL_INI%
			echo [ERROR] Run MySQL initialization once, then retry.
			exit /b 1
		)
	) else (
		echo [ERROR] mysqld.exe not found at:
		echo         %MYSQLD_EXE%
		echo [ERROR] Install MySQL Server first.
		exit /b 1
	)
)

echo [INFO] Waiting for MySQL on 127.0.0.1:3306...
set "MYSQL_READY=0"
for /L %%I in (1,1,30) do (
	powershell -NoProfile -Command "$r = Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -WarningAction SilentlyContinue; if ($r.TcpTestSucceeded) { exit 0 } else { exit 1 }" >nul 2>&1
	if not errorlevel 1 (
		set "MYSQL_READY=1"
		goto :mysql_ready
	)
	timeout /t 1 >nul
)

:mysql_ready
if "%MYSQL_READY%"=="0" (
	echo [ERROR] MySQL did not become ready on port 3306.
	echo [ERROR] Check the MySQL Server window for startup errors.
	exit /b 1
)

echo [INFO] Initializing database from SQL files...
call "%~dp0scripts\init_db.bat"
if errorlevel 1 (
	echo [ERROR] Database initialization failed. Deployment aborted.
	exit /b 1
)

echo [OK] Database initialized successfully.

REM Start Flask app (serves API and static frontend)
start "Flask App" "%PYTHON_EXE%" backend\app.py

echo [INFO] Waiting for Flask app on 127.0.0.1:%FLASK_PORT%...
set "APP_READY=0"
for /L %%I in (1,1,30) do (
	powershell -NoProfile -Command "$r = Test-NetConnection -ComputerName 127.0.0.1 -Port %FLASK_PORT% -WarningAction SilentlyContinue; if ($r.TcpTestSucceeded) { exit 0 } else { exit 1 }" >nul 2>&1
	if not errorlevel 1 (
		set "APP_READY=1"
		goto :app_ready
	)
	timeout /t 1 >nul
)

:app_ready
if "%APP_READY%"=="0" (
	echo [ERROR] Flask app did not become ready on port %FLASK_PORT%.
	echo [ERROR] Check the Flask App window for startup errors.
	exit /b 1
)

REM Start ngrok tunnel in a separate window
where ngrok >nul 2>&1
if errorlevel 1 (
	echo [ERROR] ngrok is not available in PATH.
	echo [ERROR] Install ngrok or add it to PATH.
	exit /b 1
)

start "ngrok Tunnel" cmd /k "ngrok http 127.0.0.1:%FLASK_PORT%"

echo Deployment started.
echo App server: http://localhost:%FLASK_PORT%
echo Public URL will appear in the ngrok window.
echo.
echo Close both opened windows to stop deployment.

endlocal
