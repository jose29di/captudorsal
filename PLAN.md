# PLAN.md - CaptuDorsal

## Información del Proyecto

| Campo | Valor |
|-------|-------|
| **Nombre** | CaptuDorsal |
| **Paquete** | `com.codevnexus.captudorsal` |
| **Framework** | Flutter 3.x (Dart) |
| **Plataforma** | Android |
| **OCR** | Google ML Kit (text_recognition, script Latin) |
| **Arquitectura** | Clean Architecture + Provider + DI |
| **Propósito** | Automatizar registro de dorsales en eventos deportivos |
| **Video** | Grabación + revisión con navegación por dorsales |

---

## Arquitectura del Proyecto

### Capas (Clean Architecture)

```
lib/
├── core/                    # Configuración, constantes, errores, utilidades
│   ├── config/              # Estado de persistencia (StatePersistence)
│   ├── constants/           # Constantes de la app (AppConstants)
│   ├── di/                  # Contenedor de inyección de dependencias (DependencyContainer)
│   └── utils/               # Logger
│
├── data/                    # Capa de datos
│   ├── models/              # Modelos (DetectionRecord, RecordingSession)
│   ├── repositories/        # Repositorios (DetectionRepository)
│   └── services/            # Servicios (Camera, CSV, WakeLock, Beep, Session)
│
├── domain/                  # Capa de dominio
│   └── usecases/            # Casos de uso (ManageRecording)
│
├── platform/                # Capa de plataforma
│   └── services/            # OcrIsolate, FrameProcessor, BatteryOptimization
│
└── presentation/            # Capa de presentación
    ├── providers/           # State management (Detection, Camera, Roi, Dorsal)
    ├── screens/             # Pantallas (Home, Settings, Sessions, Review)
    ├── widgets/             # Widgets reutilizables
    └── theme/               # Tema visual (AppTheme)
```

### Flujo de Datos

```
Cámara (takePicture cada 500ms via Timer)
    ↓
FrameProcessor (Timer.periodic → takePicture → file path)
    ↓
DetectionProvider.processImageFile(imagePath)
    ↓
OcrIsolate.processImageFile(imagePath)  ← ML Kit file-based
    ↓
    ├→ ML Kit Latin OCR (InputImage.fromFilePath)
    ├→ JPEG dimensiones + EXIF orientation (compute() en isolate)
    ├→ ROI Filtering (_isInsideRoi por block center)
    ├→ Filtro Formato (_validateAndCleanDorsal)
    ├→ Multi-dorsal extraction (todos los dorsales en el ROI)
    └→ Confirmation Count (N lecturas consecutivas iguales)
    ↓
DetectionProvider._handleDetection()
    ├→ UI (overlay + historial + beep nativo)
    ├→ Session tracking (si grabando)
    └→ CSV (buffer flush con fecha completa)
```

### IMPORTANTE: Arquitectura OCR

**NO usar startImageStream** — causa buffer overflow (Camera2 error code 3) en Xiaomi/MIUI.
Solo se usa `takePicture` Timer-based, que funciona durante grabación de video.

---

## Estado Actual del Proyecto

### Sprint 1-4: COMPLETADOS
- Infraestructura, Pipeline IA, Persistencia CSV, Optimización

### Sprint 5: Estabilidad de Cámara - COMPLETADO
- takePicture timer-based (sin startImageStream)
- Warmup 1.5s antes de primer takePicture
- Manejo de ImageCaptureException transitorio
- Reconexión automática preservando cámara seleccionada
- Filtro de errores ImageCapture en _onCameraError

### Sprint 6: Multi-dorsal + Grabación - COMPLETADO
- Extracción de múltiples dorsales por frame
- Doble pitido al iniciar captura (ToneGenerator nativo)
- Pitido al detectar dorsal confirmado
- Toggle de sonido en Configuración
- Botón de iniciar/pausar captura
- Throttle default reducido a 500ms

