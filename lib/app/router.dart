import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injector.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/otp_verify_page.dart';
import '../features/auth/presentation/pages/phone_input_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/chat/data/message_remote_data_source.dart';
import '../features/chat/presentation/bloc/chat_bloc.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/discover/data/discover_remote_data_source.dart';
import '../features/discover/presentation/bloc/discover_bloc.dart';
import '../features/discover/presentation/pages/discover_page.dart';
import '../features/matches/data/match_remote_data_source.dart';
import '../features/matches/presentation/bloc/matches_bloc.dart';
import '../features/matches/presentation/pages/matches_page.dart';
import '../features/profile/presentation/pages/new_pet_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import 'home_shell.dart';

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    refreshListenable: _AuthListenable(authBloc),
    initialLocation: '/splash',
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;
      final atAuth = loc == '/auth' || loc == '/auth/otp';
      final atSplash = loc == '/splash';

      if (status == AuthStatus.unknown) return atSplash ? null : '/splash';
      if (status == AuthStatus.unauthenticated) {
        if (atAuth) return null;
        return '/auth';
      }
      if (status == AuthStatus.awaitingOtp || status == AuthStatus.verifying) {
        return '/auth/otp';
      }
      if (status == AuthStatus.authenticated) {
        if (atAuth || atSplash) return '/discover';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/auth', builder: (_, __) => const PhoneInputPage()),
      GoRoute(path: '/auth/otp', builder: (_, __) => const OtpVerifyPage()),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/discover',
            builder: (_, __) => BlocProvider(
              create: (_) => DiscoverBloc(getIt<DiscoverRemoteDataSource>()),
              child: const DiscoverPage(),
            ),
          ),
          GoRoute(
            path: '/matches',
            builder: (_, __) => BlocProvider(
              create: (_) => MatchesBloc(getIt<MatchRemoteDataSource>()),
              child: const MatchesPage(),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/new-pet',
        builder: (_, __) => const NewPetPage(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          final title = state.uri.queryParameters['title'];
          return BlocProvider(
            create: (_) => ChatBloc(
              remote: getIt<MessageRemoteDataSource>(),
              reverb: getIt(),
            ),
            child: ChatPage(conversationId: id, title: title),
          );
        },
      ),
    ],
  );
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
