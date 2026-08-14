class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.username,
    required this.initialDuplicateId,
  });

  final String userId;
  final String email;
  final String? username;
  final String? initialDuplicateId;

  bool get hasUsername => username != null && username!.trim().isNotEmpty;
  bool get hasInitialDuplicate =>
      initialDuplicateId != null && initialDuplicateId!.trim().isNotEmpty;
}