### Sprint 7: Revisión de Video - COMPLETADO
- Modelo RecordingSession con dorsales y offsets
- SessionService persiste sesiones en SharedPreferences
- Video copiado a documents/videos/ al detener grabación
- ReviewScreen con video player + lista de dorsales navegable
- SessionsScreen lista grabaciones pasadas
- Compartir video desde ReviewScreen
- Timer de duración de grabación en UI

### Sprint 8: Limpieza + Fixes - COMPLETADO
- Eliminado dead code (OcrService, ProcessFrameUseCase, ThrottleService, MotionDetectorService, ImageConverter, ForegroundService wrapper, history_screen)
- CSV con fecha completa (yyyy-MM-dd,HH:mm:ss.SSS)
- Cámara frontal preservada al reconectar
- compute() para _readJpegDimensions (isolate separado)
- Eliminados paquetes audioplayers y csv (no usados)
- Eliminado motionThreshold dead code

### Sprint 9: UX + Ahorro de Batería - COMPLETADO
- Layout adaptativo portrait/landscape (cámara izquierda, historial derecha)
- Cámara sin distorsión (BoxFit.cover con dimensiones correctas por orientación)
- Modo Ahorro: atenua pantalla al mínimo, OCR y grabación continúan
- Mantener Pantalla Encendida (toggle en Configuración con wakelock)
- Compartir listado de dorsales desde ReviewScreen (archivo .txt con minutos del video)
- Timer de duración de grabación en UI

---

## Archivos Clave

### `frame_processor.dart`
- Timer.periodic + takePicture (500ms default)
- Warmup 1.5s antes de primer takePicture
- pause()/resume() para control de captura
- Funciona durante grabación de video (takePicture compatible con VideoCapture)
- Guard defensivo: CameraException disposed → stop timer

### `ocr_isolate.dart`
- `processImageFile(String imagePath)` → `OcrIsolateResult` con `List<String> dorsals`
- `_readJpegDimensionsSync` ejecutado vía `compute()` en isolate separado
- Parse EXIF orientation (tags 6/8 = intercambiar dimensiones)
- ROI filtering por block center
- Multi-dorsal: extrae todos los dorsales válidos del ROI
- `_validateAndCleanDorsal`: rechaza vacíos, no numéricos, repetidos, 1 dígito

### `detection_provider.dart`
- `processImageFile` → itera dorsales → `_handleDetection` por cada uno
- `_handleDetection`: confirmation count + debounce + CSV + session tracking + beep
- `startSession(id)` / `endSession()` para tracking de dorsales durante grabación
- `setSoundEnabled(bool)` persistido en SharedPreferences
- `_safeNotify()` con Timer 50ms para evitar setState during build

### `manage_recording_usecase.dart`
- `startRecording()`: guarda startTime + sessionId, notifica a DetectionProvider
- `stopRecording()`: copia video a documents/videos/, crea RecordingSession, guarda en prefs
- `setSessionCallbacks`: conecta usecase con DetectionProvider

### `camera_service.dart`
- `ResolutionPreset.medium` (mejor que low para ML Kit)
- `reconnect()` preserva `_currentCameraIndex` (no resetea a cámara trasera)
- `_onCameraError` filtra errores ImageCapture transitorios
- `onStateChanged` callback notifica al CameraProvider

### `beep_service.dart`
- Usa MethodChannel nativo → ToneGenerator (STREAM_MUSIC)
- `beep()`: pitido + vibración nativa
- `doubleBeep()`: doble pitido al iniciar captura
- Fallback a SystemSound.play si canal nativo falla

### `screen_service.dart`
- MethodChannel nativo → WindowManager.screenBrightness
- `dimScreen()`: brillo a 0% (modo ahorro)
- `restoreBrightness()`: brillo al valor del sistema
- OCR y grabación continúan funcionando con pantalla atenuada

### `session_service.dart`
- `saveSession(RecordingSession)` → JSON en SharedPreferences
- `loadSessions()` → lista de sesiones
- `deleteSession(id)` → borra video + registro
- `copyVideoToSessionDir` → copia temp video a documents/videos/

