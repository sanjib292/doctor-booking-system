import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/auth_storage.dart';

class AuthService {
  final Dio _dio;
  final AuthStorage _storage;

  AuthService(this._dio, this._storage);

  Future<void> sendOtp(String phone) async {
    await _dio.post('/auth/patient/send-otp', data: {'phone': phone});
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final response = await _dio.post('/auth/patient/verify-otp', data: {
      'phone': phone,
      'code': code,
    });

    final data = response.data['data'] as Map<String, dynamic>;

    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    if (data['isNewUser'] == false) {
      await _storage.saveUser(data['user'] as Map<String, dynamic>);
    }

    return data;
  }

  Future<void> completeRegistration({
    required String name,
    String? gender,
    int? age,
  }) async {
    // The user is already created via verifyOtp; update profile
    await _dio.patch('/users/me', data: {
      'name': name,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
    });
  }

  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      } catch (_) {}
    }
    await _storage.clear();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(dioProvider), ref.watch(authStorageProvider));
});
