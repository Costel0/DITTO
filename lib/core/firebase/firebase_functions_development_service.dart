import 'package:cloud_functions/cloud_functions.dart';

import '../../features/development/domain/development_service.dart';
import 'firebase_functions_config.dart';

/// Firebase implementation for temporary development/testing commands.
///
/// All mutations go through callable Cloud Functions. The client never writes
/// these authoritative gameplay fields directly to Firestore.
class FirebaseFunctionsDevelopmentService implements DevelopmentService {
  FirebaseFunctionsDevelopmentService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<String> addSurvivorForTesting({required String duplicateId}) async {
    try {
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
    } on FirebaseFunctionsException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: 'addSurvivorForTesting',
          code: error.code,
          message: error.message,
          details: error.details,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<int> addItemForTesting({
    required String itemId,
    required int quantity,
  }) async {
    try {
      final callable = _functions.httpsCallable('addItemForTesting');
      final result = await callable.call(<String, dynamic>{
        'itemId': itemId.trim(),
        'quantity': quantity,
      });

      final data = result.data;
      if (data is! Map) {
        throw const FormatException('addItemForTesting returned invalid data.');
      }

      final resultingQuantity = data['quantity'];
      if (resultingQuantity is! num || resultingQuantity < 1) {
        throw const FormatException(
          'addItemForTesting did not return a valid quantity.',
        );
      }

      return resultingQuantity.toInt();
    } on FirebaseFunctionsException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: 'addItemForTesting',
          code: error.code,
          message: error.message,
          details: error.details,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> resetUserForTesting() async {
    try {
      final callable = _functions.httpsCallable('resetUserForTesting');
      final result = await callable.call(<String, dynamic>{
        'confirm': true,
      });

      final data = result.data;
      if (data is! Map || data['deleted'] != true) {
        throw const FormatException(
          'resetUserForTesting returned invalid data.',
        );
      }
    } on FirebaseFunctionsException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: 'resetUserForTesting',
          code: error.code,
          message: error.message,
          details: error.details,
        ),
        stackTrace,
      );
    }
  }
}
