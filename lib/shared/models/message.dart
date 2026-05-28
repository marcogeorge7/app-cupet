import 'package:equatable/equatable.dart';

/// Delivery state of a message in the chat timeline.
///
/// Server-loaded history is always [sent] (or implicitly read via [readAt]).
/// [sending]/[failed] only ever apply to optimistic, locally-created bubbles
/// that haven't been acknowledged by the API yet.
enum MessageStatus { sending, sent, failed }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.status = MessageStatus.sent,
    this.localId,
  });

  final int id;
  final int conversationId;
  final int senderUserId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// [sending]/[failed] for optimistic bubbles, [sent] for anything the
  /// server has confirmed.
  final MessageStatus status;

  /// Client-generated correlation id for optimistic sends. Lets us swap the
  /// placeholder bubble for the server's copy once [send] returns, instead
  /// of leaving a duplicate. Null for server-sourced messages.
  final String? localId;

  bool get isPending => status != MessageStatus.sent;
  bool get isRead => readAt != null;

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

  /// An unsent placeholder shown the instant the user taps send.
  factory ChatMessage.optimistic({
    required String localId,
    required int conversationId,
    required int senderUserId,
    required String body,
  }) =>
      ChatMessage(
        // Temporary, monotonically-decreasing id keeps it sorted last and
        // never collides with real (positive) server ids.
        id: -DateTime.now().microsecondsSinceEpoch,
        conversationId: conversationId,
        senderUserId: senderUserId,
        body: body,
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
        localId: localId,
      );

  ChatMessage copyWith({
    int? id,
    DateTime? readAt,
    MessageStatus? status,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        conversationId: conversationId,
        senderUserId: senderUserId,
        body: body,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        status: status ?? this.status,
        localId: localId,
      );

  @override
  List<Object?> get props =>
      [id, conversationId, senderUserId, body, createdAt, readAt, status,
        localId];
}
