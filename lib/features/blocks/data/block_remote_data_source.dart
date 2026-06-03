import 'package:dio/dio.dart';

class BlockRemoteDataSource {
  BlockRemoteDataSource(this._dio);

  final Dio _dio;

  Future<void> blockUser({required int userId, String? reason}) async {
    await _dio.post('/blocks', data: {
      'blocked_user_id': userId,
      'reason': ?reason,
    });
  }

  Future<void> unblockUser(int userId) async {
    await _dio.delete('/blocks/$userId');
  }

  Future<List<BlockedUser>> fetchBlocked() async {
    final res = await _dio.get('/blocks');
    final list = (res.data['data'] as List?) ?? const [];
    return list
        .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
    this.name,
    this.avatarUrl,
    this.blockedAt,
  });

  final int userId;
  final String? name;
  final String? avatarUrl;
  final DateTime? blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        userId: json['user_id'] as int,
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        blockedAt: json['blocked_at'] != null
            ? DateTime.tryParse(json['blocked_at'] as String)
            : null,
      );
}
