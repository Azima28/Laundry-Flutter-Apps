class UserModel {
  final int? id;
  final String username;
  final String password;
  final String role; // 'admin' or 'user'
  final bool isActive;

  UserModel({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      role: map['role'],
      isActive: map['is_active'] == 1,
    );
  }
}
