import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import 'platform_storage.dart';

class AuthStorage {
  final PlatformStorage _storage;

  AuthStorage(this._storage);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: 'access_token', value: accessToken),
      _storage.write(key: 'refresh_token', value: refreshToken),
    ]);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: 'user', value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: 'user');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<void> clear() async => _storage.deleteAll();
}

final authStorageProvider = Provider<AuthStorage>(
  (ref) => AuthStorage(ref.watch(storageProvider)),
);
