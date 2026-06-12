# Informe de Optimización de Velocidad - Inferencia Local LLM

## 1. Trazado completo del flujo de mensaje

```
Usuario escribe texto en ChatScreen
  │
  ├─ chat_screen.dart:_handleSendText(text)
  │   Crea mensaje de usuario en UI
  │   Llama a _engine.sendMessage(text)
  │   Escucha Stream<ReActEvent> para tokens de respuesta
  │
  ├─ chat_engine.dart:sendMessage(text)
  │   Delega en _loop.processMessage(text)
  │
  ├─ chat_loop.dart:processMessage(text)
  │   Envía HTTP POST → http://127.0.0.1:8080/v1/chat/completions
  │   Body: { messages: [{role:user, content:text}], temperature:0.1, max_tokens:150 }
  │
  ├─ local_api_server.dart:_handleChatCompletions(request)
  │   Extrae messages del body
  │   Construye prompt con formato <|im_start|>role\ncontent<|im_end|>
  │   Llama a llama.generate(GenerationParams)
  │     maxTokens: 150 (default)
  │     temperature: 0.1 (default)
  │     topP: 0.9
  │     topK: 40
  │     repeatPenalty: 1.1
  │
  ├─ flutter_llama.dart (Dart)
  │   Envía params a través de MethodChannel 'flutter_llama'
  │
  └─ flutter_llama (Kotlin/C++ nativo)
      Configura llama_context_params con LlamaConfig:
        n_threads: 4 (default)
        n_gpu_layers: -1 (todas GPU)
        n_ctx: 2048 (contextSize default)
        n_batch: 512 (batchSize default)
        use_gpu: true
      Ejecuta inferencia en llama.cpp → GGUF model
```

## 2. Parámetros actuales por etapa

### Carga del modelo (chat_engine.dart → LlamaConfig)

| Parámetro       | Valor  | Default | Dónde se define                              |
|-----------------|--------|---------|----------------------------------------------|
| nThreads        | 4      | 4       | LlamaConfig en flutter_llama/lib/...         |
| nGpuLayers      | -1     | 0       | chat_engine.dart:52                          |
| contextSize     | 2048   | 2048    | LlamaConfig default                          |
| batchSize       | 512    | 512     | LlamaConfig default                          |
| useGpu          | true   | true    | LlamaConfig default                          |

### Generación (local_api_server.dart → GenerationParams)

| Parámetro      | Valor | Default | Dónde se define                |
|----------------|-------|---------|--------------------------------|
| maxTokens      | 150   | 512     | local_api_server.dart:62       |
| temperature    | 0.1   | 0.8     | local_api_server.dart:63       |
| topP           | 0.9   | 0.95    | local_api_server.dart:64       |
| topK           | 40    | 40      | GenerationParams default       |
| repeatPenalty  | 1.1   | 1.1     | GenerationParams default       |

### Llamada OpenAI (chat_loop.dart)

| Parámetro   | Valor | Dónde se define          |
|-------------|-------|--------------------------|
| temperature | 0.1   | chat_loop.dart:20        |
| maxTokens   | 150   | chat_loop.dart:21        |

### Diagnóstico real con datos de tu dispositivo (Redmi Note 15 Pro 4G - Helio G99)

| Prueba | nThreads | GPU | Tiempo (14 tok) | tok/s | Observación |
|--------|----------|-----|-----------------|-------|-------------|
| A | 2 | 0 | **5s** | 2.8 | Mejor resultado sin NEON |
| B | 4 | 0 | **75s** | 0.19 | Colapso por contención |
| C | 2 | 1 | **5s** | 2.8 | GPU no aporta |
| D | 2 | 2 | **8s** | 1.75 | GPU empeora |

**Conclusión:** El Helio G99 solo tiene **2 cores performance** (Cortex-A76 a 2.2GHz). Usar >2 threads los manda a los cores efficiency (Cortex-A55 a 2.0GHz), donde van lentísimos y la sincronización entre cores rápidos y lentos mata el rendimiento.

El rendimiento de ~2.8 tok/s es **anormalmente bajo** para 1.5B Q4_K_M → la causa es que llama.cpp se compiló sin optimizaciones ARM.

## 3. Cuellos de botella identificados

### A. Prompt sin límite (crítico)
- `_buildPrompt()` en `local_api_server.dart:125-143` acumula **todo el historial** del body
- Cada mensaje nuevo añade más tokens al prompt
- El prompt processing (prefilling) escala O(n²) con el largo del prompt
- **Solución**: Truncar a últimos 3 mensajes (~2000 chars)

### B. nGpuLayers = -1 (depende del dispositivo)
- En GPUs integradas (Adreno, Mali) la transferencia CPU↔GPU puede ser más lenta que CPU puro
- **Solución**: Probar `nGpuLayers: 0` como alternativa

### C. nThreads = 4
- Dispositivos modernos tienen 8+ cores (big.LITTLE: 4 performance + 4 efficiency)
- 4 threads puede no aprovechar todos los cores de performance
- **Solución**: Probar 6-8

