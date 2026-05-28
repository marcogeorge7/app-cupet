import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.lastSeenAt,
    this.createdAt,
    this.petsCount = 0,
  });

  final int id;
  final String? name;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  /// Number of pets the user owns. Drives the mandatory onboarding gate:
  /// a user with no pets has not finished registration.
  final int petsCount;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String?,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      lastSeenAt: parse(json['last_seen_at']),
      createdAt: parse(json['created_at']),
      petsCount: (json['pets_count'] as num?)?.toInt() ?? 0,
    );
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    int? petsCount,
    bool clearEmail = false,
    bool clearAvatarUrl = false,
    bool clearName = false,
  }) {
    return AppUser(
      id: id,
      name: clearName ? null : (name ?? this.name),
      phone: phone ?? this.phone,
      email: clearEmail ? null : (email ?? this.email),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      petsCount: petsCount ?? this.petsCount,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, phone, email, avatarUrl, lastSeenAt, createdAt, petsCount];
}
