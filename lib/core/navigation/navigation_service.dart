import 'package:go_router/go_router.dart';

/// Holds the live [GoRouter] so code that runs outside the widget tree
/// (e.g. FCM notification callbacks) can navigate.
///
/// A deep link that arrives before auth has resolved (e.g. a terminated-app
/// notification tap) is stashed in [pendingDeepLink] and replayed once the
/// user is authenticated, so the GoRouter auth `redirect` doesn't swallow it.
class NavigationService {
  GoRouter? _router;
  String? pendingDeepLink;

  void attach(GoRouter router) {
    _router = router;
  }

  void go(String location) {
    _router?.go(location);
  }

  void push(String location) {
    _router?.push(location);
  }
}
