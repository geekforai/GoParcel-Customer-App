import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/api_constants.dart';

class GoogleAuthService {
  GoogleAuthService()
      : _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: ApiConstants.googleServerClientId.isEmpty
              ? null
              : ApiConstants.googleServerClientId,
        );

  final GoogleSignIn _googleSignIn;

  /// Returns Google ID token, or null if user cancelled.
  Future<String?> signInForIdToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google idToken missing. Pass --dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID>',
      );
    }
    return idToken;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
