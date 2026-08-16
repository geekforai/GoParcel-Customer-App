/// Shared Maps / Places config for Dart HTTP calls.
/// Override: --dart-define=GOOGLE_MAPS_API_KEY=...
abstract final class MapsConfig {
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyCxSIt4TLHmRfFgXNcR9cpqlfKRwe4k0oE',
  );
}
