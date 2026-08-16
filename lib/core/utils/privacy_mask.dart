abstract final class PrivacyMask {
  static String name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Partner';
    final first = trimmed[0].toUpperCase();
    return '$first***';
  }

  static String phone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '******';
    return '******${digits.substring(digits.length - 4)}';
  }
}
