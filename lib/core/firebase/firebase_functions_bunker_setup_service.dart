import 'package:cloud_functions/cloud_functions.dart';

import '../../features/bunker/domain/bunker_setup_service.dart';

class FirebaseFunctionsBunkerSetupService implements BunkerSetupService {
  FirebaseFunctionsBunkerSetupService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: functionsRegion);

  static const String functionsRegion = 'europe-west1';

  final FirebaseFunctions _functions;

  @override
  Future<BunkerSetupResult> initializeBunker({
    required String username,
    required String duplicateId,
  }) async {
    final callable = _functions.httpsCallable('initializeBunker');
    final result = await callable.call(<String, dynamic>{
      'username': username.trim(),
      'duplicateId': duplicateId.trim(),
    });

    final data = result.data;
    if (data is! Map) {
      throw const FormatException('initializeBunker returned invalid data.');
    }

    final survivorId = data['survivorId'];
    if (survivorId is! String || survivorId.isEmpty) {
      throw const FormatException(
        'initializeBunker did not return a survivorId.',
      );
    }

    return BunkerSetupResult(
      survivorId: survivorId,
      created: data['created'] == true,
    );
  }
}
