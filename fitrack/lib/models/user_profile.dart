class UserProfile {
  final String username;
  final String name;
  final String email;

  const UserProfile({
    required this.username,
    required this.name,
    required this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        username: json['username'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );

  /// Display name: prefer name if set, otherwise fall back to username.
  String get displayName => name.isNotEmpty ? name : username;
}
