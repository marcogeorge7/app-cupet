import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final int conversationId;
  final int senderUserId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        conversationId: json['conversation_id'] as int,
        senderUserId: json['sender_user_id'] as int,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] != null
            ? DateTime.tryParse(json['read_at'] as String)
            : null,
      );

  @override
  List<Object?> get props =>
      [id, conversationId, senderUserId, body, createdAt, readAt];
}
