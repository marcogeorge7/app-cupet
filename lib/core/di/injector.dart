import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/auth_remote_data_source.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../messaging/fcm_service.dart';
import '../../features/chat/data/message_remote_data_source.dart';
import '../../features/discover/data/discover_remote_data_source.dart';
import '../../features/matches/data/match_remote_data_source.dart';
import '../../features/profile/data/pet_remote_data_source.dart';
import '../../features/profile/domain/pet_repository.dart';
import '../../features/reports/data/report_remote_data_source.dart';
import '../network/dio_client.dart';
import '../realtime/reverb_client.dart';
import '../storage/secure_token_storage.dart';

final getIt = GetIt.instance;

void configureInjector() {
  getIt.registerLazySingleton<SecureTokenStorage>(SecureTokenStorage.new);
  getIt.registerLazySingleton<Dio>(() => buildDioClient(getIt()));
  getIt.registerLazySingleton<ReverbClient>(
    () => ReverbClient(getIt(), getIt()),
  );

  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(getIt()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(remote: getIt(), storage: getIt()),
  );
  getIt.registerLazySingleton<FcmService>(() => FcmService(getIt()));

  getIt.registerLazySingleton<PetRemoteDataSource>(
    () => PetRemoteDataSource(getIt()),
  );
  getIt.registerLazySingleton<PetRepository>(() => PetRepository(getIt()));

  getIt.registerLazySingleton<DiscoverRemoteDataSource>(
    () => DiscoverRemoteDataSource(getIt()),
  );
  getIt.registerLazySingleton<MatchRemoteDataSource>(
    () => MatchRemoteDataSource(getIt()),
  );
  getIt.registerLazySingleton<MessageRemoteDataSource>(
    () => MessageRemoteDataSource(getIt()),
  );
  getIt.registerLazySingleton<ReportRemoteDataSource>(
    () => ReportRemoteDataSource(getIt()),
  );
}
