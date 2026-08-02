import 'package:flutter/foundation.dart';

import '../models/new_password_model.dart';
import '../services/auth_api.dart';
import '../services/otp_service.dart';
import '../services/password_reset_session.dart';

class NewPasswordController extends ChangeNotifier {
  NewPasswordController({
    required this._email,
    OtpService? otpService,
  }) : _otpService = otpService ?? OtpService();

  final String _email;
  final OtpService _otpService;

  NewPasswordModel _model = const NewPasswordModel();
  Map<String, String> _errors = {};
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;
  bool _isSubmitting = false;

  NewPasswordModel get model => _model;
  Map<String, String> get errors => _errors;
  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword => _obscureConfirmPassword;
  bool get isSubmitting => _isSubmitting;

  void updatePassword(String value) {
    _model = _model.copyWith(password: value);
    _revalidateIfNeeded();
  }

  void updateConfirmPassword(String value) {
    _model = _model.copyWith(confirmPassword: value);
    _revalidateIfNeeded();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleObscureConfirmPassword() {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    notifyListeners();
  }

  Future<bool> submit() async {
    _submitted = true;
    _errors = _model.validate();
    if (_errors.isNotEmpty) {
      notifyListeners();
      return false;
    }

    if (!PasswordResetSession.instance.verified) {
      _errors = {'password': 'Verify your OTP before setting a new password.'};
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      await _otpService.resetPassword(
        email: _email,
        password: _model.password,
      );
      return true;
    } on ApiException catch (e) {
      _errors = {'password': e.message};
      return false;
    } catch (_) {
      _errors = {'password': 'Could not update password. Please try again.'};
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _revalidateIfNeeded() {
    if (!_submitted) {
      notifyListeners();
      return;
    }
    _errors = _model.validate();
    notifyListeners();
  }
}
