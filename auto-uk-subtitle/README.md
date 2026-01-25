# Auto UK Subtitle

Automatische Untertitel-Transkription und Uebersetzung von Deutsch nach Ukrainisch.

## Architektur

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Auto UK Subtitle Service                             │
│                              (Port 8085)                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│   │   Web UI    │    │  REST API   │    │  Job Queue  │                    │
│   │  (Browser)  │───▶│  (FastAPI)  │───▶│   (Redis)   │                    │
│   └─────────────┘    └─────────────┘    └─────────────┘                    │
│                             │                   │                           │
│                             ▼                   ▼                           │
│                      ┌─────────────────────────────────────┐               │
│                      │       Processing Pipeline           │               │
│                      │  ┌───────────┐  ┌───────────────┐  │               │
│                      │  │ Whisper   │  │  Translation  │  │               │
│                      │  │ Service   │  │   Service     │  │               │
│                      │  └─────┬─────┘  └───────┬───────┘  │               │
│                      └────────┼────────────────┼──────────┘               │
│                               │                │                           │
└───────────────────────────────┼────────────────┼───────────────────────────┘
                                │                │
                                ▼                ▼
                    ┌───────────────┐  ┌───────────────┐
                    │  Whisper API  │  │    LiteLLM    │
                    │  (ai-stack)   │  │  (ai-stack)   │
                    │   :8000       │  │    :4000      │
                    └───────────────┘  └───────────────┘
```

## Voraussetzungen

1. **ai-stack** muss laufen mit:
   - Whisper API (Port 8000)
   - LiteLLM (Port 4000)
   - Ollama mit `aya-expanse:8b` Modell

2. **Ollama Modell installieren** (einmalig):
   ```bash
   docker exec -it ollama ollama pull aya-expanse:8b
   ```

## Installation

1. **Konfiguration erstellen:**
   ```bash
   cp .env.example .env
   # Bearbeite .env und setze APP_SOURCE_PATH
   ```

2. **Stack starten:**
   ```bash
   docker compose -p auto-uk-subtitle up -d --build
   ```

3. **Web UI oeffnen:**
   ```
   http://localhost:8085
   ```

## Workflow

```
Video Datei
     │
     ▼
┌────────────────┐
│ Suche nach     │
│ existierenden  │───▶ UK/RU Untertitel gefunden? ───▶ Fertig (keine Uebersetzung)
│ Untertiteln    │
└────────────────┘
     │
     │ DE Untertitel gefunden?
     ▼
┌────────────────┐         ┌────────────────┐
│ Spot-Check     │───OK───▶│ Uebersetze     │───▶ Fertig
│ Verifikation   │         │ DE → UK        │
└────────────────┘         └────────────────┘
     │
     │ Nicht OK / Keine Untertitel
     ▼
┌────────────────┐         ┌────────────────┐
│ Whisper        │────────▶│ Uebersetze     │───▶ Fertig
│ Transkription  │         │ DE → UK        │
└────────────────┘         └────────────────┘
```

## API Endpunkte

| Endpoint | Method | Beschreibung |
|----------|--------|--------------|
| `/api/health` | GET | Service Status |
| `/api/models` | GET | Verfuegbare Modelle |
| `/api/jobs` | GET | Jobs auflisten |
| `/api/jobs` | POST | Neuen Job erstellen |
| `/api/jobs/{id}` | GET | Job Status |
| `/api/jobs/{id}` | DELETE | Job abbrechen |
| `/api/jobs/{id}/result` | GET | Ergebnis herunterladen |
| `/api/jobs/{id}/events` | GET (SSE) | Live Updates |
| `/api/files` | GET | Datei-Browser |
| `/api/transcribe` | POST | Direkte Transkription |
| `/api/translate` | POST | Direkte Uebersetzung |

## Job erstellen (API)

```bash
curl -X POST http://localhost:8085/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "video_path": "Serien/MeineSerie/S01E01.mkv",
    "force_transcription": false,
    "force_translation": false,
    "source_language": "de",
    "target_language": "uk"
  }'
```

## Konfiguration

### Umgebungsvariablen

| Variable | Default | Beschreibung |
|----------|---------|--------------|
| `MEDIA_PATH` | `/mnt/qnap/Multimedia` | Pfad zu Video-Dateien |
| `WHISPER_API_URL` | `http://whisper-api:8000` | Whisper API URL |
| `LLM_API_URL` | `http://litellm:4000/v1` | LiteLLM API URL |
| `LLM_TRANSLATION_MODEL` | `aya-expanse:8b` | Modell fuer Uebersetzung |
| `MAX_PARALLEL_JOBS` | `2` | Max. parallele Jobs |
| `TRANSLATION_CHUNK_SIZE` | `25000` | Zeichen pro Chunk |

### Empfohlene Modelle fuer DE→UK

1. **aya-expanse:8b** (Standard) - Gute Qualitaet, schnell
2. **aya-expanse:32b** - Beste Qualitaet, langsamer
3. **qwen2.5:14b** - Alternative, gute mehrsprachige Unterstuetzung

## Fehlerbehebung

### Service nicht erreichbar
```bash
# Logs pruefen
docker logs auto-uk-subtitle

# Health check
curl http://localhost:8085/api/health
```

### Whisper/LLM nicht verfuegbar
```bash
# ai-stack Status pruefen
docker compose -p ai-stack ps

# Ollama Modelle pruefen
docker exec -it ollama ollama list
```

### Uebersetzung langsam
- Groesseres Modell verwenden (32b statt 8b)
- `TRANSLATION_CHUNK_SIZE` reduzieren
- `MAX_PARALLEL_JOBS` erhoehen (mehr RAM/VRAM noetig)
