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
echo [0] Tu dong phat hien theo may (khuyen dung)
echo [1] Nvidia GPU CUDA 12.6 (Khuyen dung - Chay rat nhanh)
echo [2] Nvidia GPU CUDA 12.4
echo [3] Nvidia GPU CUDA 12.1
echo [4] Chi dung CPU (Khong can card roi - Chay cham hon)
echo ======================================================================
set /p choice="Nhap lua chon cua ban (0-4): "

if "%choice%"=="" set "choice=0"

if "%choice%"=="0" (
    set "cuda_ver="
    set "cuda_target=cpu"

    where nvidia-smi >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=2 delims=:" %%A in ('nvidia-smi ^| findstr /i "CUDA Version"') do (
            set "cuda_ver=%%A"
        )

        if defined cuda_ver (
            for /f "tokens=1-2 delims=." %%A in ("!cuda_ver!") do (
                set "cuda_major=%%A"
                set "cuda_minor=%%B"
            )

            if not defined cuda_minor set "cuda_minor=0"
            if !cuda_major! GEQ 13 (
                set "cuda_target=cu126"
            ) else if !cuda_major! GEQ 12 (
                if !cuda_minor! GEQ 6 (
                    set "cuda_target=cu126"
                ) else if !cuda_minor! GEQ 4 (
                    set "cuda_target=cu124"
                ) else (
                    set "cuda_target=cu121"
                )
            ) else (
                set "cuda_target=cu121"
            )
        )
    )

    if "!cuda_target!"=="cu126" (
        echo [INFO] Auto-detected CUDA support: 12.6 or higher - installing PyTorch CUDA 12.6...
        pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu126
    ) else if "!cuda_target!"=="cu124" (
        echo [INFO] Auto-detected CUDA support: 12.4 - installing PyTorch CUDA 12.4...
        pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu124
    ) else if "!cuda_target!"=="cu121" (
        echo [INFO] Auto-detected CUDA support: 12.1 - installing PyTorch CUDA 12.1...
        pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu121
    ) else (
        echo [INFO] No NVIDIA GPU detected - installing PyTorch CPU-only version...
        pip install torch torchaudio
    )
) else if "%choice%"=="1" (
    echo [INFO] Installing PyTorch with CUDA 12.6 support...
    pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu126
) else if "%choice%"=="2" (
    echo [INFO] Installing PyTorch with CUDA 12.4 support...
    pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu124
) else if "%choice%"=="3" (
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
    "%~dp0venv\Scripts\python.exe" "%~dp0app\main.py"
) else (
    echo.
    echo De chay server sau nay, activate venv va chay:
    echo venv\Scripts\activate.bat ^&^& python app/main.py
    echo.
)

pause

