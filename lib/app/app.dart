import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injector.dart';
import '../core/navigation/navigation_service.dart';
import '../core/realtime/realtime_user_service.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/profile/domain/pet_repository.dart';
import '../features/profile/presentation/bloc/pet_bloc.dart';
import 'router.dart';
import 'theme.dart';

class CupetApp extends StatefulWidget {
  const CupetApp({super.key});

  @override
  State<CupetApp> createState() => _CupetAppState();
}

class _CupetAppState extends State<CupetApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(getIt<AuthRepository>())
      ..add(const AuthCheckRequested());
    _router = buildRouter(_authBloc);
    // Let code outside the widget tree (FCM callbacks) navigate.
    getIt<NavigationService>().attach(_router);
  }

  @override
  void dispose() {
    getIt<RealtimeUserService>().stop();
    _router.dispose();
    _authBloc.close();
    super.dispose();
  }

  /// Mirrors the router's onboarding gate: a user without a name or any pet
  /// is still pinned to /register, so a deep link must not jump past it.
  bool _needsOnboarding(AuthState state) {
    final user = state.user;
    if (user == null) return false;
    return (user.name ?? '').trim().isEmpty || user.petsCount == 0;
  }

  void _onAuthChanged(BuildContext context, AuthState state) {
    final realtime = getIt<RealtimeUserService>();
    if (state.status == AuthStatus.authenticated && state.user != null) {
      // Idempotent — safe to call on every authenticated emission.
      realtime.start(state.user!.id);
      final nav = getIt<NavigationService>();
      final pending = nav.pendingDeepLink;
      if (pending != null && !_needsOnboarding(state)) {
        nav.pendingDeepLink = null;
        // Defer so the authenticated redirect to /discover settles first;
        // the deep link then sits on top of it (back returns to the app).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          nav.push(pending);
        });
      }
    } else if (state.status == AuthStatus.unauthenticated) {
      realtime.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => PetBloc(getIt<PetRepository>())),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (p, c) => p.status != c.status || p.user != c.user,
        listener: _onAuthChanged,
        child: MaterialApp.router(
          title: 'CuPet',
          debugShowCheckedModeBanner: false,
          theme: buildCupetTheme(),
          routerConfig: _router,
        ),
      ),
    );
  }
}
