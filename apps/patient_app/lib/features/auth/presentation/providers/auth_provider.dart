import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  Future<Map<String, dynamic>> registerPatient({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? gender,
    int? age,
  }) async {
    final response = await _dio.post('/auth/patient/register', data: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
    });
    final data = response.data['data'] as Map<String, dynamic>;
    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await _storage.saveUser(data['user'] as Map<String, dynamic>);
    return data;
  }

  Future<Map<String, dynamic>> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post('/auth/patient/login', data: {
      'identifier': identifier,
      'password': password,
    });
    final data = response.data['data'] as Map<String, dynamic>;
    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await _storage.saveUser(data['user'] as Map<String, dynamic>);
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

  // Phase 2: Google Sign-In
  Future<void> googleSignIn() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) throw Exception('Google Sign-In cancelled');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('Failed to get Google ID token');

    final response = await _dio.post('/auth/patient/google', data: {
      'idToken': idToken,
    });

    final data = response.data['data'] as Map<String, dynamic>;
    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await _storage.saveUser(data['user'] as Map<String, dynamic>);
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
