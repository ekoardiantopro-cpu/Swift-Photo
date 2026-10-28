import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class DriveSignInRequired implements Exception {
  const DriveSignInRequired();
  @override
  String toString() => 'Sesi Google berakhir. Hubungkan kembali akun Google.';
}

class GoogleDriveAuth {
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '907898476409-djkfubkn242lia4nddj94doh7n0qj2t4.apps.googleusercontent.com',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const scopes = ['https://www.googleapis.com/auth/drive.file'];
  static Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (Platform.isIOS && iosClientId.isEmpty) {
      throw StateError(
        'Login Google iOS belum dikonfigurasi. Client ID iOS diperlukan.',
      );
    }
    await GoogleSignIn.instance.initialize(
      serverClientId: webClientId,
      clientId: Platform.isIOS ? iosClientId : null,
    );
    // Native SDK also emits events for failed interactive sign-ins.
    GoogleSignIn.instance.authenticationEvents.listen(
      (_) {},
      onError: (Object _) {},
    );
  }

  Future<GoogleSignInAccount> connect() async {
    await initialize();
    final account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    await account.authorizationClient.authorizeScopes(scopes);
    return account;
  }

  /// Android AuthorizationClient uses the saved account, not the default one,
  /// and can refresh previously granted scopes without an attached Activity.
  Future<String> token(String accountId, String email) async {
    await initialize();
    if (Platform.isIOS) {
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (account?.id != accountId) throw const DriveSignInRequired();
    }
    final authorization = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: scopes,
              userId: accountId,
              email: email,
              promptIfUnauthorized: false,
            ),
          ),
        );
    if (authorization == null) throw const DriveSignInRequired();
    return authorization.accessToken;
  }

  Future<void> invalidate(String token) =>
      GoogleSignInPlatform.instance.clearAuthorizationToken(
        ClearAuthorizationTokenParams(accessToken: token),
      );

  Future<void> signOut() async {
    await initialize();
    await GoogleSignIn.instance.signOut();
  }
}
