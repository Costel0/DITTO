class BunkerSetupResult {
  const BunkerSetupResult({
    required this.survivorId,
    required this.created,
  });

  final String survivorId;
  final bool created;
}

/// Trusted entry point used by the app to request initial bunker creation.
///
/// The Flutter client sends only player choices. The implementation is expected
/// to delegate validation and all authoritative writes to a backend service.
abstract interface class BunkerSetupService {
  Future<BunkerSetupResult> initializeBunker({
    required String username,
    required String duplicateId,
  });
}
