import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/widgets/gp_primary_button.dart';
import '../providers/auth_provider.dart';

class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _afterAuthSuccess() async {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final notifier = ref.read(authProvider.notifier);

    if (_isRegister) {
      final ok = await notifier.registerWithEmail(
        fullName: _nameController.text.trim(),
        email: email,
        password: password,
      );
      if (!mounted) return;
      if (ok) {
        context.push(RoutePaths.otp);
        return;
      }
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.otpSent) {
        context.push(RoutePaths.otp);
      }
      return;
    }

    final ok = await notifier.loginWithEmail(email: email, password: password);
    if (!mounted) return;
    if (ok) {
      await _afterAuthSuccess();
      return;
    }
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.otpSent) {
      context.push(RoutePaths.otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isRegister ? 'Create account' : 'Email login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  _isRegister ? 'Join GoParcel' : 'Welcome back',
                  style: AppTypography.textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegister
                      ? 'Create an account with email and password.'
                      : 'Sign in with your email and password.',
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (_isRegister) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      hintText: 'Amit Kumar',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofillHints: [
                    _isRegister
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: _isRegister ? 'Min 8 chars, Aa1' : 'Your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (value.length < 8) return 'Min 8 characters';
                    if (_isRegister) {
                      final ok = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$')
                          .hasMatch(value);
                      if (!ok) {
                        return 'Use upper, lower, and a number';
                      }
                    }
                    return null;
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
                const SizedBox(height: 28),
                GpPrimaryButton(
                  label: _isRegister ? 'Create account' : 'Login',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'Already have an account? Login'
                          : 'New here? Create account',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
