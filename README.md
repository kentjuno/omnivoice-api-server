# OmniVoice Local API Server

This is an offline, standalone FastAPI wrapper for the **[k2-fsa/OmniVoice](https://github.com/k2-fsa/OmniVoice)** text-to-speech engine. It pre-loads the model on startup, caches generated voice segments, and provides a `/v1/tts` HTTP POST endpoint. It is fully compatible with the `MovieRecapTool` voice service.

---

## Prerequisites

1. **Python 3.10 - 3.12** installed on your system.
2. **Git** installed (required to fetch OmniVoice from GitHub): [Download Git here](https://git-scm.com/downloads).
3. **Nvidia GPU** (Optional but highly recommended for fast RTF inference). Ensure you have Nvidia CUDA drivers installed.

---

## Quick Setup (Windows)

We have provided a double-click helper batch script:

1. Double-click `setup_and_run.bat`.
2. The script will automatically create a Python virtual environment (`venv/`).
3. It will prompt you to choose the PyTorch target (CUDA 12.4, CUDA 12.1, or CPU).
4. It will install all dependencies (including `fastapi`, `uvicorn`, `soundfile`, and the latest `omnivoice` git code).
5. At the end, it will ask if you want to launch the server immediately.

---

## Manual Setup

If you prefer to install manually, run the following commands:

```bash
# 1. Create and activate environment
python -m venv venv
call venv\Scripts\activate

# 2. Install PyTorch configured for your system (e.g. CUDA 12.4)
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124

# 3. Install requirements
pip install -r requirements.txt

# 4. Install OmniVoice from GitHub
pip install git+https://github.com/k2-fsa/OmniVoice.git

# 5. Create default env file
copy .env.example .env
```

To run the server:
```bash
python app/main.py
```

---

## API Reference

### 1. Health Check
*   **Method**: `GET`
*   **URL**: `http://127.0.0.1:8088/health`
*   **Response**:
    ```json
    {
      "status": "ok",
      "model_loaded": true
    }
    ```

### 2. Text-to-Speech Generation
*   **Method**: `POST`
*   **URL**: `http://127.0.0.1:8088/v1/tts`
*   **Request Body (JSON)**:
    ```json
    {
      "text": "Xin chào nha ní! Đây là thuyết minh kịch bản phim.",
      "voice_id": "vi_female_1",
      "language": "vi",
      "emotion": "normal",
      "instruct": "A professional male voice with a warm tone.",
      "ref_audio": "path/to/custom_ref.wav"
    }
    ```
*   **Response**: Audio binary stream in WAV format (`audio/wav`).

---

## Features

### 🎙️ Voice Cloning (Reference Audio)
If you send a request with `voice_id = "my_voice"`, the server will check if `voices/my_voice.wav` (or `.mp3`/`.ogg`/`.flac`) exists.
*   If **found**, it automatically extracts voice characteristics from that file to clone the speaker's voice.
*   If **not found**, it treats `voice_id` as a text description for Voice Design.

### 🎭 Voice Design (Text Instruction)
You can describe the speaker's voice using natural language (in `voice_id` or `instruct`):
*   *Example:* `"A soft, friendly female voice speaking Vietnamese with a Southern accent."`

### 😊 Expressive Emotions
Insert style tags directly inside your text for extra expressiveness:
*   *Example:* `"[laughter] Tôi không thể tin được chuyện này đã xảy ra!"` (supports `[laughter]`, `[sigh]`, etc. depending on model defaults).
*   If the `emotion` parameter is set to something other than `normal` (e.g. `dramatic`), it prepends the tag automatically (e.g., `[dramatic]`).

---

## Verification

While the server is running, open a new command prompt, activate the environment, and execute the test client:

```bash
call venv\Scripts\activate
python test_client.py
```

This will call the API, verify the connection, and save a test file `test_output.wav` to your project folder. Play it to hear the synthesized audio!
