import 'package:intl/intl.dart';

abstract final class Formatters {
  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String currency(num amount) => _inr.format(amount);

  static String currencyDecimal(num amount) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 2,
      ).format(amount);

  static String rating(double v) => v.toStringAsFixed(1);

  static String timeOfDay(DateTime dt) => DateFormat('h:mm a').format(dt);

  static String dateTime(DateTime dt) =>
      DateFormat('h:mm a, d MMM yyyy').format(dt);

  static String shortDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
