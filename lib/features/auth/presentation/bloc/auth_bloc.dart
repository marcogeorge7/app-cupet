import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/models/user.dart';
import '../../domain/auth_repository.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthOtpRequested extends AuthEvent {
  const AuthOtpRequested(this.phoneNumber);
  final String phoneNumber;
  @override
  List<Object?> get props => [phoneNumber];
}

class AuthOtpSubmitted extends AuthEvent {
  const AuthOtpSubmitted(this.smsCode);
  final String smsCode;
  @override
  List<Object?> get props => [smsCode];
}

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

/// The session was ended by the server, not the user: the Sanctum token was
/// revoked or the socket was kicked because this account signed in on another
/// device (one device per account). Unlike [AuthLoggedOut] this must NOT hit
/// the backend logout endpoint — the token is already invalid — and it lands
/// the user on /auth with an explanatory message.
class AuthSessionRevoked extends AuthEvent {
  const AuthSessionRevoked();
}

/// Permanently delete the current account (App Store Guideline 5.1.1(v)).
/// On success the user ends up unauthenticated; on failure we stay
/// authenticated and surface [AuthState.errorMessage].
class AuthAccountDeleted extends AuthEvent {
  const AuthAccountDeleted();
}

/// Abandon the in-progress OTP flow and go back to phone entry so the user
/// can send the code to a different number. No backend call: there is no
/// session yet, only a pending verification to discard.
class AuthOtpCancelled extends AuthEvent {
  const AuthOtpCancelled();
}

class AuthProfileUpdated extends AuthEvent {
  const AuthProfileUpdated({
    this.name,
    this.email,
    this.avatarUrl,
    this.clearEmail = false,
    this.clearAvatarUrl = false,
  });

  final String? name;
  final String? email;
  final String? avatarUrl;
  final bool clearEmail;
  final bool clearAvatarUrl;

  @override
  List<Object?> get props =>
      [name, email, avatarUrl, clearEmail, clearAvatarUrl];
}

class _AuthCodeSent extends AuthEvent {
  const _AuthCodeSent(this.pending);
  final PendingPhoneVerification pending;
  @override
  List<Object?> get props => [pending.verificationId];
}

class _AuthSucceeded extends AuthEvent {
  const _AuthSucceeded(this.user);
  final AppUser user;
  @override
  List<Object?> get props => [user];
}

class _AuthFailed extends AuthEvent {
  const _AuthFailed(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

enum AuthStatus {
  unknown,
  unauthenticated,
  sendingOtp,
  awaitingOtp,
  verifying,
  authenticated,
  error,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.phoneNumber,
    this.pending,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? phoneNumber;
  final PendingPhoneVerification? pending;
  final AppUser? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    PendingPhoneVerification? pending,
    AppUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pending: pending ?? this.pending,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, phoneNumber, pending?.verificationId, user, errorMessage];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthOtpRequested>(_onOtpRequested);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthLoggedOut>(_onLogout);
    on<AuthSessionRevoked>(_onSessionRevoked);
    on<AuthAccountDeleted>(_onAccountDeleted);
    on<AuthOtpCancelled>((event, emit) =>
        emit(const AuthState(status: AuthStatus.unauthenticated)));
    on<AuthProfileUpdated>(_onProfileUpdated);
    on<_AuthCodeSent>((event, emit) => emit(state.copyWith(
          status: AuthStatus.awaitingOtp,
          pending: event.pending,
          clearError: true,
        )));
    on<_AuthSucceeded>((event, emit) => emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: event.user,
          clearError: true,
        )));
    on<_AuthFailed>((event, emit) => emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: event.failure.message,
        )));
  }

  final AuthRepository _repository;

  Future<void> _onCheck(AuthCheckRequested event, Emitter<AuthState> emit) async {
    if (!await _repository.hasToken()) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }

    // We have a stored session. Validate it against the backend — but a stored
    // token must only be discarded when the server actually REJECTS it (a 401,
    // e.g. the account signed in on another device). A network error / timeout
    // / 5xx on a cold start must NOT throw the user out to the login screen, so
    // retry a few times and never clear the token on a non-401 failure. This is
    // what fixes "I log in, reopen the app, and it shows the login page again".
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final user = await _repository.loadCurrentUser();
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
        return;
      } on Failure catch (f) {
        if (f.statusCode == 401) {
          await _repository.clearLocalSession();
          emit(state.copyWith(status: AuthStatus.unauthenticated));
          return;
        }
        // Transient — wait briefly, then retry without touching the token.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    // Backend unreachable (offline / down) after retries. Keep the token so the
    // next launch signs straight back in; fall back to sign-in for now rather
    // than hanging on the splash screen.
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }

  Future<void> _onOtpRequested(
    AuthOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.sendingOtp,
      phoneNumber: event.phoneNumber,
      clearError: true,
    ));

    await _repository.sendOtp(
      phoneNumber: event.phoneNumber,
      onCodeSent: (pending) => add(_AuthCodeSent(pending)),
      onAutoSignIn: (cred) async {
        try {
          final user = await _repository.signInWithCredential(cred);
          add(_AuthSucceeded(user));
        } catch (e) {
          add(_AuthFailed(e is Failure ? e : Failure(e.toString())));
        }
      },
      onError: (failure) => add(_AuthFailed(failure)),
    );
  }

  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final pending = state.pending;
    if (pending == null) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: 'No pending verification.'));
      return;
    }

    emit(state.copyWith(status: AuthStatus.verifying, clearError: true));
    try {
      final user = await _repository.verifyOtpAndSignIn(
        pending: pending,
        smsCode: event.smsCode,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e is Failure ? e.message : e.toString(),
      ));
    }
  }

  Future<void> _onProfileUpdated(
    AuthProfileUpdated event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _repository.updateProfile(
        name: event.name,
        email: event.email,
        avatarUrl: event.avatarUrl,
        clearEmail: event.clearEmail,
        clearAvatarUrl: event.clearAvatarUrl,
      );
      // Stay authenticated; just swap the user payload.
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
      ));
    } catch (e) {
      // Stay authenticated; surface the message via state.errorMessage so the
      // edit page can show it without bouncing the user back to /auth.
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: e is Failure ? e.message : e.toString(),
      ));
    }
  }

  Future<void> _onAccountDeleted(
    AuthAccountDeleted event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.deleteAccount();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      // Deletion failed on the server — keep the user signed in and surface
      // the error rather than stranding them in a half-deleted state.
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: e is Failure ? e.message : e.toString(),
      ));
    }
  }

  Future<void> _onSessionRevoked(
    AuthSessionRevoked event,
    Emitter<AuthState> emit,
  ) async {
    // Idempotent: rapid duplicate signals (several 401s in flight, plus the
    // socket `session.revoked`) must not re-clear or thrash the router once
    // we're already signed out. `unknown` is the initial-check window — a
    // best-effort pre-login call (e.g. POST /devices at startup) 401ing there
    // must not tear down a session that's still resolving.
    if (state.status == AuthStatus.unauthenticated ||
        state.status == AuthStatus.unknown) {
      return;
    }
    try {
      await _repository.clearLocalSession();
    } catch (_) {
      // Local-only teardown; never strand the user on an authenticated screen.
    }
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage:
          'You were signed out because your account was used on another device.',
    ));
  }

  Future<void> _onLogout(AuthLoggedOut event, Emitter<AuthState> emit) async {
    try {
      await _repository.logout();
    } catch (_) {
      // Ignore: the repository already swallows backend/Firebase failures,
      // but guard here too so a stray throw can never strand the user on
      // an authenticated screen.
    }
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
