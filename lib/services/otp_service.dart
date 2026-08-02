import 'auth_api.dart';
import 'password_reset_session.dart';
import 'signup_session.dart';

/// Sends / verifies OTPs through spark-api (Mailtrap when configured).
class OtpService {
  OtpService({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  final AuthApi _authApi;

  /// Sends a signup OTP via Mailtrap.
  Future<void> sendSignupOtp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _authApi.sendSignupOtp(
      name: name,
      email: email,
      password: password,
    );
    SignupSession.instance.start(
      name: name,
      email: email,
      password: password,
    );
  }

  Future<void> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    await _authApi.verifyOtp(
      email: email,
      otp: otp,
      purpose: 'SIGNUP',
    );
    SignupSession.instance.verified = true;
  }

  Future<void> completeSignup({required String email}) async {
    await _authApi.completeRegister(email: email);
    SignupSession.instance.clear();
  }

  Future<void> resendSignupOtp() async {
    final session = SignupSession.instance;
    final name = session.name;
    final email = session.email;
    final password = session.password;
    if (name == null || email == null || password == null) {
      throw StateError('No active signup session to resend OTP.');
    }
    await sendSignupOtp(name: name, email: email, password: password);
  }

  Future<void> sendResetOtp(String email) async {
    await _authApi.forgotPassword(email: email);
    PasswordResetSession.instance.start(email: email);
  }

  Future<void> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    await _authApi.verifyOtp(
      email: email,
      otp: otp,
      purpose: 'PASSWORD_RESET',
    );
    PasswordResetSession.instance.markVerified();
  }

  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    await _authApi.resetPassword(email: email, password: password);
    PasswordResetSession.instance.clear();
  }
}
