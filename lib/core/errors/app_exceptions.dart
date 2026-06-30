abstract class AppException implements Exception {
  final String message;
  final dynamic originalError;

  const AppException(this.message, [this.originalError]);

  @override
  String toString() => '$runtimeType: $message';
}

class CameraException extends AppException {
  const CameraException(super.message, [super.originalError]);
}

class StorageException extends AppException {
  const StorageException(super.message, [super.originalError]);
}

class OcrException extends AppException {
  const OcrException(super.message, [super.originalError]);
}

class PermissionException extends AppException {
  const PermissionException(super.message, [super.originalError]);
}
