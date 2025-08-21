import 'package:dio/dio.dart';
import 'package:flutter_application_ar/config/initialize_dependencies.dart';
import 'package:flutter_application_ar/models/ar_location_model.dart';
import 'package:flutter_application_ar/models/auth_model.dart';

class ApiSource {
  final Dio dio = sl.get();

  Future<AuthModel> login(String email, String password) async {
    try {
      final response = await dio.post(
        '/admin/login',
        data: {'email': email, 'password': password},
      );
      return AuthModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      print(e.response?.data);
      throw Exception(e);
    }
  }

  Future<ArData> getArLocation() async {
    try {
      final response = await dio.get(
        '/admin/ar-locations',
        queryParameters: {'page': 1, 'limit': 100},
      );
      return ArData.fromJson(response.data['data']);
    } on DioException catch (e) {
      print(e.response?.data);
      throw Exception(e);
    }
  }

  Future<List<ArLocationVideo>> getVideoByArLocationId(
    int culturalSiteId,
    int arLocationId,
  ) async {
    try {
      final response = await dio.get(
        '/cultural-sites/$culturalSiteId/$arLocationId/get-video',
      );
      return (response.data['data']['videos'] as List<dynamic>)
          .map((e) => ArLocationVideo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load video: $e');
    }
  }
}
