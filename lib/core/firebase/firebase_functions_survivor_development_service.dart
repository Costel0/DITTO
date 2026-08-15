import 'package:cloud_functions/cloud_functions.dart';

import '../../features/survivors/domain/survivor_development_service.dart';
import 'firebase_functions_config.dart';

class FirebaseFunctionsSurvivorDevelopmentService
    implements SurvivorDevelopmentService {
  FirebaseFunctionsSurvivorDevelopmentService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<String> addSurvivorForTesting({required String duplicateId}) async {
    final callable = _functions.httpsCallable('addSurvivorForTesting');
    final result = await callable.call(<String, dynamic>{
      'duplicateId': duplicateId.trim(),
    });

    final data = result.data;
    if (data is! Map) {
      throw const FormatException(
        'addSurvivorForTesting returned invalid data.',
      );
    }

    final survivorId = data['survivorId'];
    if (survivorId is! String || survivorId.isEmpty) {
      throw const FormatException(
        'addSurvivorForTesting did not return a survivorId.',
      );
    }

    return survivorId;
  }
}
