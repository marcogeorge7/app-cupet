import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injector.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/otp_verify_page.dart';
import '../features/auth/presentation/pages/phone_input_page.dart';
import '../features/auth/presentation/pages/registration_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/blocks/presentation/blocked_users_page.dart';
import '../features/chat/data/message_remote_data_source.dart';
import '../features/chat/presentation/bloc/chat_bloc.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/discover/data/discover_remote_data_source.dart';
import '../features/discover/presentation/bloc/discover_bloc.dart';
import '../features/discover/presentation/pages/discover_page.dart';
import '../features/matches/data/match_remote_data_source.dart';
import '../features/matches/presentation/bloc/matches_bloc.dart';
import '../features/matches/presentation/pages/matches_page.dart';
import '../features/profile/presentation/bloc/pet_bloc.dart';
import '../features/profile/presentation/pages/edit_profile_page.dart';
import '../features/profile/presentation/pages/new_pet_page.dart';
import '../features/profile/presentation/pages/pet_detail_page.dart';
import '../shared/models/pet.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import 'home_shell.dart';

/// Root navigator key — lets the [GoRouter] navigator be addressed from
/// outside the widget tree (e.g. FCM notification callbacks).
final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: _AuthListenable(authBloc),
    initialLocation: '/splash',
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;
      final atAuth = loc == '/auth' || loc == '/auth/otp';
      final atSplash = loc == '/splash';

      if (status == AuthStatus.unknown) return atSplash ? null : '/splash';
      if (status == AuthStatus.unauthenticated) {
        // Only phone entry is valid while unauthenticated. /auth/otp is also
        // under "auth" but must fall back here so "use a different number"
        // actually returns the user to phone entry instead of being pinned
        // to the OTP screen.
        return loc == '/auth' ? null : '/auth';
      }
      if (status == AuthStatus.awaitingOtp || status == AuthStatus.verifying) {
        return '/auth/otp';
      }
      if (status == AuthStatus.authenticated) {
        final atRegister = loc == '/register';
        if (_needsOnboarding(authBloc.state)) {
          // Block every authenticated route (deep links included) until
          // the mandatory name + first-pet onboarding is complete.
          return atRegister ? null : '/register';
        }
        if (atRegister || atAuth || atSplash) return '/discover';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/auth', builder: (_, _) => const PhoneInputPage()),
      GoRoute(path: '/auth/otp', builder: (_, _) => const OtpVerifyPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegistrationPage()),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/discover',
            builder: (_, _) => BlocProvider(
              create: (_) => DiscoverBloc(getIt<DiscoverRemoteDataSource>()),
              child: const DiscoverPage(),
            ),
          ),
          GoRoute(
            path: '/matches',
            builder: (_, _) => BlocProvider(
              create: (_) => MatchesBloc(getIt<MatchRemoteDataSource>()),
              child: const MatchesPage(),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/profile/new-pet',
        builder: (_, _) => const NewPetPage(),
      ),
      GoRoute(
        path: '/profile/blocked',
        builder: (_, _) => const BlockedUsersPage(),
      ),
      GoRoute(
        path: '/profile/pet/:id',
        redirect: (_, state) {
          final raw = state.pathParameters['id'];
          if (raw == null || int.tryParse(raw) == null) return '/profile';
          return null;
        },
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PetDetailPage(petId: id);
        },
      ),
      GoRoute(
        path: '/profile/pet/:id/edit',
        redirect: (_, state) {
          final raw = state.pathParameters['id'];
          if (raw == null || int.tryParse(raw) == null) return '/profile';
          return null;
        },
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          // Look up the pet from the app-level PetBloc; if it's gone (e.g. a
          // deep link refresh that beat the list load) bounce back to the
          // profile list rather than crashing.
          final pets = context.read<PetBloc>().state.pets;
          final pet = pets.where((p) => p.id == id).firstOrNull;
          if (pet == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/profile');
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return NewPetPage(initialPet: pet);
        },
      ),
      GoRoute(
        path: '/pet-profile',
        parentNavigatorKey: rootNavigatorKey,
        // Read-only profile of a discovered pet, passed in via `extra` so no
        // extra fetch is needed (the discover deck already carries the pet).
        builder: (context, state) {
          final pet = state.extra;
          if (pet is! Pet) {
            return const Scaffold(body: Center(child: Text('Pet not found.')));
          }
          return PetProfileView(pet: pet, owner: false);
        },
      ),
      GoRoute(
        path: '/chat/:id',
        redirect: (_, state) {
          final raw = state.pathParameters['id'];
          if (raw == null || int.tryParse(raw) == null) {
            return '/matches';
          }
          return null;
        },
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final title = state.uri.queryParameters['title'];
          // Optional — present when opened from the Matches list, absent for
          // FCM deep links. Drive the chat's Report/Block menu.
          final peerPetId =
              int.tryParse(state.uri.queryParameters['peerPetId'] ?? '');
          final peerUserId =
              int.tryParse(state.uri.queryParameters['peerUserId'] ?? '');
          final matchId =
              int.tryParse(state.uri.queryParameters['matchId'] ?? '');
          final myUserId = context.read<AuthBloc>().state.user?.id;
          return BlocProvider(
            create: (_) => ChatBloc(
              remote: getIt<MessageRemoteDataSource>(),
              socket: getIt(),
              myUserId: myUserId,
            ),
            child: ChatPage(
              conversationId: id,
              title: title,
              peerPetId: peerPetId,
              peerUserId: peerUserId,
              matchId: matchId,
            ),
          );
        },
      ),
    ],
  );
}

/// A user must finish registration (name + at least one pet) before they
/// can reach the app. Derived from server state (refreshed via /me on every
/// launch and after each onboarding step), so it resumes across cold starts.
bool _needsOnboarding(AuthState state) {
  final user = state.user;
  if (user == null) return false;
  return (user.name ?? '').trim().isEmpty || user.petsCount == 0;
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._bloc) {
    _sub = _bloc.stream.listen((_) => notifyListeners());
  }

  final AuthBloc _bloc;
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
