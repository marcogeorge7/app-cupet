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
    if (await _repository.hasToken()) {
      try {
        final user = await _repository.loadCurrentUser();
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } catch (e) {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
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

  Future<void> _onLogout(AuthLoggedOut event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
