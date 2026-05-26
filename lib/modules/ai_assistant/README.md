# Módulo AI Assistant

## Arquitectura general

```
dart_openai (cliente)
     ↕  formato OpenAI (tools, messages, audio)
shelf server (localhost:8080)
     ↕
├── POST /v1/chat/completions   →  FlutterLlama (modelo GGUF local)
└── POST /v1/audio/transcriptions →  Whisper (modelo .bin local)
```

## Estructura del módulo

```
lib/modules/ai_assistant/
├── ai_assistant_module.dart         # Barrel exports
├── README.md                        # Este archivo
│
├── models/
│   ├── chat_message.dart            # Modelo ChatMessage (role, content)
│   └── react_event.dart             # Eventos del loop ReAct
│
├── screens/
│   └── chat_screen.dart             # UI del chat con botón 🎤
│
├── services/
│   ├── chat_engine.dart             # Orquestador: server + loop + audio
│   ├── chat_loop.dart               # Loop ReAct con dart_openai + tools
│   ├── chat_theme.dart              # Tema del chat extraído
│   ├── local_api_server.dart        # Servidor shelf (2 endpoints)
│   ├── tool_definitions.dart        # Tools + conversión a OpenAI format
│   └── tool_executor.dart           # Ejecuta tools (CRUD vía API)
│
└── audio/
    ├── audio_model.dart             # Whisper wrapper (init, transcribe, dispose)
    ├── audio_recorder.dart          # MicCapture (grabar WAV 16kHz mono)
    └── audio_handler.dart           # Handler shelf para /v1/audio/transcriptions
```

## Dependencias agregadas

```yaml
dependencies:
  shelf: ^1.4.2
  shelf_router: ^1.1.4
  dart_openai: ^5.1.0
  whisper_ggml: ^1.4.0
  record: ^5.0.0
  path_provider: ^2.1.0
```

## Archivos creados (6 nuevos)

| Archivo | Líneas | Propósito |
|---|---|---|
| `services/chat_theme.dart` | 18 | Tema del chat extraído |
| `audio/audio_model.dart` | 64 | Inicializa whisper.cpp, transcribe audio |
| `audio/audio_recorder.dart` | 39 | Graba micrófono, devuelve WAV |
| `audio/audio_handler.dart` | 35 | Endpoint shelf para transcripciones |
| `services/local_api_server.dart` | 177 | (modificado) + /v1/audio/transcriptions |
| `services/chat_engine.dart` | 70 | (modificado) + AudioModel + MicCapture |

## Archivos eliminados (3)

| Archivo | Reemplazado por |
|---|---|
| `services/react_engine.dart` | `chat_loop.dart` + `local_api_server.dart` |
| `services/llm_service.dart` | `local_api_server.dart` (usa FlutterLlama directo) |
| `services/permission_service.dart` | Ya no se necesita |

## Archivos movidos (2)

| De | A |
|---|---|
| `lib/services/agent/chat_loop.dart` | `lib/modules/ai_assistant/services/chat_loop.dart` |
| `lib/services/agent/local_api_server.dart` | `lib/modules/ai_assistant/services/local_api_server.dart` |

## Pendiente / Próximos pasos

1. **Descargar modelo whisper**: `ggml-tiny.bin` (~75MB) desde HuggingFace a `/storage/emulated/0/ggml-tiny.bin`
2. **Inicializar AudioModel** en el flujo de inicio con la ruta del modelo whisper
3. **Probar grabación y transcripción** en dispositivo físico Android
4. **(Opcional) Soporte multipart** en `/v1/audio/transcriptions` para compatibilidad total con `dart_openai` audio API
5. **(Opcional) Streaming** de audio para transcripción en tiempo real
6. **(Opcional) Agregar selector de modelo** whisper (tiny/base/small) en la UI

## Notas

- Todos los archivos del módulo están bajo 200 líneas
- `chat_screen.dart` tiene 189 líneas
- El análisis de flutter pasa sin errores ni warnings (solo 3 infos de terceros)
- El servidor shelf se inicia al entrar al chat y se detiene al salir
- Whisper se inicializa con español (`language: 'es'`)
- La grabación captura 5 segundos por defecto
