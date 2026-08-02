import 'package:flutter/foundation.dart';

import '../models/forgot_password_model.dart';
import '../services/auth_api.dart';
import '../services/otp_service.dart';

class ForgotPasswordController extends ChangeNotifier {
  ForgotPasswordController({OtpService? otpService})
      : _otpService = otpService ?? OtpService();

  final OtpService _otpService;

  ForgotPasswordModel _model = const ForgotPasswordModel();
  Map<String, String> _errors = {};
  bool _submitted = false;
  bool _isSubmitting = false;

  ForgotPasswordModel get model => _model;
  Map<String, String> get errors => _errors;
  bool get isSubmitting => _isSubmitting;

  void updateEmail(String value) {
    _model = _model.copyWith(email: value);
    _revalidateIfNeeded();
  }

  Future<bool> submit() async {
    _submitted = true;
    _errors = _model.validate();
    if (_errors.isNotEmpty) {
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      await _otpService.sendResetOtp(_model.email.trim());
      return true;
    } on ApiException catch (e) {
      _errors = {'email': e.message};
      return false;
    } catch (_) {
      _errors = {'email': 'Could not send OTP. Please try again.'};
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
