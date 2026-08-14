import 'survivor.dart';

abstract class SurvivorService {
  Future<List<Survivor>> loadSurvivors({required String userId});

  Future<void> saveInitialSurvivor({
    required String userId,
    required Survivor survivor,
  });

  Future<void> clearInitialSurvivor({required String userId});
}
