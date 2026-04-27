import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
  });

  final int id;
  final String? name;
  final String phone;
  final String? email;
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String?,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email, avatarUrl];
}
