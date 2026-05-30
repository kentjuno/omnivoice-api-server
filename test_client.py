import sys
import requests
from pathlib import Path

def main():
    url = "http://127.0.0.1:8088/v1/tts"
    payload = {
        "text": "[laughter] Xin chào nha ní! Đây là giọng nói thử nghiệm chạy trực tiếp từ server OmniVoice cục bộ trên máy tính của bạn.",
        "voice_id": "A professional male voice with a warm, friendly Vietnamese accent.",
        "language": "vi",
        "emotion": "normal"
    }

    print("Checking if server is running...")
    try:
        health = requests.get("http://127.0.0.1:8088/health", timeout=5)
        print(f"Health check status: {health.status_code} - {health.json()}")
    except Exception as e:
        print(f"Error connecting to server. Is it running? {e}")
        print("We will attempt to request TTS anyway...")

    print(f"Sending request to {url}...")
    try:
        response = requests.post(url, json=payload, timeout=180)
        if response.status_code == 200:
            output_file = Path("test_output.wav")
            output_file.write_bytes(response.content)
            print(f"Success! Saved generated audio to: {output_file.resolve()}")
            print(f"Audio size: {len(response.content)} bytes")
        else:
            print(f"Failed with status code {response.status_code}: {response.text}")
    except Exception as e:
        print(f"Error during request: {e}")

if __name__ == "__main__":
    main()