### D. contextSize = 2048
- Procesa hasta 2048 tokens de prompt aunque no se necesiten
- Más contexto = más memoria y más tiempo de prefill
- **Solución**: Reducir a 1024 si no se necesitan conversaciones largas

### E. maxTokens = 150
- Cada token de generación toma ~20-50ms
- 150 tokens → ~3-7.5 segundos solo de generación
- **Solución**: 100 tokens para respuestas más rápidas

### F. batchSize = 512
- Adecuado, pero en dispositivos con poca RAM puede causar swapping
- **Solución**: 256 si hay problemas de memoria

### G. **(CAUSA RAÍZ) llama.cpp compilado sin NEON/SIMD para ARM** ← crítica

El archivo `packages/flutter_llama/android/build.gradle` define los flags de compilación de llama.cpp:

```groovy
arguments '-DGGML_VULKAN=ON'
```

Pero **no define** `GGML_CPU_ARM_ARCH`. Cuando está vacío, ggml compila las operaciones de matrices en **C++ genérico** sin usar las instrucciones SIMD del procesador ARM.

**Qué son NEON y SIMD:**
- **SIMD** (Single Instruction, Multiple Data): permite que una sola instrucción del CPU opere sobre **múltiples datos a la vez** (ej: sumar 4 números de 32 bits en un solo ciclo de reloj en lugar de 4 ciclos)
- **NEON**: es la implementación de SIMD de ARM (128-bit). En ARM64 está siempre disponible, pero el compilador necesita saber que puede usarlo
- **armv8.2-a**: extensión del conjunto de instrucciones ARMv8 que añade **dot product** (SDOT/UDOT) y **half-precision** (FP16), acelera muchísimo las multiplicaciones de matrices cuantizadas (Q4, Q5, Q8)

**El fix (primera versión):** agregar `-DGGML_CPU_ARM_ARCH=armv8.2-a` en los cmake arguments.

**Problema:** `-march=armv8.2-a` NO activa `__ARM_FEATURE_DOTPROD` en el NDK de Android. Solo activa NEON básico.

**El fix REAL (segunda versión):** `-DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod`

### ¿Por qué `+dotprod` es crítico?

En `ggml-cpu-impl.h:307-321`:
```c
#if !defined(__ARM_FEATURE_DOTPROD)
// FALLBACK — 12 instrucciones NEON en software:
inline static int32x4_t ggml_vdotq_s32(...) {
    const int16x8_t p0 = vmull_s8(vget_low_s8(a), vget_low_s8(b));  // mul
    const int16x8_t p1 = vmull_s8(vget_high_s8(a), vget_high_s8(b)); // mul
    return vaddq_s32(acc, vaddq_s32(vpaddlq_s16(p0), vpaddlq_s16(p1))); // add + widen
}
#else
#define ggml_vdotq_s32(a, b, c) vdotq_s32(a, b, c) // 1 instrucción nativa
#endif
```

Sin `+dotprod`:
- ❌ `__ARM_FEATURE_DOTPROD` no está definido
- ❌ Se usa el **fallback en software**: 12 instrucciones por cada dot product
- ❌ El Helio G99 tiene SDOT nativo en hardware, pero no se usa

Con `+dotprod`:
- ✅ `__ARM_FEATURE_DOTPROD` se define
- ✅ `vdotq_s32` nativo: **1 instrucción** en lugar de 12
- ✅ ~4-5x más rápido en operaciones cuantizadas

Además, en `arch/arm/quants.c:766` hay código adicional optimizado para SDOT:
```c
#if defined(__ARM_FEATURE_DOTPROD)
    vdotq_s32(...)  // Código optimizado con SDOT
#else
    // Código NEON sin dot product (más lento)
#endif
```

## 4. Recomendaciones por orden de impacto (ACTUALIZADO)

| # | Cambio | Código | Ganancia estimada |
|---|--------|--------|-------------------|
| **0** | **⚠️ Activar DOTPROD (`armv8.2-a+dotprod`)** | packages/flutter_llama/android/build.gradle | **~4-5x** (2.8 → **12-15 tok/s**) |
| 1 | **Limitar historial** a últimos 3 mensajes | local_api_server.dart | 5-10% adicional |
| 2 | **Reducir contextSize** de 2048 → 1024 | chat_engine.dart (LlamaConfig) | 5-10% adicional |
| 3 | **Mantener nThreads=2** (solo 2 cores performance en G99) | chat_engine.dart (LlamaConfig) | ya está |
| 4 | **Desactivar GPU** (Vulkan no acelera en Mali-G57 para Q4) | chat_engine.dart (LlamaConfig) | evita lag en UI |

## 5. Explicación detallada del cambio clave

### ¿Qué cambia exactamente?

**Antes** (flag vacío):
```cpp
// ggml compila las matrices así (C++ genérico):
for (int i = 0; i < n; i++) {
    sum += a[i] * b[i];  // 1 multiplicación por ciclo
}
```

