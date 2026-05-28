/// Tracks which conversation (if any) the user is currently viewing so the
/// FCM foreground handler can suppress a redundant banner for the open chat.
class ActiveChatTracker {
  int? activeConversationId;

  void enter(int conversationId) {
    activeConversationId = conversationId;
  }

  void leave(int conversationId) {
    // Only clear if we're still the active chat — a fast chat→chat switch can
    // dispose the previous page after the new one already registered itself.
    if (activeConversationId == conversationId) {
      activeConversationId = null;
    }
  }
}
