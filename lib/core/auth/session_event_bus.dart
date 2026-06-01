import 'dart:async';

/// App-wide signal that the current session is no longer valid and the user
/// must be returned to sign-in.
///
/// Raised from two low-level sources that must stay decoupled from the
/// [AuthBloc]:
///   * the Dio 401 interceptor — the bearer was revoked server-side (a newer
///     login on another device wiped this device's Sanctum token);
///   * the socket-hub `session.revoked` event — this socket was kicked the
///     instant another device signed in (sub-second, before any REST 401).
///
/// One [AuthBloc] listener consumes this and dispatches `AuthSessionRevoked`.
class SessionEventBus {
  final StreamController<void> _forcedLogout =
      StreamController<void>.broadcast();

  /// Fires whenever the session is forcibly ended elsewhere. Multiple rapid
  /// signals are fine — the AuthBloc handler is idempotent.
  Stream<void> get onForcedLogout => _forcedLogout.stream;

  void notifyForcedLogout() {
    if (!_forcedLogout.isClosed) _forcedLogout.add(null);
  }

  Future<void> dispose() => _forcedLogout.close();
}
