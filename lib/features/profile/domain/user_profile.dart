class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.username,
    required this.characterId,
  });

  final String userId;
  final String email;
  final String? username;
  final String? characterId;

  bool get hasUsername => username != null && username!.trim().isNotEmpty;
  bool get hasCharacter =>
      characterId != null && characterId!.trim().isNotEmpty;
}
