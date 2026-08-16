import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.token,
    required this.phone,
    required this.isAuthenticated,
    this.refreshToken = '',
    this.userId = '',
    this.fullName = '',
  });

  final String token;
  final String refreshToken;
  final String phone;
  final String userId;
  final String fullName;
  final bool isAuthenticated;

  static const empty = AuthSession(
    token: '',
    phone: '',
    isAuthenticated: false,
  );

  AuthSession copyWith({
    String? token,
    String? refreshToken,
    String? phone,
    String? userId,
    String? fullName,
    bool? isAuthenticated,
  }) {
    return AuthSession(
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  List<Object?> get props =>
      [token, refreshToken, phone, userId, fullName, isAuthenticated];
}

class CustomerProfile extends Equatable {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.walletBalance = 0,
  });

  final String id;
  final String name;
  final String phone;
  final double walletBalance;

  @override
  List<Object?> get props => [id, name, phone, walletBalance];
}

class SavedAddress extends Equatable {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String address;
  final bool isDefault;

  @override
  List<Object?> get props => [id, label, address, isDefault];
}
