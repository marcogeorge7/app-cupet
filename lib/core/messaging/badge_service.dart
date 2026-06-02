import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// Mirrors the unread-message total onto the OS app-icon badge.
///
/// While the app is backgrounded the OS sets the badge from a push's
/// `aps.badge`; this service keeps it correct while the app is open — set from
/// the live Matches unread total, and cleared when the user returns to the app
/// (the in-app UI already shows per-thread unread, and relying on the iOS
/// silent "clear" push is unreliable).
class BadgeService {
  /// Set the badge to [count] (clamped at 0). 0 clears it. Always applied: the
  /// OS may have set the badge from a push without our knowledge, so we can't
  /// short-circuit on a cached value.
  Future<void> setCount(int count) async {
    final next = count < 0 ? 0 : count;
    try {
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(next);
      }
    } catch (e) {
      debugPrint('BadgeService update failed: $e');
    }
  }

  /// Clear the badge — call when the user returns to / signs out of the app.
  Future<void> clear() => setCount(0);
}
