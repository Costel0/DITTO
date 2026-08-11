class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.username,
  });

  final String userId;
  final String email;
  final String? username;

  bool get hasUsername => username != null && username!.trim().isNotEmpty;
}
