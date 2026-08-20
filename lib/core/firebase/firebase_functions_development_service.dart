import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  /// Development callables are intentionally strict about security token
  /// freshness so App Check/Auth setup problems are surfaced before the
  /// request reaches Cloud Functions.
  ///
  /// No token value is exposed in errors or logs. We only verify that Firebase
  /// can obtain a fresh token immediately before invoking the callable.
  Future<void> _refreshSecurityTokens(String operation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DevelopmentServiceException(
        operation: operation,
        code: 'auth-current-user-null',
        message: 'FirebaseAuth.currentUser is null before the callable.',
      );
    }

    try {
      final authToken = await user.getIdToken(true);
      if (authToken == null || authToken.isEmpty) {
        throw DevelopmentServiceException(
          operation: operation,
          code: 'auth-token-empty',
          message: 'Firebase Auth returned an empty ID token.',
        );
      }
    } on DevelopmentServiceException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: operation,
          code: 'auth-token-${error.code}',
          message: error.message,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: operation,
          code: 'auth-token-refresh-failed',
          message: error.toString(),
        ),
        stackTrace,
      );
    }

    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken(true);
      if (appCheckToken == null || appCheckToken.isEmpty) {
        throw DevelopmentServiceException(
          operation: operation,
          code: 'app-check-token-empty',
          message: 'Firebase App Check returned an empty token.',
        );
      }
    } on DevelopmentServiceException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: operation,
          code: 'app-check-token-${error.code}',
          message: error.message,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: operation,
          code: 'app-check-token-refresh-failed',
          message: error.toString(),
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<String> addSurvivorForTesting({required String duplicateId}) async {
    const operation = 'addSurvivorForTesting';
    await _refreshSecurityTokens(operation);

    try {
      final callable = _functions.httpsCallable(operation);
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
          operation: operation,
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
    const operation = 'addItemForTesting';
    await _refreshSecurityTokens(operation);

    try {
      final callable = _functions.httpsCallable(operation);
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
          operation: operation,
          code: error.code,
          message: error.message,
          details: error.details,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> resetTaskTreeForTesting() async {
    const operation = 'resetTaskTreeForTesting';
    await _refreshSecurityTokens(operation);

    try {
      final callable = _functions.httpsCallable(operation);
      final result = await callable.call(<String, dynamic>{});

      final data = result.data;
      if (data is! Map || data['reset'] != true) {
        throw const FormatException(
          'resetTaskTreeForTesting returned invalid data.',
        );
      }
    } on FirebaseFunctionsException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DevelopmentServiceException(
          operation: operation,
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
    const operation = 'resetUserForTesting';
    await _refreshSecurityTokens(operation);

    try {
      final callable = _functions.httpsCallable(operation);
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
          operation: operation,
          code: error.code,
          message: error.message,
          details: error.details,
        ),
        stackTrace,
      );
    }
  }
}
