import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../domain/entities/customer.dart';

enum AuthStatus { idle, loading, otpSent, authenticated, error }

enum OtpChannel { phone, email }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.idle,
    this.phone = '',
    this.email = '',
    this.otpChannel = OtpChannel.phone,
    this.errorMessage,
    this.session,
  });

  final AuthStatus status;
  final String phone;
  final String email;
  final OtpChannel otpChannel;
  final String? errorMessage;
  final AuthSession? session;

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    String? email,
    OtpChannel? otpChannel,
    String? errorMessage,
    AuthSession? session,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      otpChannel: otpChannel ?? this.otpChannel,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props =>
      [status, phone, email, otpChannel, errorMessage, session];
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void _markAuthed() => ref.read(sessionGateProvider).markAuthenticated();

  void setPhone(String phone) =>
      state = state.copyWith(phone: phone, clearError: true);

  void setEmail(String email) =>
      state = state.copyWith(email: email, clearError: true);

  Future<bool> sendOtp() async {
    if (state.phone.length != 10) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Enter a valid 10-digit number',
      );
      return false;
    }
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final result =
        await ref.read(authRepositoryProvider).sendOtp(phone: state.phone);
    return result.when(
      success: (_) {
        state = state.copyWith(
          status: AuthStatus.otpSent,
          otpChannel: OtpChannel.phone,
        );
        return true;
      },
      failure: (m) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: m);
        return false;
      },
    );
  }

  Future<bool> verifyOtp(String otp) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    if (state.otpChannel == OtpChannel.email) {
      final result = await ref.read(authRepositoryProvider).verifyEmailOtp(
            email: state.email,
            otp: otp,
          );
      return result.when(
        success: (s) {
          state = state.copyWith(status: AuthStatus.authenticated, session: s);
          _markAuthed();
          return true;
        },
        failure: (m) {
          state = state.copyWith(status: AuthStatus.error, errorMessage: m);
          return false;
        },
      );
    }

    final result = await ref.read(authRepositoryProvider).verifyOtp(
          phone: state.phone,
          otp: otp,
        );
    return result.when(
      success: (s) {
        state = state.copyWith(status: AuthStatus.authenticated, session: s);
        _markAuthed();
        return true;
      },
      failure: (m) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: m);
        return false;
      },
    );
  }

  Future<bool> loginWhatsApp() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final result = await ref.read(authRepositoryProvider).loginWithWhatsApp();
    return result.when(
      success: (s) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          session: s,
          phone: s.phone,
        );
        _markAuthed();
        return true;
      },
      failure: (m) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: m);
        return false;
      },
    );
  }

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      email: email,
      clearError: true,
    );
    final result = await ref.read(authRepositoryProvider).loginWithEmail(
          email: email,
          password: password,
        );
    return result.when(
      success: (s) {
        state = state.copyWith(status: AuthStatus.authenticated, session: s);
        _markAuthed();
        return true;
      },
      failure: (m) {
        if (m == 'EMAIL_NOT_VERIFIED') {
          state = state.copyWith(
            status: AuthStatus.otpSent,
            otpChannel: OtpChannel.email,
            email: email,
            clearError: true,
          );
          return false;
        }
        state = state.copyWith(status: AuthStatus.error, errorMessage: m);
        return false;
      },
    );
  }

  Future<bool> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      email: email,
      clearError: true,
    );
    final result = await ref.read(authRepositoryProvider).registerWithEmail(
          fullName: fullName,
          email: email,
          password: password,
        );
    return result.when(
      success: (_) {
        state = state.copyWith(
          status: AuthStatus.otpSent,
          otpChannel: OtpChannel.email,
          email: email,
        );
        return true;
      },
      failure: (m) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: m);
        return false;
      },
    );
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final idToken =
          await ref.read(googleAuthServiceProvider).signInForIdToken();
      if (idToken == null) {
        state = state.copyWith(status: AuthStatus.idle);
        return false;
      }
      final result = await ref
          .read(authRepositoryProvider)
          .loginWithGoogle(idToken: idToken);
      return result.when(
        success: (s) {
          state = state.copyWith(status: AuthStatus.authenticated, session: s);
          _markAuthed();
          return true;
        },
        failure: (m) {
          state = state.copyWith(status: AuthStatus.error, errorMessage: m);
          return false;
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('Bad state: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(googleAuthServiceProvider).signOut();
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