### `review_screen.dart`
- VideoPlayerController.file carga video de la sesión
- Lista de dorsales con offset formateado (MM:SS)
- Al pulsar dorsal: `seekTo(Duration(milliseconds: offsetMs))` + auto-play
- Resalta dorsal más cercano a posición actual del video
- PopupMenu: compartir video (.mp4) o compartir listado (.txt con dorsales + minutos)

### `home_screen.dart`
- Layout adaptativo: portrait (cámara arriba, historial abajo) / landscape (cámara izquierda, historial derecha)
- Botones: captura ▶/⏸, grabaciones 📹, modo ahorro ☀, settings ⚙
- Modo ahorro: overlay oscuro, tocar para restaurar
- Warmup 1.5s antes de reanudar FrameProcessor
- Cámara con BoxFit.cover (sin distorsión ni bordes negros)

### `csv_service.dart`
- CSV con fecha completa: `Dorsal,Fecha_Hora` → `123,2026-06-30,14:32:15.123`
- Compatibilidad con formato viejo (solo hora) → usa fecha de hoy
- `rewriteAll(records)` sobrescribe CSV completo (para delete/update/clear)
- Buffer de 5 registros o 5 segundos para flush

---

## Configuración

### Cámara
```dart
CameraController(
  camera,
  ResolutionPreset.medium,
  enableAudio: false,
  imageFormatGroup: ImageFormatGroup.yuv420,
)
```

### OCR
```dart
_throttleMs = 500        // default (configurable 100-1500ms)
_minDigits = 1
_maxDigits = 4
// ROI: left=25%, top=35%, width=50%, height=30% (defaults)
```

### Dorsal Validation
```dart
// _validateAndCleanDorsal() rechaza:
// - Strings vacíos
// - Longitud fuera de [minDigits, maxDigits]
// - No numéricos
// - Patrón repetido (1111, 2222) cuando length > 2
// - Un solo dígito
```

---

## Dependencias

```yaml
dependencies:
  flutter
  cupertino_icons: ^1.0.8
  camera: ^0.11.0+2
  path_provider: ^2.1.5
  google_mlkit_text_recognition: ^0.14.0
  share_plus: ^10.1.4
  intl: ^0.20.2
  provider: ^6.1.2
  wakelock_plus: ^1.2.8
  permission_handler: ^11.3.1
  saver_gallery: ^4.1.2
  logger: ^2.5.0
  shared_preferences: ^2.3.4
  video_player: ^2.9.2
```

---

## Limitaciones Conocidas

1. **OCR en main isolate**: ML Kit usa platform channels que solo funcionan en el main isolate. No se puede mover el OCR a un isolate separado. Solo `_readJpegDimensions` se ejecuta vía `compute()`.
2. **Sin overlay en video**: El video grabado no tiene texto/hora sobreimpuesta. Solo metadata de timestamps para navegación en revisión.
3. **MIUI/Camera2**: `startImageStream` causa error code 3 (buffer overflow) en Xiaomi. Solo `takePicture` es compatible.
4. **CSV sin sesión ID**: El CSV agrupa por día, no por sesión de grabación. Las sesiones se guardan aparte en SharedPreferences.

---

## Comandos Útiles

```bash
flutter run                                    # Ejecutar en dispositivo
flutter build apk --release --target-platform android-arm64
flutter analyze                                # Analizar código
flutter test                                   # Ejecutar tests
flutter clean && flutter pub get               # Limpiar build
```

---

## Estado del Proyecto

| Sprint | Estado |
|--------|--------|
| Sprint 1: Infraestructura y UI | ✓ Completado |
| Sprint 2: Pipeline IA | ✓ Completado |
| Sprint 3: Persistencia CSV | ✓ Completado |
| Sprint 4: Optimización | ✓ Completado |
| Sprint 5: Estabilidad Cámara | ✓ Completado |
| Sprint 6: Multi-dorsal + Sonido | ✓ Completado |
| Sprint 7: Revisión de Video | ✓ Completado |
| Sprint 8: Limpieza + Fixes | ✓ Completado |
| Sprint 9: UX + Ahorro Batería | ✓ Completado |
