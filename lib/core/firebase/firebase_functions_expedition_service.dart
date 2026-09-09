import 'package:cloud_functions/cloud_functions.dart';

import '../../features/expeditions/domain/expedition.dart';
import '../../features/expeditions/domain/expedition_service.dart';
import 'firebase_functions_config.dart';

class FirebaseFunctionsExpeditionService implements ExpeditionService {
  FirebaseFunctionsExpeditionService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<ExpeditionLauncherInfo> fetchLauncherInfo() async {
    final callable = _functions.httpsCallable('getExpeditionLauncherInfo');
    final result = await callable.call();
    final data = result.data;
    if (data is! Map) {
      throw const FormatException('Invalid expedition launcher response.');
    }
    return ExpeditionLauncherInfo.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  @override
  Future<void> startExpedition({
    required List<String> survivorIds,
    required ExpeditionCoordinates coordinates,
    required List<String> actionIds,
  }) async {
    final callable = _functions.httpsCallable('startExpedition');
    await callable.call(<String, dynamic>{
      'survivorIds': survivorIds.map((id) => id.trim()).toList(growable: false),
      'coordinates': coordinates.toMap(),
      'actionIds': actionIds.map((id) => id.trim()).toList(growable: false),
    });
  }
}
