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

  Future<void> resetUserForTesting();
}
