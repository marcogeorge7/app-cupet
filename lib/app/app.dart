import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_event_bus.dart';
import '../core/di/injector.dart';
import '../core/messaging/active_chat_tracker.dart';
import '../core/messaging/badge_service.dart';
import '../core/messaging/fcm_service.dart';
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

class _CupetAppState extends State<CupetApp> with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  late final StreamSubscription<void> _forcedLogoutSub;
  late final StreamSubscription<RealtimeUserEvent> _realtimeSub;

  // Drives in-app banners (e.g. "You matched with Bella!") above every route.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authBloc = AuthBloc(getIt<AuthRepository>())
      ..add(const AuthCheckRequested());
    _router = buildRouter(_authBloc);
    // Let code outside the widget tree (FCM callbacks) navigate.
    final nav = getIt<NavigationService>();
    nav.attach(_router);
    // Replay a notification deep link the moment it's stashed, so a tap that
    // resolves after auth is already settled isn't missed (the auth-change
    // listener below covers the opposite order).
    nav.onPendingDeepLink = _replayDeepLink;
    // A revoked bearer (Dio 401) or a kicked socket (`session.revoked`) both
    // funnel through SessionEventBus; turn either into a forced sign-out.
    _forcedLogoutSub = getIt<SessionEventBus>().onForcedLogout.listen((_) {
      _authBloc.add(const AuthSessionRevoked());
    });
    // App-wide realtime events: surface a match that arrives while the user is
    // on another screen as an in-app banner.
    _realtimeSub = getIt<RealtimeUserService>().events.listen(_onRealtimeEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _forcedLogoutSub.cancel();
    _realtimeSub.cancel();
    getIt<RealtimeUserService>().stop();
    getIt<NavigationService>().onPendingDeepLink = null;
    _router.dispose();
    _authBloc.close();
    super.dispose();
  }

  void _onRealtimeEvent(RealtimeUserEvent event) {
    if (event is MatchCreatedEvent) {
      _showMatchBanner(event);
    } else if (event is MessageReceivedEvent) {
      _showMessageBanner(event);
    }
  }

  void _showMatchBanner(MatchCreatedEvent event) {
    // A match you make by swiping already shows the Discover "It's a match!"
    // dialog, so don't double-notify while that page is the active route.
    if (_router.routerDelegate.currentConfiguration.uri.path == '/discover') {
      return;
    }
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    final name = event.otherPetName;
    final text = (name != null && name.isNotEmpty)
        ? '🎉 You matched with $name!'
        : "🎉 It's a match!";
    final conversationId = event.conversationId;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => getIt<NavigationService>().deepLink(
            conversationId != null ? '/chat/$conversationId' : '/matches',
          ),
        ),
      ));
  }

  void _showMessageBanner(MessageReceivedEvent event) {
    // Only the realtime socket path carries a sender name; the FCM-backup nudge
    // (notifyMessageReceived) leaves it null and is covered by the OS/local
    // notification, so don't banner it here. Skip our own echo, and skip when
    // we're already viewing that conversation (ChatBloc renders it inline).
    if (event.fromSelf || event.senderName == null) return;
    if (getIt<ActiveChatTracker>().activeConversationId ==
        event.conversationId) {
      return;
    }
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    final sender = event.senderName!;
    final body = event.body ?? '';
    final text = body.isNotEmpty ? '$sender: $body' : sender;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => getIt<NavigationService>()
              .deepLink('/chat/${event.conversationId}'),
        ),
      ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authBloc.state.status != AuthStatus.authenticated) return;
    final realtime = getIt<RealtimeUserService>();
    switch (state) {
      case AppLifecycleState.resumed:
        // The socket-hub connection is dropped while backgrounded (we close it
        // below; the OS would anyway, and the short-lived JWT expires). Reopen
        // it on resume — ChatBloc then resyncs missed messages via REST cursor.
        realtime.onAppResumed();
        // The user is back in the app, so drop the OS app-icon badge the push
        // set while away. The Matches list re-asserts the live unread total when
        // it (re)loads.
        getIt<BadgeService>().clear();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Don't hold a socket open behind a hidden screen: the OS will suspend
        // it within seconds, and background delivery is push (FCM), not socket.
        realtime.onAppPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Mirrors the router's onboarding gate: a user without a name or any pet
  /// is still pinned to /register, so a deep link must not jump past it.
  bool _needsOnboarding(AuthState state) {
    final user = state.user;
    if (user == null) return false;
    return (user.name ?? '').trim().isEmpty || user.petsCount == 0;
  }

  /// Replay a stashed notification deep link once the user is authenticated and
  /// past onboarding. No-op when nothing is pending or we're not ready yet.
  /// Driven by BOTH the auth-change listener and NavigationService's
  /// onPendingDeepLink, so it fires regardless of which happens last.
  void _replayDeepLink() {
    final state = _authBloc.state;
    if (state.status != AuthStatus.authenticated || _needsOnboarding(state)) {
      return;
    }
    final nav = getIt<NavigationService>();
    final pending = nav.pendingDeepLink;
    if (pending == null) return;
    nav.pendingDeepLink = null;
    // Defer so the authenticated redirect to /discover settles first; the deep
    // link then lands on top of it (Back returns to the app).
    WidgetsBinding.instance.addPostFrameCallback((_) => nav.deepLink(pending));
  }

  void _onAuthChanged(BuildContext context, AuthState state) {
    final realtime = getIt<RealtimeUserService>();
    if (state.status == AuthStatus.authenticated && state.user != null) {
      // Idempotent — safe to call on every authenticated emission.
      realtime.start(state.user!.id);
      // Register this device's FCM token now that we're authenticated. The
      // startup FcmService.init() call races ahead of OTP login and 401s on a
      // fresh install, so without this a newly-signed-in device gets no push
      // until the next app restart.
      getIt<FcmService>().syncToken();
      // Foregrounded + signed in → clear any stale push badge; the Matches list
      // re-asserts the live unread total on load.
      getIt<BadgeService>().clear();
      _replayDeepLink();
    } else if (state.status == AuthStatus.unauthenticated) {
      realtime.stop();
      getIt<BadgeService>().clear();
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
          scaffoldMessengerKey: _messengerKey,
          theme: buildCupetTheme(),
          routerConfig: _router,
        ),
      ),
    );
  }
}
