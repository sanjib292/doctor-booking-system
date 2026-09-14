import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/platform_storage.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://doctor-booking-system-production-2bf8.up.railway.app/api/v1',
);

class ApiClient {
  late final Dio dio;
  final PlatformStorage _storage;

  ApiClient(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(_storage, dio),
      _LogInterceptor(),
    ]);
  }
}

class _AuthInterceptor extends Interceptor {
  final PlatformStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken != null) {
          final response = await _dio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(headers: {'Authorization': null}),
          );

          final newAccessToken = response.data['data']['accessToken'];
          final newRefreshToken = response.data['data']['refreshToken'];

          await _storage.write(key: 'access_token', value: newAccessToken);
          await _storage.write(key: 'refresh_token', value: newRefreshToken);

          // Retry original request
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(opts);
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        await _storage.deleteAll();
        // Navigation to login handled by GoRouter redirect
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('→ ${options.method} ${options.uri}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('✗ ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
      return true;
    }());
    handler.next(err);
  }
}

// Providers
final storageProvider = Provider<PlatformStorage>(
  (_) => PlatformStorage(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(storageProvider)),
);

final dioProvider = Provider<Dio>(
  (ref) => ref.watch(apiClientProvider).dio,
);
