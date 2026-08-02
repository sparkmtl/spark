/// Tracks password-reset email after OTP is requested via the API.
class PasswordResetSession {
  PasswordResetSession._();
  static final PasswordResetSession instance = PasswordResetSession._();

  String? email;
  bool verified = false;

  bool get hasActiveRequest => email != null && email!.isNotEmpty;

  void start({required String email}) {
    this.email = email.trim();
    verified = false;
  }

  void markVerified() {
    verified = true;
  }

  void clear() {
    email = null;
    verified = false;
  }
}
