import '../config/state_persistence.dart';
import '../utils/logger.dart';
import '../../data/services/camera_service.dart';
import '../../data/services/csv_service.dart';
import '../../data/services/wake_lock_service.dart';
import '../../data/services/beep_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/screen_service.dart';
import '../../platform/services/battery_optimization_service.dart';
import '../../data/repositories/detection_repository.dart';
import '../../domain/usecases/manage_recording_usecase.dart';
import '../../presentation/providers/detection_provider.dart';
import '../../presentation/providers/camera_provider.dart';
import '../../presentation/providers/roi_provider.dart';
import '../../presentation/providers/dorsal_provider.dart';

class DependencyContainer {
  static final DependencyContainer _instance = DependencyContainer._internal();
  factory DependencyContainer() => _instance;
  DependencyContainer._internal();

  bool _isInitialized = false;

  late final StatePersistence _statePersistence;
  late final CameraService _cameraService;
  late final CsvService _csvService;
  late final WakeLockService _wakeLockService;
  late final BeepService _beepService;
  late final SessionService _sessionService;
  late final ScreenService _screenService;
  late final BatteryOptimizationService _batteryOptimizationService;
  late final DetectionRepository _detectionRepository;
  late final ManageRecordingUseCase _manageRecordingUseCase;
  late final DetectionProvider _detectionProvider;
  late final CameraProvider _cameraProvider;
  late final RoiProvider _roiProvider;
  late final DorsalProvider _dorsalProvider;
  late final AppLogger _logger;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _logger = AppLogger();
    _logger.info('Initializing dependency container...');

    _statePersistence = StatePersistence();
    await _statePersistence.initialize();

    _cameraService = CameraService();
    _csvService = CsvService();
    _wakeLockService = WakeLockService();
    _beepService = BeepService();
    await _beepService.initialize();
    _sessionService = SessionService();
    await _sessionService.initialize();
    _screenService = ScreenService();
    _batteryOptimizationService = BatteryOptimizationService();

    _detectionRepository = DetectionRepository(
      csvService: _csvService,
    );

    _manageRecordingUseCase = ManageRecordingUseCase(
      cameraService: _cameraService,
      wakeLockService: _wakeLockService,
      sessionService: _sessionService,
    );

    _detectionProvider = DetectionProvider(
      detectionRepository: _detectionRepository,
      beepService: _beepService,
      statePersistence: _statePersistence,
    );

    _manageRecordingUseCase.setSessionCallbacks(
      collectDorsals: () => _detectionProvider.endSession(),
      onSessionStart: (id) => _detectionProvider.startSession(id),
    );

    _cameraProvider = CameraProvider(
      cameraService: _cameraService,
      manageRecordingUseCase: _manageRecordingUseCase,
    );

    _roiProvider = RoiProvider(statePersistence: _statePersistence);
    _roiProvider.initialize();

    _dorsalProvider = DorsalProvider(statePersistence: _statePersistence);
    _dorsalProvider.initialize();

    _isInitialized = true;
    _logger.info('Dependency container initialized successfully');
  }

  StatePersistence get statePersistence => _statePersistence;
  CameraService get cameraService => _cameraService;
  CsvService get csvService => _csvService;
  WakeLockService get wakeLockService => _wakeLockService;
  BeepService get beepService => _beepService;
  SessionService get sessionService => _sessionService;
  ScreenService get screenService => _screenService;
  BatteryOptimizationService get batteryOptimizationService => _batteryOptimizationService;
  DetectionRepository get detectionRepository => _detectionRepository;
  ManageRecordingUseCase get manageRecordingUseCase => _manageRecordingUseCase;
  DetectionProvider get detectionProvider => _detectionProvider;
  CameraProvider get cameraProvider => _cameraProvider;
  RoiProvider get roiProvider => _roiProvider;
  DorsalProvider get dorsalProvider => _dorsalProvider;
  AppLogger get logger => _logger;

  Future<void> dispose() async {
    _logger.info('Disposing dependency container...');
    _detectionProvider.dispose();
    _cameraProvider.dispose();
    _csvService.dispose();
    _cameraService.dispose();
    _beepService.dispose();
    _isInitialized = false;
  }
}
