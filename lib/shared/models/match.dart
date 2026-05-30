import 'package:equatable/equatable.dart';

import 'pet.dart';

/// Lightweight preview of a conversation's newest message, shown in the
/// Matches/inbox list. Full message bodies are loaded by the chat screen.
class LastMessagePreview extends Equatable {
  const LastMessagePreview({
    required this.id,
    required this.body,
    required this.senderUserId,
    required this.createdAt,
  });

  final int id;
  final String body;
  final int senderUserId;
  final DateTime createdAt;

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) =>
      LastMessagePreview(
        id: json['id'] as int,
        body: json['body'] as String? ?? '',
        senderUserId: json['sender_user_id'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, body, senderUserId, createdAt];
}

class PetMatch extends Equatable {
  const PetMatch({
    required this.id,
    required this.petA,
    required this.petB,
    required this.conversationId,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final int id;
  final Pet petA;
  final Pet petB;
  final int? conversationId;
  final DateTime createdAt;
  final LastMessagePreview? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory PetMatch.fromJson(Map<String, dynamic> json) => PetMatch(
        id: json['id'] as int,
        petA: Pet.fromJson(json['pet_a'] as Map<String, dynamic>),
        petB: Pet.fromJson(json['pet_b'] as Map<String, dynamic>),
        conversationId: json['conversation_id'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastMessage: json['last_message'] != null
            ? LastMessagePreview.fromJson(
                json['last_message'] as Map<String, dynamic>)
            : null,
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'] as String)
            : null,
        unreadCount: (json['unread_count'] as int?) ?? 0,
      );

  Pet otherPetFor(int userId) =>
      petA.userId == userId ? petB : petA;

  @override
  List<Object?> get props => [
        id,
        petA,
        petB,
        conversationId,
        createdAt,
        lastMessage,
        lastMessageAt,
        unreadCount,
      ];
}
