import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://doctor-booking-system-production-2bf8.up.railway.app/api/v1');

final _dioProvider = Provider<Dio>((_) => Dio(BaseOptions(baseUrl: _baseUrl)));
final _storageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)),
);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await ref.read(_dioProvider).post('/auth/doctor/login', data: {
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      });

      final data = response.data['data'] as Map<String, dynamic>;
      final storage = ref.read(_storageProvider);
      await storage.write(key: 'access_token', value: data['accessToken'] as String);
      await storage.write(key: 'refresh_token', value: data['refreshToken'] as String);

      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      setState(() => _error = (e.response?.data?['error']?['message'] as String?) ?? 'Login failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.local_hospital_rounded, size: 48, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 32),
              Text('Doctor Login', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Sign in to manage your appointments', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 40),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
