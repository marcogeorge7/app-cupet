/// Maps an FCM `data` payload to an in-app route.
///
/// Pure and shared by every notification tap entry point (foreground local
/// notification, `onMessageOpenedApp`, and `getInitialMessage`). The backend
/// sends `{type: 'message', conversation_id, message_id}` or
/// `{type: 'match', match_id, conversation_id}` with string values.
String? routeForData(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'message':
      final id = data['conversation_id'];
      if (id == null || id.toString().isEmpty) return null;
      return '/chat/$id';
    case 'match':
      return '/matches';
    default:
      return null;
  }
}
