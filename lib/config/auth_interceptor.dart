import 'dart:async';
import 'dart:developer' as developer;
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_ar/models/auth_model.dart';

class Oauth2Interceptor extends QueuedInterceptor {
  static const TAG = 'Oauth2Interceptor';

  Dio dio;
  Dio oauth2Dio;
  String pathRefreshToken;
  String keyRefreshToken = 'refreshToken';
  Oauth2Manager<AuthModel?> tokenProvider;

  Oauth2Interceptor({
    required this.dio,
    required this.oauth2Dio,
    required this.pathRefreshToken,
    required this.tokenProvider,
    this.keyRefreshToken = 'refreshToken',
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('onRequest: ${tokenProvider.currentValue?.accessToken}');
    options.headers.putIfAbsent(
      'Authorization',
      () => 'Bearer ${tokenProvider.currentValue?.accessToken}',
    );
    handler.next(options);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) async {
    log(
      'onError: ${error.response?.statusCode} -- ${tokenProvider.currentValue}',
    );
    if (error.response?.statusCode == 401 &&
        tokenProvider.currentValue != null) {
      developer.log('onError 401 [$error]', name: TAG);
      RequestOptions options = error.response!.requestOptions;
      if ('${tokenProvider.currentValue?.accessToken}' !=
          options.headers["Authorization"]) {
        options.headers["Authorization"] =
            'Bearer ${tokenProvider.currentValue?.accessToken}';
        dio
            .fetch(options)
            .then(
              (value) {
                handler.resolve(value);
              },
              onError: (error) {
                handler.reject(error);
              },
            );
        return;
      }
      oauth2Dio
          .post(
            pathRefreshToken,
            data: {keyRefreshToken: tokenProvider.currentValue?.accessToken},
          )
          .then(
            (value) {
              log(
                '"success Authorization: ${tokenProvider.currentValue?.accessToken}',
              );
              tokenProvider.add(AuthModel.fromJson(value.data));
              options.headers["Authorization"] =
                  'Bearer ${tokenProvider.currentValue?.accessToken}';
            },
            onError: (error) {
              log('error Authorization: $error');
              tokenProvider.add(null);
              handler.reject(error);
            },
          )
          .then((value) {
            dio
                .fetch(options)
                .then(
                  (value) {
                    log('success Authorization: $value');

                    handler.resolve(value);
                  },
                  onError: (error) {
                    log('error Authorization: $error');
                    tokenProvider.add(null);
                    handler.reject(error);
                  },
                );
          });
    } else {
      handler.next(error);
    }
  }
}

class Oauth2Manager<AuthModel> {
  static const TAG = 'Oauth2Manager';

  AuthModel? currentValue;

  late StreamController<AuthModel?> controller;

  ValueChanged<AuthModel?>? onSave;

  Oauth2Manager({this.currentValue, this.onSave}) {
    controller = StreamController.broadcast();
    controller.stream.listen((event) {
      currentValue = event;
    });
  }

  void add(AuthModel? event) {
    developer.log('add [event] : $event', name: TAG);
    currentValue = event;
    onSave!(event);
    controller.add(event);
  }

  void dispose() {
    controller.close();
  }
}
