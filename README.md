# CaptuDorsal

Sistema de control de dorsales para eventos deportivos usando OCR en tiempo real.

## Caracteristicas

- **OCR en tiempo real** con Google ML Kit (reconocimiento de texto Latin)
- **Multiples dorsales** por captura (detecta varios competidores a la vez)
- **ROI configurable** (region de interes) para enfocar solo la zona de deteccion
- **Grabacion de video** con tracking de dorsales detectados
- **Revision de video** con navegacion por dorsal (salta al momento exacto)
- **Sonido nativo** (ToneGenerator + vibracion) al detectar dorsales
- **Modo Ahorro** atenúa la pantalla manteniendo deteccion y grabacion activas
- **Layout adaptativo** portrait/landscape
- **Persistencia CSV** con fecha completa + exportacion por dorsal
- **Confirmacion configurable** (N lecturas consecutivas para validar dorsal)

## Arquitectura

```
lib/
├── core/           Config, constantes, DI, logger
├── data/           Modelos, repositorios, servicios (camara, CSV, beep, sesion)
├── domain/         Casos de uso (ManageRecording)
├── platform/       OcrIsolate, FrameProcessor, BatteryOptimization
└── presentation/   Providers, screens, widgets, theme
```

**Stack:** Flutter 3.x · Provider · Clean Architecture · Google ML Kit · CameraX

## Pantallas

| Pantalla | Descripcion |
|-----------|-------------|
| **HomeScreen** | Camara preview + ROI + controles + historial |
| **SettingsScreen** | Config de dorsales, frecuencia, sonido, pantalla, ROI |
| **SessionsScreen** | Lista de grabaciones guardadas |
| **ReviewScreen** | Reproductor de video + lista de dorsales navegable |

## Configuracion

- **Frecuencia de escaneo:** 100-1500ms (default 500ms)
- **Digitos de dorsal:** 1-4 (configurable)
- **Confirmaciones:** 1-10 lecturas consecutivas (default 2)
- **ROI:** Rectangulo configurable desde Settings
- **Sonido:** Toggle on/off
- **Mantener pantalla:** Toggle wakelock

## Compilar

```bash
flutter pub get
flutter run                          # Debug en dispositivo
flutter build apk --release          # APK release
flutter analyze                      # Analisis estatico
flutter test                         # Tests unitarios
```

## Requisitos

- Flutter 3.x (Dart ^3.11.4)
- Android API 21+ (CameraX)
- Permiso de camara
- Dispositivo fisico (la camara no funciona en emulador con ML Kit)

## Limitaciones conocidas

- **OCR en main isolate**: ML Kit usa platform channels, no se puede aislar
- **Sin overlay en video**: El video no tiene texto quemado, solo metadata de timestamps
- **MIUI/Camera2**: `startImageStream` causa buffer overflow en Xiaomi, se usa `takePicture` timer-based
