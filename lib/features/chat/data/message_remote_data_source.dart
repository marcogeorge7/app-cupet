import 'package:dio/dio.dart';

import '../../../shared/models/message.dart';

class MessageRemoteDataSource {
  MessageRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<ChatMessage>> list(int conversationId, {int? beforeId}) async {
    final response = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {
        'before_id': ?beforeId,
      },
    );
    final list = (response.data as Map<String, dynamic>)['data'] as List;
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> send(int conversationId, String body) async {
    final response = await _dio.post(
      '/conversations/$conversationId/messages',
      data: {'body': body},
    );
    final data = (response.data as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
    return ChatMessage.fromJson(data);
  }

  Future<void> markRead(int conversationId) async {
    await _dio.post('/conversations/$conversationId/read');
  }
}
