import 'user_profile.dart';

abstract class UserProfileService {
  Future<UserProfile?> loadProfile({required String userId});

  Future<void> saveUsername({
    required String userId,
    required String email,
    required String username,
  });
}
