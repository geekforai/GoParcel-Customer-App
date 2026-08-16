import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/locale/app_locale.dart';
import '../../../../core/widgets/gp_inputs.dart';
import '../../../../core/widgets/gp_primary_button.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _otp = '';

  Future<void> _verify() async {
    final ok = await ref.read(authProvider.notifier).verifyOtp(_otp);
    if (!ok || !mounted) return;

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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final isEmail = auth.otpChannel == OtpChannel.email;
    final otpLength = isEmail ? 6 : 4;
    final target = isEmail
        ? (auth.email.isEmpty ? 'your email' : auth.email)
        : (auth.phone.isEmpty ? 'your number' : '+91 ${auth.phone}');
    final s = ref.watch(l10nProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(s.verifyOtp),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.enterOtp, style: AppTypography.textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      isEmail
                          ? 'We sent a $otpLength-digit code to $target'
                          : '${s.otpHint} ($target)',
                      style: AppTypography.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    GpOtpInput(
                      key: ValueKey('otp-$otpLength-${auth.otpChannel}'),
                      length: otpLength,
                      onChanged: (v) => setState(() => _otp = v),
                      onCompleted: (v) {
                        setState(() => _otp = v);
                        _verify();
                      },
                    ),
                    if (auth.status == AuthStatus.error &&
                        auth.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.errorMessage!,
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: GpPrimaryButton(
                label: s.verifyContinue,
                isLoading: isLoading,
                isEnabled: _otp.length == otpLength,
                onPressed: _verify,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
