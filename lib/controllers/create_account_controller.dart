import 'package:flutter/foundation.dart';

import '../models/create_account_model.dart';
import '../services/auth_api.dart';
import '../services/otp_service.dart';

class CreateAccountController extends ChangeNotifier {
  CreateAccountController({OtpService? otpService})
      : _otpService = otpService ?? OtpService();

  final OtpService _otpService;

  CreateAccountModel _model = const CreateAccountModel();
  Map<String, String> _errors = {};
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;
  bool _isSubmitting = false;

  CreateAccountModel get model => _model;
  Map<String, String> get errors => _errors;
  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword => _obscureConfirmPassword;
  bool get isValid => _errors.isEmpty && _submitted;
  bool get isSubmitting => _isSubmitting;

  void updateName(String value) {
    _model = _model.copyWith(name: value);
    _revalidateIfNeeded();
  }

  void updateEmail(String value) {
    _model = _model.copyWith(email: value);
    _revalidateIfNeeded();
  }

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

    _isSubmitting = true;
    notifyListeners();

    try {
      await _otpService.sendSignupOtp(
        name: _model.name.trim(),
        email: _model.email.trim(),
        password: _model.password,
      );
      return true;
    } on ApiException catch (e) {
      if (e.fieldErrors != null && e.fieldErrors!.isNotEmpty) {
        _errors = Map<String, String>.from(e.fieldErrors!);
      } else if (e.message.toLowerCase().contains('username')) {
        _errors = {'name': e.message};
      } else {
        _errors = {'email': e.message};
      }
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
