import 'expedition.dart';

abstract interface class ExpeditionService {
  Future<ExpeditionLauncherInfo> fetchLauncherInfo();

  Future<void> startExpedition({
    required List<String> survivorIds,
    required ExpeditionCoordinates coordinates,
    required List<String> actionIds,
  });
}
