import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sign in with Google',
      button: true,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Continue with Google', style: AppTextStyles.labelLarge),
                ],
              ),
      ),
    );
  }
}

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // OTP tab
  final _phoneController = TextEditingController();
  final _otpFormKey = GlobalKey<FormState>();
  bool _isOtpLoading = false;
  String? _otpError;

  // Password tab
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pwFormKey = GlobalKey<FormState>();
  bool _isPwLoading = false;
  bool _obscurePassword = true;
  String? _pwError;

  // Google
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authServiceProvider).googleSignIn();
      if (mounted) context.goNamed('home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('not configured')
                ? 'Google Sign-In requires a Google Client ID — see SETUP.md'
                : 'Google Sign-In failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    setState(() {
      _isOtpLoading = true;
      _otpError = null;
    });
    try {
      final phone = '+91${_phoneController.text.trim()}';
      await ref.read(authServiceProvider).sendOtp(phone);
      if (mounted) context.pushNamed('otpVerification', extra: phone);
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final msg = (data is Map ? data['message'] as String? : null) ??
            'Something went wrong. Please try again.';
        setState(() => _otpError = msg);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _otpError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isOtpLoading = false);
    }
  }

  Future<void> _loginWithPassword() async {
    if (!_pwFormKey.currentState!.validate()) return;
    setState(() {
      _isPwLoading = true;
      _pwError = null;
    });
    try {
      await ref.read(authServiceProvider).loginWithPassword(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.goNamed('home');
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final msg = (data is Map ? data['message'] as String? : null) ??
            'Invalid credentials. Please try again.';
        setState(() => _pwError = msg);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pwError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isPwLoading = false);
    }
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpTab() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your mobile number',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: '9876543210',
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+91',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Phone number required';
              if (v.length != 10) return 'Enter a valid 10-digit number';
              return null;
            },
            onFieldSubmitted: (_) => _sendOtp(),
          ),
          if (_otpError != null) ...[
            const SizedBox(height: 10),
            _buildErrorBanner(_otpError!),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Send OTP',
            onPressed: _sendOtp,
            isLoading: _isOtpLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTab() {
    final theme = Theme.of(context);
    return Form(
      key: _pwFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in with phone or email',
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Phone number or email',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone or email required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password required';
              return null;
            },
            onFieldSubmitted: (_) => _loginWithPassword(),
          ),
          if (_pwError != null) ...[
            const SizedBox(height: 10),
            _buildErrorBanner(_pwError!),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Sign In',
            onPressed: _loginWithPassword,
            isLoading: _isPwLoading,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  size.height - MediaQuery.of(context).padding.vertical - 48,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // Illustration
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(80),
                      ),
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Text(
                    'Welcome to\nDoctorBook',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      labelStyle: AppTextStyles.labelLarge,
                      unselectedLabelStyle: AppTextStyles.labelMedium,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'OTP Login'),
                        Tab(text: 'Password'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Tab content (no TabBarView to avoid nesting scroll issues)
                  if (_tabController.index == 0) _buildOtpTab() else _buildPasswordTab(),

                  const SizedBox(height: 16),

                  Center(
                    child: GestureDetector(
                      onTap: () => context.pushNamed('registration'),
                      child: RichText(
                        text: TextSpan(
                          text: 'New here? ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: 'Create an account',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: AppTextStyles.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GoogleSignInButton(
                      isLoading: _isGoogleLoading, onTap: _signInWithGoogle),

                  const Spacer(),

                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
