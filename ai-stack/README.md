# AI Stack - Lokale LLM & Whisper Infrastruktur

Optimiert fuer: **Intel i5-14500 + RTX 5070 Ti (16GB VRAM) + 64GB DDR5**

## Architektur

```
                                    +------------------+
                                    |   Open WebUI     |
                                    |   (Port 3000)    |
                                    +--------+---------+
                                             |
         +-----------------------------------+-----------------------------------+
         |                                   |                                   |
         v                                   v                                   v
+------------------+              +------------------+              +------------------+
|     Ollama       |              |   Whisper API    |              |    LiteLLM       |
|   (Port 11434)   |              |   (Port 8000)    |              |   (Port 4000)    |
|                  |              |                  |              |                  |
|   RTX 5070 Ti    |              |   CPU (i5-14500) |              |   API Gateway    |
|   16GB VRAM      |              |   AVX-512        |              |   OpenAI-compat  |
+------------------+              +------------------+              +------------------+
```

## Komponenten

| Service | Port | Zweck | Hardware |
|---------|------|-------|----------|
| Ollama | 11434 | LLM Inferenz | RTX 5070 Ti (GPU) |
| Open WebUI | 3000 | Chat Interface | - |
| Whisper API | 8000 | Speech-to-Text | Intel CPU (AVX-512) |
| LiteLLM | 4000 | OpenAI-kompatible API | - |

## Schnellstart

```bash
# 1. Konfiguration erstellen
cp .env.example .env
# Bearbeite .env und setze WEBUI_SECRET_KEY

# 2. Stack starten
docker compose up -d

# 3. Modelle herunterladen (einmalig)
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull qwen2.5-coder:14b
docker exec -it ollama ollama pull nomic-embed-text

# 4. Open WebUI oeffnen
# http://localhost:3000
```

## Use Case 1: Open WebUI Chat

Oeffne `http://localhost:3000` im Browser.

**Ersteinrichtung:**
1. Erstelle einen Admin-Account
2. Waehle ein Modell aus (z.B. llama3.2)
3. Starte einen Chat

**Empfohlene Modelle (16GB VRAM):**
- `llama3.2` - Schnell, gut fuer alltaegliche Aufgaben
- `qwen2.5:14b` - Exzellent fuer Deutsch/Mehrsprachig
- `llama3.3:70b-instruct-q4_K_M` - Hoechste Qualitaet (nutzt vollen VRAM)

## Use Case 2: Untertitel-Transkription & Uebersetzung

### Whisper API Endpunkte

```bash
# Transkription
curl -X POST "http://localhost:8000/v1/audio/transcriptions" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@audio.mp3" \
  -F "model=whisper-large-v3" \
  -F "language=de" \
  -F "response_format=srt"

# Mit Timestamps
curl -X POST "http://localhost:8000/v1/audio/transcriptions" \
  -F "file=@video.mkv" \
  -F "model=whisper-large-v3" \
  -F "response_format=verbose_json"
```

### Integration mit AutoUkSubtitle

Aendere in `appsettings.json`:

```json
{
  "AiProvider": "LmStudio",
  "LmStudio": {
    "BaseUrl": "http://localhost:4000",
    "Model": "qwen2.5",
    "ApiKey": "sk-local-dev-key"
  }
}
```

Die Whisper-Einstellungen bleiben unveraendert (lokale Whisper CLI).
Alternativ kann die App erweitert werden, um die Whisper API zu nutzen.

### Python Beispiel (Transkription + Uebersetzung)

```python
import requests

# 1. Transkription mit Whisper API
def transcribe(audio_path: str, language: str = "de") -> str:
    with open(audio_path, "rb") as f:
        response = requests.post(
            "http://localhost:8000/v1/audio/transcriptions",
            files={"file": f},
            data={
                "model": "whisper-large-v3",
                "language": language,
                "response_format": "srt"
            }
        )
    return response.text

# 2. Uebersetzung mit LLM (OpenAI-kompatibel)
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key="sk-local-dev-key"
)

def translate(srt_content: str, target_lang: str = "uk") -> str:
    response = client.chat.completions.create(
        model="qwen2.5",  # oder "aya" fuer bessere Uebersetzungen
        messages=[
            {"role": "system", "content": f"Translate the following SRT subtitles to {target_lang}. Output only the translated SRT."},
            {"role": "user", "content": srt_content}
        ],
        temperature=0.3
    )
    return response.choices[0].message.content

# Workflow
srt = transcribe("video.mkv", "de")
translated = translate(srt, "uk")
print(translated)
```

