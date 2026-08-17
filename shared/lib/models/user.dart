enum UserRole { trainer, member }

class User {
  final String id;
  final UserRole role;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? assignedTrainerId;

  const User({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.assignedTrainerId,
  });
}
