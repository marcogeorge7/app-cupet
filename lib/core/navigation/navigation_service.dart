import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Holds the live [GoRouter] so code that runs outside the widget tree
/// (e.g. FCM notification callbacks) can navigate.
///
/// A deep link that arrives before auth has resolved (e.g. a terminated-app
/// notification tap) is stashed in [pendingDeepLink] and replayed once the
/// user is authenticated, so the GoRouter auth `redirect` doesn't swallow it.
class NavigationService {
  GoRouter? _router;
  String? _pendingDeepLink;

  /// Fires whenever a [pendingDeepLink] is stored, so the app can replay it
  /// immediately when the user is already authenticated — covering the case
  /// where the deep link is stashed AFTER auth resolved, not only before.
  VoidCallback? onPendingDeepLink;

  String? get pendingDeepLink => _pendingDeepLink;
  set pendingDeepLink(String? value) {
    _pendingDeepLink = value;
    if (value != null) onPendingDeepLink?.call();
  }

  void attach(GoRouter router) {
    _router = router;
  }

  void go(String location) {
    _router?.go(location);
  }

  void push(String location) {
    _router?.push(location);
  }

  /// Navigate to a notification deep link. A chat is a detail screen pushed on
  /// top (so Back returns where the user was); the bottom-nav destinations
  /// (`/matches`, `/discover`, `/profile`) live in a ShellRoute and must be
  /// switched with `go()` — `push()` doesn't reliably reach a shell tab.
  void deepLink(String location) {
    final router = _router;
    if (router == null) return;
    if (location.startsWith('/chat/')) {
      router.push(location);
    } else {
      router.go(location);
    }
  }
}
