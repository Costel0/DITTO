import 'user_profile.dart';

abstract class UserProfileService {
  Future<UserProfile?> loadProfile({required String userId});

  Future<void> saveInitialProfile({
    required String userId,
    required String email,
    required String username,
    required String characterId,
  });

  Future<void> clearInitialProfile({required String userId});
}
