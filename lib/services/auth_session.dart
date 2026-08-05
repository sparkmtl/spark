/// In-memory auth session for the current app run (JWT from login).
class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  String? _accessToken;

  String? get accessToken => _accessToken;

  bool get isAuthenticated =>
      _accessToken != null && _accessToken!.trim().isNotEmpty;

  void setSession({required String accessToken}) {
    _accessToken = accessToken.trim();
  }

  void clear() {
    _accessToken = null;
  }
}
