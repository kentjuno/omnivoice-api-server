import io
import os
import sys
import logging
import asyncio
from pathlib import Path
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Load env variables
load_dotenv()

# Setup logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("omnivoice-api-server")

# Global reference to model
model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    import torch
    from omnivoice import OmniVoice
    
    logger.info("Python executable: %s", sys.executable)
    logger.info("Torch version: %s | torch.cuda.is_available(): %s | torch.version.cuda: %s",
                torch.__version__, torch.cuda.is_available(), torch.version.cuda)

    device = os.getenv("DEVICE", "cuda" if torch.cuda.is_available() else "cpu")
    dtype_str = os.getenv("DTYPE", "float16" if device == "cuda" else "float32")
    
    # Auto fallback if CUDA is selected but not compiled/available
    if device == "cuda" and not torch.cuda.is_available():
        logger.warning(
            "CUDA was selected, but PyTorch does not have CUDA enabled on this system. "
            "Automatically falling back to CPU!"
        )
        device = "cpu"
        dtype_str = "float32"
        
    dtype = torch.float16 if dtype_str == "float16" else torch.float32
    
    logger.info("Loading OmniVoice model onto '%s' (precision: %s)...", device, dtype_str)
    try:
        model = OmniVoice.from_pretrained(
            "k2-fsa/OmniVoice",
            device_map=device,
            dtype=dtype
        )
        logger.info("OmniVoice model loaded successfully!")
    except Exception as e:
        logger.error("Failed to load OmniVoice model: %s", e, exc_info=True)
        raise e
    yield
    # Clean up model reference
    model = None
    logger.info("OmniVoice model unloaded.")

