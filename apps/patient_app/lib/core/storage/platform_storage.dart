import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Web-safe storage wrapper.
/// On web: uses Hive (IndexedDB) — avoids WebCrypto which breaks under --disable-web-security.
/// On native: uses FlutterSecureStorage (Keystore / Keychain).
class PlatformStorage {
  static const _boxName = 'auth';

  final FlutterSecureStorage? _secure;

  PlatformStorage()
      : _secure = kIsWeb
            ? null
            : const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
              );

  Box get _box => Hive.box(_boxName);

  Future<String?> read({required String key}) async {
    if (kIsWeb) return _box.get(key) as String?;
    return _secure!.read(key: key);
  }

  Future<void> write({required String key, required String? value}) async {
    if (kIsWeb) {
      if (value == null) {
        await _box.delete(key);
      } else {
        await _box.put(key, value);
      }
      return;
    }
    await _secure!.write(key: key, value: value);
  }

  Future<void> deleteAll() async {
    if (kIsWeb) {
      await _box.clear();
      return;
    }
    await _secure!.deleteAll();
  }
}
