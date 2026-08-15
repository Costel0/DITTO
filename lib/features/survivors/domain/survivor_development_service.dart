abstract interface class SurvivorDevelopmentService {
  Future<String> addSurvivorForTesting({required String duplicateId});

  Future<void> resetUserForTesting();
}
