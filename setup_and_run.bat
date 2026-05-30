@echo off
title OmniVoice Local API Server - Setup and Runner
color 0A
setlocal enabledelayedexpansion

echo ======================================================================
echo          OmniVoice Local API Server - Installer ^& Runner
echo ======================================================================
echo.

:: 1. Check Python installation
python --version >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo ERROR: Python is not installed or not in system PATH.
    echo Please install Python 3.10+ and select "Add Python to PATH".
    pause
    exit /b 1
)

:: 2. Setup Virtual Environment
if not exist venv (
    echo [INFO] Creating Python virtual environment in venv/...
    python -m venv venv
    if !errorlevel! neq 0 (
        color 0C
        echo ERROR: Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo [SUCCESS] Virtual environment created.
    echo.
)

echo [INFO] Activating virtual environment...
call venv\Scripts\activate.bat
echo [INFO] Upgrading pip...
python -m pip install --upgrade pip

:: 3. Select PyTorch target
echo.
echo ======================================================================
echo CHON PHIEN BAN PYTORCH CAI DAT (SELECT PYTORCH VERSION):
echo ======================================================================
echo [1] Nvidia GPU CUDA 12.4 (Khuyen dung - Chay rat nhanh)
echo [2] Nvidia GPU CUDA 12.1
echo [3] Chi dung CPU (Khong can card rời - Chay cham hon)
echo ======================================================================
set /p choice="Nhap lua chon cua ban (1-3): "

if "%choice%"=="1" (
    echo [INFO] Installing PyTorch with CUDA 12.4 support...
    pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu124
) else if "%choice%"=="2" (
    echo [INFO] Installing PyTorch with CUDA 12.1 support...
    pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu121
) else (
    echo [INFO] Installing PyTorch CPU-only version...
    pip install torch torchaudio
)

if !errorlevel! neq 0 (
    color 0C
    echo ERROR: Failed to install PyTorch. Please check your internet connection.
    pause
    exit /b 1
)

:: 4. Install requirements and git package
echo.
echo [INFO] Installing general requirements...
pip install -r requirements.txt

echo [INFO] Installing k2-fsa/OmniVoice from GitHub...
pip install git+https://github.com/k2-fsa/OmniVoice.git

if !errorlevel! neq 0 (
    color 0C
    echo ERROR: Failed to install OmniVoice. Please ensure Git is installed.
    echo Download Git from: https://git-scm.com/downloads
    pause
    exit /b 1
)

:: 5. Create default folder templates
if not exist app mkdir app
if not exist voices mkdir voices
if not exist .env (
    echo [INFO] Creating default .env file...
    copy .env.example .env >nul
)

echo.
echo [SUCCESS] Cài đặt hoàn tất / Setup completed successfully!
echo ======================================================================
echo.

set /p run="Ban co muon khoi dong server luon khong? (y/n): "
if /i "%run%"=="y" (
    echo [INFO] Starting FastAPI server on http://127.0.0.1:8000 ...
    python app/main.py
) else (
    echo.
    echo De chay server sau nay, activate venv va chay:
    echo venv\Scripts\activate.bat ^&^& python app/main.py
    echo.
)

pause
