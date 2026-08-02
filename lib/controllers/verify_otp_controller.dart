import 'package:flutter/foundation.dart';

import '../models/otp_flow.dart';
import '../models/verify_otp_model.dart';
import '../services/auth_api.dart';
import '../services/otp_service.dart';
import '../services/password_reset_session.dart';
import '../services/signup_session.dart';

class VerifyOtpController extends ChangeNotifier {
  VerifyOtpController({
    required String email,
    required this._flow,
    OtpService? otpService,
  })  : _otpService = otpService ?? OtpService(),
        _model = VerifyOtpModel(email: email);

  final OtpService _otpService;
  final OtpFlow _flow;

  VerifyOtpModel _model;
  Map<String, String> _errors = {};
  bool _submitted = false;
  bool _isSubmitting = false;
  bool _isResending = false;

  OtpFlow get flow => _flow;
  VerifyOtpModel get model => _model;
  Map<String, String> get errors => _errors;
  bool get isSubmitting => _isSubmitting;
  bool get isResending => _isResending;

  void updateOtp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    _model = _model.copyWith(otp: digits.length > 6 ? digits.substring(0, 6) : digits);
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
      if (_flow == OtpFlow.signUp) {
        await _otpService.verifySignupOtp(
          email: _model.email,
          otp: _model.otp,
        );
        await _otpService.completeSignup(email: _model.email);
      } else {
        await _otpService.verifyResetOtp(
          email: _model.email,
          otp: _model.otp,
        );
      }
      _isSubmitting = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errors = {'otp': e.message};
      _isSubmitting = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errors = {'otp': 'Could not verify OTP. Please try again.'};
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resend() async {
    _isResending = true;
    notifyListeners();
    try {
      if (_flow == OtpFlow.signUp) {
        await _otpService.resendSignupOtp();
      } else {
        await _otpService.sendResetOtp(_model.email);
      }
      _submitted = false;
      _errors = {};
      _model = _model.copyWith(otp: '');
      return true;
    } on ApiException catch (e) {
      _errors = {'otp': e.message};
      return false;
    } catch (_) {
      _errors = {'otp': 'Could not resend OTP. Please try again.'};
      return false;
    } finally {
      _isResending = false;
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

  bool get sessionActive => _flow == OtpFlow.signUp
      ? SignupSession.instance.hasDraft
      : PasswordResetSession.instance.hasActiveRequest;
}
