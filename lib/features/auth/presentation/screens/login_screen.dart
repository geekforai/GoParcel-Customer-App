import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/widgets/gp_brand_logo.dart';
import '../../../../core/widgets/gp_inputs.dart';
import '../../../../core/widgets/gp_outline_button.dart';
import '../../../../core/widgets/gp_primary_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _goAfterAuth() async {
    final locResult =
        await ref.read(customerRepositoryProvider).isLocationGranted();
    if (!mounted) return;
    locResult.when(
      success: (granted) {
        context.go(granted ? RoutePaths.home : RoutePaths.location);
      },
      failure: (_) => context.go(RoutePaths.location),
    );
  }

  Future<void> _sendOtp() async {
    ref.read(authProvider.notifier).setPhone(_phoneController.text.trim());
    final sent = await ref.read(authProvider.notifier).sendOtp();
    if (!sent || !mounted) return;
    // SMS not configured yet — auto-verify with fixed bypass OTP.
    final ok = await ref.read(authProvider.notifier).verifyOtp('1234');
    if (ok && mounted) await _goAfterAuth();
  }

  Future<void> _whatsAppLogin() async {
    final ok = await ref.read(authProvider.notifier).loginWhatsApp();
    if (ok && mounted) await _goAfterAuth();
  }

  Future<void> _googleLogin() async {
    final ok = await ref.read(authProvider.notifier).loginWithGoogle();
    if (ok && mounted) await _goAfterAuth();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              const GpBrandLogo(height: 28),
              const SizedBox(height: 36),
              Text(
                'Welcome to GoParcel',
                style: AppTypography.textTheme.displayMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your mobile number to continue.',
                style: AppTypography.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              GpPhoneField(
                controller: _phoneController,
                errorText: auth.status == AuthStatus.error
                    ? auth.errorMessage
                    : null,
                onChanged: (v) =>
                    ref.read(authProvider.notifier).setPhone(v.trim()),
              ),
              const SizedBox(height: 24),
              GpPrimaryButton(
                label: 'Continue',
                isLoading: isLoading,
                onPressed: _sendOtp,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: AppTypography.textTheme.labelMedium,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 28),
              GpOutlineButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                onPressed: isLoading ? null : _googleLogin,
              ),
              const SizedBox(height: 12),
              GpOutlineButton(
                label: 'Continue with Email',
                icon: Icons.mail_outline_rounded,
                onPressed: isLoading
                    ? null
                    : () => context.push(RoutePaths.emailLogin),
              ),
              const SizedBox(height: 12),
              GpOutlineButton(
                label: 'Continue with WhatsApp',
                icon: Icons.chat_rounded,
                borderColor: AppColors.whatsapp,
                foregroundColor: AppColors.whatsapp,
                onPressed: isLoading ? null : _whatsAppLogin,
              ),
              const SizedBox(height: 48),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: AppTypography.textTheme.bodySmall,
                    children: [
                      const TextSpan(text: 'By continuing, you agree to our '),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
