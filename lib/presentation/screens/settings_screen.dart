import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/dependency_container.dart';
import '../../presentation/providers/detection_provider.dart';
import '../../presentation/providers/dorsal_provider.dart';
import '../../presentation/providers/roi_provider.dart';
import '../../platform/services/ocr_isolate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _throttleMs = 500;
  int _requiredReads = 2;
  bool _soundEnabled = true;
  bool _keepScreenOn = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllSettings());
  }

  void _loadAllSettings() async {
    try {
      final container = DependencyContainer();
      if (!container.isInitialized) {
        await container.initialize();
      }
      final saved = container.statePersistence.loadOcrSensitivity();
      final reads = container.statePersistence.loadRequiredReads();
      final sound = container.statePersistence.loadSoundEnabled();
      final keepScreen = container.statePersistence.loadKeepScreenOn();
      if (mounted) {
        setState(() {
          _throttleMs = saved.throttleMs.toDouble();
          _requiredReads = reads;
          _soundEnabled = sound;
          _keepScreenOn = keepScreen;
        });
        final detectionProvider = context.read<DetectionProvider>();
        detectionProvider.setRequiredReads(_requiredReads);
        detectionProvider.setSoundEnabled(_soundEnabled);
      }
    } catch (e) {
      // Keep defaults if loading fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[900],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DorsalConfigSection(),
            const SizedBox(height: 20),
            _OcrSensitivitySection(
              throttleMs: _throttleMs,
              onThrottleChanged: (v) => setState(() => _throttleMs = v),
              onSave: _saveOcrSettings,
            ),
            const SizedBox(height: 20),
            _RequiredReadsSection(
              requiredReads: _requiredReads,
              onChanged: (v) => setState(() => _requiredReads = v.toInt()),
              onSave: _saveRequiredReads,
            ),
            const SizedBox(height: 20),
            _SoundSection(
              soundEnabled: _soundEnabled,
              onChanged: _saveSoundSetting,
            ),
            const SizedBox(height: 20),
            _KeepScreenOnSection(
              keepScreenOn: _keepScreenOn,
              onChanged: _saveKeepScreenOn,
            ),
            const SizedBox(height: 20),
            _RoiConfigSection(),
            const SizedBox(height: 20),
            _AboutSection(),
          ],
        ),
      ),
    );
  }

  void _saveOcrSettings() async {
    try {
      OcrIsolate.updateThrottle(_throttleMs);

      final container = DependencyContainer();
      if (!container.isInitialized) {
        await container.initialize();
      }
      await container.statePersistence.saveOcrSensitivity(
        throttleMs: _throttleMs.toInt(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Frecuencia guardada: ${_throttleMs.toInt()}ms'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar sensibilidad OCR'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _saveRequiredReads() async {
    try {
      final container = DependencyContainer();
      if (!container.isInitialized) {
        await container.initialize();
      }
      await container.statePersistence.saveRequiredReads(_requiredReads);

      if (!mounted) return;
      final detectionProvider = context.read<DetectionProvider>();
      detectionProvider.setRequiredReads(_requiredReads);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirmaciones requeridas: $_requiredReads'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar confirmaciones'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _saveSoundSetting(bool enabled) async {
    setState(() => _soundEnabled = enabled);
    try {
      final container = DependencyContainer();
      if (!container.isInitialized) {
        await container.initialize();
      }
      await container.statePersistence.saveSoundEnabled(enabled);
      if (!mounted) return;
      final detectionProvider = context.read<DetectionProvider>();
      detectionProvider.setSoundEnabled(enabled);
      if (enabled) {
        container.beepService.beep(frequency: 1200, durationMs: 100);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar configuración de sonido'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _saveKeepScreenOn(bool enabled) async {
    setState(() => _keepScreenOn = enabled);
    try {
      final container = DependencyContainer();
      if (!container.isInitialized) {
        await container.initialize();
      }
      await container.statePersistence.saveKeepScreenOn(enabled);
      if (enabled) {
        await container.wakeLockService.activate();
      } else {
        await container.wakeLockService.deactivate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar configuración de pantalla'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _DorsalConfigSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DorsalProvider>(
      builder: (context, dorsalProvider, child) {
        final config = dorsalProvider.config;

        return Card(
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tag, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Dorsal / Placa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Configura los dígitos del número del competidor',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mínimo: ${config.minDigits}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Slider(
                            value: config.minDigits.toDouble(),
                            min: 1,
                            max: 6,
                            divisions: 5,
                            onChanged: (v) => dorsalProvider.updateMinDigits(v.toInt()),
                            activeColor: Colors.greenAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Máximo: ${config.maxDigits}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Slider(
                            value: config.maxDigits.toDouble(),
                            min: 1,
                            max: 6,
                            divisions: 5,
                            onChanged: (v) => dorsalProvider.updateMaxDigits(v.toInt()),
                            activeColor: Colors.greenAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rango actual:', style: TextStyle(color: Colors.white70)),
                      Text(
                        config.description,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickPreset(label: 'Exacto 4', min: 4, max: 4, provider: dorsalProvider),
                    _QuickPreset(label: '1-2', min: 1, max: 2, provider: dorsalProvider),
                    _QuickPreset(label: '1-3', min: 1, max: 3, provider: dorsalProvider),
                    _QuickPreset(label: '1-4', min: 1, max: 4, provider: dorsalProvider),
                    _QuickPreset(label: '3-6', min: 3, max: 6, provider: dorsalProvider),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => dorsalProvider.save(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickPreset extends StatelessWidget {
  final String label;
  final int min;
  final int max;
  final DorsalProvider provider;

  const _QuickPreset({
    required this.label,
    required this.min,
    required this.max,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = provider.config.minDigits == min && provider.config.maxDigits == max;

    return GestureDetector(
      onTap: () {
        provider.updateMinDigits(min);
        provider.updateMaxDigits(max);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.greenAccent : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.greenAccent : Colors.grey[600]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _OcrSensitivitySection extends StatelessWidget {
  final double throttleMs;
  final ValueChanged<double> onThrottleChanged;
  final VoidCallback onSave;

  const _OcrSensitivitySection({
    required this.throttleMs,
    required this.onThrottleChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final throttleLabel = throttleMs <= 200
        ? 'Muy rápido'
        : throttleMs <= 500
            ? 'Rápido'
            : throttleMs <= 1000
                ? 'Normal'
                : 'Lento (ahorra batería)';

    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: Colors.orangeAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Frecuencia de Escaneo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cada cuánto se captura y procesa la imagen',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Frecuencia de escaneo:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(throttleLabel, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: throttleMs,
              min: 100,
              max: 1500,
              divisions: 14,
              onChanged: onThrottleChanged,
              activeColor: Colors.orangeAccent,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Más rápido', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                Text('Más lento', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Aplicar y Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequiredReadsSection extends StatelessWidget {
  final int requiredReads;
  final ValueChanged<double> onChanged;
  final VoidCallback onSave;

  const _RequiredReadsSection({
    required this.requiredReads,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.fact_check, color: Colors.cyanAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Confirmaciones de Lectura',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Lecturas consecutivas iguales para validar',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lecturas requeridas:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  '$requiredReads',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: requiredReads.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: onChanged,
              activeColor: Colors.cyanAccent,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 (inmediato)', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                Text('10 (muy seguro)', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    requiredReads == 1 ? Icons.speed : Icons.shield,
                    color: requiredReads == 1 ? Colors.orangeAccent : Colors.cyanAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      requiredReads == 1
                          ? 'Registra inmediatamente (puede tener falsos positivos)'
                          : 'Requiere $requiredReads lecturas iguales para confirmar',
                      style: TextStyle(
                        color: requiredReads == 1 ? Colors.orangeAccent : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepScreenOnSection extends StatelessWidget {
  final bool keepScreenOn;
  final ValueChanged<bool> onChanged;

  const _KeepScreenOnSection({
    required this.keepScreenOn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                keepScreenOn ? Icons.screen_lock_rotation : Icons.lock_clock,
                color: keepScreenOn ? Colors.greenAccent : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Mantener Pantalla Encendida',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Evita que la pantalla se apague mientras usas la app. El usuario puede bloquear manualmente.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: keepScreenOn,
            onChanged: onChanged,
            activeThumbColor: Colors.greenAccent,
            title: Text(
              keepScreenOn ? 'Activado' : 'Desactivado',
              style: TextStyle(
                color: keepScreenOn ? Colors.greenAccent : Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _SoundSection extends StatelessWidget {
  final bool soundEnabled;
  final ValueChanged<bool> onChanged;

  const _SoundSection({
    required this.soundEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                soundEnabled ? Icons.volume_up : Icons.volume_off,
                color: soundEnabled ? Colors.greenAccent : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Sonido de Captura',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Pitido al detectar un dorsal confirmado',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: soundEnabled,
            onChanged: onChanged,
            activeThumbColor: Colors.greenAccent,
            title: Text(
              soundEnabled ? 'Activado' : 'Desactivado',
              style: TextStyle(
                color: soundEnabled ? Colors.greenAccent : Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _RoiConfigSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RoiProvider>(
      builder: (context, roiProvider, child) {
        final config = roiProvider.config;

        return Card(
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.crop, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Zona de Captura (ROI)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Área donde se buscarán los dorsales',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 16),
                _RoiSlider(
                  label: 'Ancho',
                  value: config.widthPercent,
                  min: AppConstants.minRoiWidthPercent,
                  max: AppConstants.maxRoiWidthPercent,
                  onChanged: roiProvider.updateWidth,
                ),
                _RoiSlider(
                  label: 'Alto',
                  value: config.heightPercent,
                  min: AppConstants.minRoiHeightPercent,
                  max: AppConstants.maxRoiHeightPercent,
                  onChanged: roiProvider.updateHeight,
                ),
                _RoiSlider(
                  label: 'Arriba',
                  value: config.topPercent,
                  min: 0.0,
                  max: 0.8,
                  onChanged: (v) => roiProvider.updatePosition(topPercent: v),
                ),
                _RoiSlider(
                  label: 'Izquierda',
                  value: config.leftPercent,
                  min: 0.0,
                  max: 0.8,
                  onChanged: (v) => roiProvider.updatePosition(leftPercent: v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          roiProvider.reset();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Zona reseteada (presiona Guardar para aplicar)'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await roiProvider.save();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Zona guardada: ${(config.widthPercent * 100).toInt()}% x ${(config.heightPercent * 100).toInt()}%'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoiSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _RoiSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white38, size: 20),
                SizedBox(width: 8),
                Text(
                  'Acerca de',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'App', value: AppConstants.appName),
            _InfoRow(label: 'Versión', value: AppConstants.appVersion),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          Text(value, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}
