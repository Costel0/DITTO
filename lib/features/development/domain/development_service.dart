/// Server-backed tools used only while developing and testing DITTO.
///
/// Keeping all temporary mutations behind this interface makes the entire
/// development surface easy to remove, replace with admin-only tooling, or
/// disable for production builds without touching gameplay services.
abstract interface class DevelopmentService {
  Future<String> addSurvivorForTesting({required String duplicateId});

  Future<int> addItemForTesting({
    required String itemId,
    required int quantity,
  });

  Future<void> resetTaskTreeForTesting();

  Future<void> resetUserForTesting();
}

/// Transport-neutral error exposed by the development service layer.
///
/// Firebase-specific exceptions are converted to this type so presentation and
/// application code can inspect useful diagnostics without importing Firebase.
class DevelopmentServiceException implements Exception {
  const DevelopmentServiceException({
    required this.operation,
    required this.code,
    this.message,
    this.details,
  });

  final String operation;
  final String code;
  final String? message;
  final Object? details;

  @override
  String toString() {
    return 'DevelopmentServiceException('
        'operation: $operation, '
        'code: $code, '
        'message: ${message ?? '<none>'}, '
        'details: ${details ?? '<none>'}'
        ')';
  }
}
