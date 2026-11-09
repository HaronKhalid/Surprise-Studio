class User {
  const User({required this.id, required this.email, this.displayName});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
      );

  final String id;
  final String email;
  final String? displayName;
}
