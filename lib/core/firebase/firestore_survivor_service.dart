import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/survivors/domain/survivor.dart';
import '../../features/survivors/domain/survivor_service.dart';

class FirestoreSurvivorService implements SurvivorService {
  FirestoreSurvivorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _survivors(String userId) =>
      _firestore.collection('users').doc(userId).collection('survivors');

  @override
  Future<List<Survivor>> loadSurvivors({required String userId}) async {
    final snapshot = await _survivors(userId).orderBy('createdAt').get();
    return snapshot.docs
        .map((document) {
          final data = document.data();
          final storedId = data['id'] as String?;
          return Survivor.fromMap(<String, dynamic>{
            ...data,
            'id': storedId != null && storedId.trim().isNotEmpty
                ? storedId.trim()
                : document.id,
          });
        })
        .where((survivor) => survivor.duplicateId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> saveInitialSurvivor({
    required String userId,
    required Survivor survivor,
  }) async {
    final survivorId = survivor.id.trim().isNotEmpty
        ? survivor.id.trim()
        : 'initial';
    final reference = _survivors(userId).doc(survivorId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = <String, dynamic>{
        ...survivor.toMap(),
        'id': survivorId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(reference, data, SetOptions(merge: true));
    });
  }
}
