@echo off
title OmniVoice API Server - Port 8088
color 0A

if "%OMNIVOICE_HOST%"=="" set "OMNIVOICE_HOST=127.0.0.1"
if "%OMNIVOICE_PORT%"=="" set "OMNIVOICE_PORT=8088"

echo.
echo  ===================================================
echo   OmniVoice Local API Server
echo   http://%OMNIVOICE_HOST%:%OMNIVOICE_PORT%
echo  ===================================================
echo.

:: Check venv exists
if not exist "%~dp0venv\Scripts\activate.bat" (
    color 0C
    echo  [ERROR] Virtual environment not found!
    echo  Please run setup_and_run.bat first.
    echo.
    pause
    exit /b 1
)

:: Activate venv
call "%~dp0venv\Scripts\activate.bat"

:: Kill anything already on the target port
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%OMNIVOICE_PORT% ^| findstr LISTENING') do (
    echo  [INFO] Port %OMNIVOICE_PORT% in use by PID %%a - killing it...
    taskkill /PID %%a /F >nul 2>&1
)

:: Quick CUDA check
python -c "import torch; ok = torch.cuda.is_available(); name = torch.cuda.get_device_name(0) if ok else 'None'; print(f'  [GPU] {name}' if ok else '  [GPU] Not available - Running on CPU')" 2>nul
echo.

:: Start server
echo  [INFO] Starting server... (Ctrl+C to stop)
echo.
cd /d "%~dp0app"
"%~dp0venv\Scripts\python.exe" -m uvicorn main:app --host %OMNIVOICE_HOST% --port %OMNIVOICE_PORT% --log-level info

echo.
echo  [INFO] Server stopped.
pause
