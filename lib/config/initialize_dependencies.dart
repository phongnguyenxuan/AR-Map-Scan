import 'package:flutter_application_ar/config/auth_interceptor.dart';
import 'package:flutter_application_ar/models/auth_model.dart';
import 'package:flutter_application_ar/network/api_source.dart';
import 'package:flutter_application_ar/services/local_service.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

final sl = GetIt.instance;

Future initializeDependencies() async {
  final baseUrl = 'https://api-dev.vietnamdieusu.vn';

  //region local IO
  final sharedPres = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPres);

  sl.registerLazySingleton<ApiSource>(() => ApiSource());
  sl.registerLazySingleton(() => LocalService());

  Dio dio = Dio(BaseOptions(baseUrl: baseUrl));

  Oauth2Manager<AuthModel> authManager = Oauth2Manager<AuthModel>(
    currentValue: sl.get<LocalService>().getAuth(),
    onSave: (auth) {
      if (auth != null) {
        sl.get<LocalService>().saveAuth(auth: auth);
      } else {
        sl.get<LocalService>().saveAuth(auth: null);
      }
    },
  );

  sl.registerLazySingleton<Oauth2Manager<AuthModel>>(() => authManager);

  dio.interceptors.add(
    Oauth2Interceptor(
      dio: dio,
      oauth2Dio: dio,
      pathRefreshToken: '/api/v1/auth/refresh-token',
      tokenProvider: authManager,
    ),
  );

  sl.registerLazySingleton<Dio>(() => dio);
}