**Después** (con GGML_CPU_ARM_ARCH=armv8.2-a):
```cpp
// ggml compila con NEON:
float32x4_t va = vld1q_f32(&a[i]);
float32x4_t vb = vld1q_f32(&b[i]);
float32x4_t vsum = vmlaq_f32(vsum, va, vb);
// 4 multiplicaciones en 1 ciclo
```

Para modelos cuantizados (Q4_K_M), la ganancia es aún mayor porque usa instrucciones **SDOT** que hacen multiplicaciones de enteros de 8 bits con acumulación de 32 bits en una sola instrucción — exactamente lo que necesita la des-cuantización y multiplicación de matrices.

### ¿Por qué 4+ threads empeoraba tanto?

Sin NEON, cada thread hace trabajo **ineficiente** (espera memoria, ejecuta código serial). Con NEON, el trabajo de cada thread es tan eficiente que 2 threads performance (Cortex-A76) bastan y sobran. Los threads extra solo compiten por el bus de memoria y causan contención.

### Velocidad esperada después del fix

| Dispositivo | Antes (sin NEON) | Después (con NEON) |
|-------------|-----------------|-------------------|
| Helio G99 (G76 perf + 6 A55) | ~2-4 tok/s | **~15-25 tok/s** |
| Helio G99 (SDOT desactivado) | ~2.8 tok/s | — |
| Helio G99 (SDOT activado) | — | **~12-15 tok/s** |
| Prompt "hola" + 14 tokens | **~5s** | **~1-1.5s** |

### Configuración optimizada recomendada (chat_engine.dart)

```dart
final config = LlamaConfig(
  modelPath: modelPath,
  nThreads: 6,
  nGpuLayers: -1,     // Probar también con 0
  contextSize: 1024,
  batchSize: 256,
  useGpu: true,
);
```

### Prompt truncado recomendado (local_api_server.dart)

```dart
String _buildPrompt(List<dynamic> messages) {
  // Mantener solo últimos 3 mensajes
  final recent = messages.length > 3 ? messages.sublist(messages.length - 3) : messages;
  final buf = StringBuffer();
  for (final msg in recent) {
    final role = msg['role'] as String;
    final content = msg['content'];
    String contentStr;
    if (content is String) {
      contentStr = content;
    } else if (content is List) {
      contentStr = content.map((c) => (c['text'] as String?) ?? '').join('\n');
    } else {
      contentStr = '';
    }
    // Limitar cada mensaje a 1000 caracteres
    if (contentStr.length > 1000) contentStr = contentStr.substring(0, 1000);
    buf.writeln('<|im_start|>$role');
    buf.writeln(contentStr);
    buf.writeln('<|im_end|>');
  }
  buf.writeln('<|im_start|>assistant');
  return buf.toString();
}
```

## 6. Opción de cambio de modelo

Se agregó un selector en la pantalla de chat para cambiar entre:

- **Modelo actual**: `neuralqwen-2.5-1.5b-spanish.Q4_K_M.gguf`
  - Fine-tune español, 1.5B params, Q4_K_M
  - Especializado en español, mejor calidad conversacional

- **Modelo alternativo**: `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf`
  - Misma arquitectura base (Qwen2.5), 1.5B params, Q4_K_M
  - Versión instruct original (sin fine-tune español)
  - Potencialmente más rápido por menor vocabulario/mayor eficiencia

### Cómo usarlo:
1. Toca el nombre del modelo en la AppBar
2. Selecciona el modelo deseado del menú desplegable
3. El modelo se descargará (si es necesario) y cargará automáticamente
4. La conversación actual se mantiene

## 7. Medición de velocidad

Para medir tokens por segundo reales, revisa el log impreso por `local_api_server.dart`:

```
---------- LLM RESPONSE ----------
<texto generado>
tokens: <N> | <tiempo>ms
----------------------------------
```

Tokens/s = tokens / (tiempo_ms / 1000)

### Valores de referencia esperados (1.5B Q4_K_M):

| Dispositivo | GPU (nGpuLayers=-1) | CPU (nGpuLayers=0) |
|-------------|---------------------|--------------------|
| Snapdragon 8 Gen 3 | ~40-50 tok/s | ~25-35 tok/s |
| Snapdragon 8 Gen 2 | ~30-40 tok/s | ~20-30 tok/s |
| Snapdragon 7 Gen 1 | ~15-25 tok/s | ~10-18 tok/s |
| MediaTek Dimensity | ~20-30 tok/s | ~15-22 tok/s |
| Helio G99 (sin NEON) | ~1-3 tok/s | ~2-4 tok/s |
| Helio G99 (NEON sin SDOT) | ~2-4 tok/s | ~3-5 tok/s |
| Helio G99 (NEON + SDOT) | ~10-15 tok/s | **~15-25 tok/s** (óptimo: 2 threads A76) |

Si estás por debajo de estos valores, aplica las optimizaciones de la sección 4.