## Use Case 3: VS Code Integration

### Option A: Continue Extension (Empfohlen)

1. Installiere "Continue" Extension in VS Code
2. Oeffne Continue Settings (`~/.continue/config.json`):

```json
{
  "models": [
    {
      "title": "Local Qwen Coder",
      "provider": "openai",
      "model": "qwen-coder",
      "apiBase": "http://localhost:4000/v1",
      "apiKey": "sk-local-dev-key"
    },
    {
      "title": "Local DeepSeek Coder",
      "provider": "openai",
      "model": "deepseek-coder",
      "apiBase": "http://localhost:4000/v1",
      "apiKey": "sk-local-dev-key"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Local Autocomplete",
    "provider": "openai",
    "model": "qwen-coder",
    "apiBase": "http://localhost:4000/v1",
    "apiKey": "sk-local-dev-key"
  }
}
```

### Option B: Cody Extension

1. Installiere "Cody" Extension
2. Settings > Cody > Custom Model:
   - API Endpoint: `http://localhost:4000/v1`
   - API Key: `sk-local-dev-key`
   - Model: `qwen-coder`

### Option C: Andere OpenAI-kompatible Extensions

Jede Extension die OpenAI API unterstuetzt kann verwendet werden:
- API Base URL: `http://localhost:4000/v1`
- API Key: `sk-local-dev-key`
- Verfuegbare Modelle: siehe `http://localhost:4000/v1/models`

## Modell-Installation

```bash
# Code-Modelle (fuer VS Code)
docker exec -it ollama ollama pull qwen2.5-coder:14b
docker exec -it ollama ollama pull deepseek-coder-v2:16b
docker exec -it ollama ollama pull codellama:13b

# Allgemeine Modelle
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull llama3.3:70b-instruct-q4_K_M
docker exec -it ollama ollama pull qwen2.5:14b
docker exec -it ollama ollama pull mistral

# Uebersetzungs-Modelle
docker exec -it ollama ollama pull aya:35b
docker exec -it ollama ollama pull command-r:35b

# Embedding (fuer RAG)
docker exec -it ollama ollama pull nomic-embed-text
```

## VRAM-Nutzung (RTX 5070 Ti - 16GB)

| Modell | VRAM | Qualitaet |
|--------|------|-----------|
| llama3.2 (3B) | ~2GB | Gut, schnell |
| mistral (7B) | ~4GB | Sehr gut |
| qwen2.5-coder:14b | ~8GB | Exzellent |
| qwen2.5:14b | ~8GB | Exzellent |
| llama3.3:70b-q4 | ~14GB | Beste |
| aya:35b-q4 | ~12GB | Beste fuer Uebersetzung |

## Whisper auf CPU vs GPU

Der Stack ist so konfiguriert, dass Whisper auf der CPU laeuft.
Dies hat folgende Vorteile:
- GPU bleibt frei fuer LLM-Inferenz
- Intel i5-14500 hat starke AVX-512 Unterstuetzung
- 64GB RAM erlaubt grosse Modelle

Falls GPU-Beschleunigung gewuenscht ist:
1. Kommentiere `whisper-api-gpu` in `compose.yaml` ein
2. Nutze Port 8001 statt 8000

## Fehlerbehebung

### Ollama startet nicht
```bash
# Logs pruefen
docker compose logs ollama

# GPU-Zugriff testen
docker exec -it ollama nvidia-smi
```

### Whisper API langsam
- Pruefe CPU-Auslastung
- Erwaege GPU-Version zu aktivieren
- Reduziere Modellgroesse auf `medium` statt `large-v3`

### LiteLLM Fehler
```bash
# Config validieren
docker compose logs litellm

# Manuell testen
curl http://localhost:4000/v1/models
```

### Modell nicht gefunden
```bash
# Verfuegbare Modelle auflisten
docker exec -it ollama ollama list

# Modell herunterladen
docker exec -it ollama ollama pull <model-name>
```

## API Referenz

### LiteLLM (OpenAI-kompatibel)
- Base URL: `http://localhost:4000/v1`
- Modelle: `http://localhost:4000/v1/models`
- Chat: `POST /v1/chat/completions`
- Completions: `POST /v1/completions`

### Whisper API (OpenAI-kompatibel)
- Base URL: `http://localhost:8000/v1`
- Transcription: `POST /v1/audio/transcriptions`
- Translation: `POST /v1/audio/translations`

### Ollama (Native API)
- Base URL: `http://localhost:11434`
- Chat: `POST /api/chat`
- Generate: `POST /api/generate`
- Models: `GET /api/tags`
