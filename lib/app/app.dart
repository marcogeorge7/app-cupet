import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injector.dart';
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

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(getIt<AuthRepository>())
      ..add(const AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(_authBloc);
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => PetBloc(getIt<PetRepository>())),
      ],
      child: MaterialApp.router(
        title: 'CuPet',
        debugShowCheckedModeBanner: false,
        theme: buildCupetTheme(),
        routerConfig: router,
      ),
    );
  }
}
