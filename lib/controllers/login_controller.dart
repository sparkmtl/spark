import 'package:flutter/foundation.dart';

import '../models/login_model.dart';
import '../services/auth_api.dart';

class LoginController extends ChangeNotifier {
  LoginController({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  final AuthApi _authApi;

  LoginModel _model = const LoginModel();
  Map<String, String> _errors = {};
  bool _obscurePassword = true;
  bool _submitted = false;
  bool _isSubmitting = false;

  LoginModel get model => _model;
  Map<String, String> get errors => _errors;
  bool get obscurePassword => _obscurePassword;
  bool get isSubmitting => _isSubmitting;

  void updateEmail(String value) {
    _model = _model.copyWith(email: value);
    _revalidateIfNeeded();
  }

  void updatePassword(String value) {
    _model = _model.copyWith(password: value);
    _revalidateIfNeeded();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
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
      await _authApi.login(
        usernameOrEmail: _model.email.trim(),
        password: _model.password,
      );
      return true;
    } on ApiException catch (e) {
      if (e.fieldErrors != null && e.fieldErrors!.isNotEmpty) {
        _errors = Map<String, String>.from(e.fieldErrors!);
      } else {
        _errors = {'email': e.message};
      }
      return false;
    } catch (_) {
      _errors = {'email': 'Could not log in. Please try again.'};
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
