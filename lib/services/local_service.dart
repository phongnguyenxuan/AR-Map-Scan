import 'dart:convert';

import 'package:flutter_application_ar/config/initialize_dependencies.dart';
import 'package:flutter_application_ar/models/auth_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalService {
  final String keyAuth = 'key_auth';
  final String keySite = 'key_site';
  final String keyIsFirstTime = 'is_first_time';

  final _sharedPref = sl.get<SharedPreferences>();

  bool isAuthorized() {
    return _sharedPref.containsKey(keyAuth);
  }

  Future saveAuth({required AuthModel? auth}) async {
    if (auth != null) {
      await _sharedPref.setString(keyAuth, jsonEncode(auth.toJson()));
    } else {
      await _sharedPref.clear();
    }
  }

  AuthModel? getAuth() {
    if (_sharedPref.containsKey(keyAuth)) {
      final authData = jsonDecode(_sharedPref.getString(keyAuth) ?? '');
      return AuthModel.fromJson(authData);
    } else {
      return null;
    }
  }

  void saveSessionExpiryTime(DateTime expiryTime) {
    // Save expiry time as milliseconds since epoch
    _sharedPref.setInt(
      'session_expiry_time',
      expiryTime.millisecondsSinceEpoch,
    );
  }

  DateTime? getSessionExpiryTime() {
    final milliseconds = _sharedPref.getInt('session_expiry_time');
    if (milliseconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  Future saveSelectedLanguage(String languageCode) async {
    return _sharedPref.setString('language_code', languageCode);
  }

  String? getLanguageCode() {
    return _sharedPref.getString('language_code');
  }

  void saveAuthRoute(bool isAuthRoute) {
    _sharedPref.setBool('is_auth_route', isAuthRoute);
  }

  bool getAuthRoute() {
    return _sharedPref.getBool('is_auth_route') ?? false;
  }

  Future saveSelectedSite(int siteId) {
    return _sharedPref.setInt(keySite, siteId);
  }

  int? getSelectedSiteId() {
    return _sharedPref.getInt(keySite);
  }

  Future markFirstTimeDone() async {
    return _sharedPref.setBool(keyIsFirstTime, false);
  }

  Future<bool> isFirstTime() async {
    return _sharedPref.getBool(keyIsFirstTime) ?? true;
  }
}