app = FastAPI(
    title="OmniVoice Local API Server",
    description="Offline API server wrapper for k2-fsa/OmniVoice TTS",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for local client apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", response_class=HTMLResponse)
async def get_index():
    index_path = Path(__file__).resolve().parent / "templates" / "index.html"
    if not index_path.exists():
        raise HTTPException(status_code=404, detail="Web playground template not found")
    return HTMLResponse(content=index_path.read_text(encoding="utf-8"))

class TTSRequest(BaseModel):
    text: str
    voice_id: Optional[str] = None
    language: Optional[str] = "vi"
    emotion: Optional[str] = "normal"
    instruct: Optional[str] = None
    ref_audio: Optional[str] = None
    speed: Optional[float] = None
    duration: Optional[float] = None
    num_step: Optional[int] = 32
    guidance_scale: Optional[float] = 2.0
    denoise: Optional[bool] = True
    postprocess_output: Optional[bool] = True

@app.get("/health")
def health():
    """Simple status check to verify server running and model loaded."""
    if model is None:
        return {"status": "starting", "model_loaded": False}
    return {"status": "ok", "model_loaded": True}

@app.post("/v1/tts")
async def generate_tts(request: TTSRequest):
    """Generates audio/wav stream from text utilizing OmniVoice."""
    global model
    if model is None:
        raise HTTPException(status_code=503, detail="TTS Model is not loaded yet")

    if not request.text.strip():
        raise HTTPException(status_code=400, detail="Text field cannot be empty")

    # 1. Resolve Voice Cloning (Reference Audio)
    ref_audio_path = None
    if request.ref_audio:
        ref_audio_path = request.ref_audio
    elif request.voice_id:
        # Check in the local voices directory
        voices_dir = Path(__file__).resolve().parents[1] / "voices"
        for ext in [".wav", ".mp3", ".ogg", ".flac"]:
            candidate = voices_dir / f"{request.voice_id}{ext}"
            if candidate.exists():
                ref_audio_path = str(candidate.resolve())
                logger.info("Matched voice_id '%s' to local reference file: %s", request.voice_id, ref_audio_path)
                break

    # 2. Resolve Voice Design (Instructions)
    instruct = request.instruct
    if not instruct and request.voice_id and not ref_audio_path:
        # Fallback mappings for standard MovieRecapTool voices if files do not exist
        voice_id_lower = request.voice_id.lower()
        if "female" in voice_id_lower or "default" in voice_id_lower:
            instruct = "female, young adult, moderate pitch"
        elif "male" in voice_id_lower:
            instruct = "male, young adult, moderate pitch"
        else:
            instruct = request.voice_id
        logger.info("Treating voice_id '%s' as Voice Design instruction: %s", request.voice_id, instruct)

    # 3. Handle emotions
    text_to_gen = request.text
    if request.emotion and request.emotion.lower() != "normal":
        emo = request.emotion.lower()
        if not text_to_gen.startswith("["):
            text_to_gen = f"[{emo}] {text_to_gen}"
            logger.info("Prepended emotion tag '%s' to text prompt", emo)

    # 4. Perform inference asynchronously in a threadpool executor
    logger.info("Generating speech for: '%s'...", text_to_gen[:60] + ("..." if len(text_to_gen) > 60 else ""))
    loop = asyncio.get_running_loop()
    
    try:
        kwargs = {
            "num_step": int(request.num_step or 32),
            "guidance_scale": float(request.guidance_scale or 2.0),
            "denoise": bool(request.denoise if request.denoise is not None else True),
            "postprocess_output": bool(request.postprocess_output if request.postprocess_output is not None else True),
            "audio_chunk_duration": 10.0,
            "audio_chunk_threshold": 15.0
        }
        
        # Parse language
        lang = request.language if request.language and request.language.lower() != "auto" else None
        
        if ref_audio_path:
            kwargs["ref_audio"] = ref_audio_path
        else:
            kwargs["instruct"] = instruct or "female, moderate pitch, young adult"

        if request.speed is not None:
            kwargs["speed"] = float(request.speed)
        if request.duration is not None:
            kwargs["duration"] = float(request.duration)

        def _infer():
            res_audio = model.generate(text=text_to_gen, language=lang, **kwargs)
            if isinstance(res_audio, (tuple, list)):
                return res_audio[0]
            return res_audio

        audio_data = await loop.run_in_executor(None, _infer)
        
        # 5. Convert generated NumPy array into standard WAV BytesIO stream
        import soundfile as sf
        samplerate = getattr(model.config, "samplerate", 24000)
        
        buffer = io.BytesIO()
        sf.write(buffer, audio_data, samplerate, format="WAV")
        buffer.seek(0)
        
        logger.info("Speech generation successful. Duration: %.2fs", len(audio_data) / samplerate)
        return StreamingResponse(buffer, media_type="audio/wav")

    except Exception as e:
        logger.error("TTS generation failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

from fastapi import UploadFile, File

@app.post("/api/upload-ref")
async def upload_ref_file(file: UploadFile = File(...)):
    """Uploads a WAV reference file into the voices directory for cloning."""
    if not file.filename.lower().endswith((".wav", ".mp3", ".ogg", ".flac")):
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận file âm thanh (.wav, .mp3, .ogg, .flac)")
        
    voices_dir = Path(__file__).resolve().parents[1] / "voices"
    voices_dir.mkdir(parents=True, exist_ok=True)
    
    file_path = voices_dir / file.filename
    try:
        contents = await file.read()
        file_path.write_bytes(contents)
        logger.info("Uploaded reference file saved: %s", file_path)
    except Exception as e:
        logger.error("Failed to save uploaded file: %s", e)
        raise HTTPException(status_code=500, detail=f"Lỗi khi lưu file: {e}")
        
    return {"filename": file.filename, "path": str(file_path.resolve())}

@app.get("/api/voices")
def list_available_voices():
    """Lists all available reference audio files inside the voices directory."""
    voices_dir = Path(__file__).resolve().parents[1] / "voices"
    voices_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for ext in ["*.wav", "*.mp3", "*.ogg", "*.flac"]:
        for f in voices_dir.glob(ext):
            files.append(f.name)
    files.sort()
    return {"voices": files}

if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "8000"))
    logger.info("Starting Uvicorn server on %s:%d...", host, port)
    uvicorn.run("main:app", host=host, port=port, reload=False)
