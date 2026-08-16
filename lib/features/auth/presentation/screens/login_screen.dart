import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/widgets/gp_brand_logo.dart';
import '../../../../core/widgets/gp_inputs.dart';
import '../../../../core/widgets/gp_primary_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    ref.read(authProvider.notifier).setPhone(_phoneController.text.trim());
    final sent = await ref.read(authProvider.notifier).sendOtp();
    if (!sent || !mounted) return;
    context.push(RoutePaths.otp);
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
                'Jaipur deliveries — login with your mobile number.',
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
              const SizedBox(height: 14),
              TextField(
                controller: _referralController,
                decoration: const InputDecoration(
                  labelText: 'Referral code (optional)',
                  hintText: 'Enter referral code',
                ),
              ),
              const SizedBox(height: 24),
              GpPrimaryButton(
                label: 'Continue',
                isLoading: isLoading,
                onPressed: _sendOtp,
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
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              context.push(RoutePaths.settings),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              context.push(RoutePaths.settings),
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
