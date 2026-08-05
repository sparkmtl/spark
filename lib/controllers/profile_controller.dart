import 'package:flutter/foundation.dart';

import '../models/profile_model.dart';
import '../services/auth_api.dart';
import '../services/profile_api.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({ProfileApi? profileApi})
      : _profileApi = profileApi ?? ProfileApi();

  final ProfileApi _profileApi;

  ProfileModel _model = const ProfileModel();
  Map<String, String> _errors = {};
  bool _isLoading = false;
  bool _isSaving = false;
  String? _saveMessage;
  String? _loadError;

  ProfileModel get model => _model;
  Map<String, String> get errors => _errors;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get saveMessage => _saveMessage;
  String? get loadError => _loadError;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _model = await _profileApi.getProfile();
    } on ApiException catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Could not load profile. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get needsReauthentication {
    final messages = [loadError, saveMessage];
    for (final message in messages) {
      if (message == null) continue;
      final lower = message.toLowerCase();
      if (lower.contains('log in') ||
          lower.contains('authentication') ||
          lower.contains('session expired')) {
        return true;
      }
    }
    return false;
  }

  void setName(String value) {
    _model = _model.copyWith(name: value);
    _clearFieldError('name');
    notifyListeners();
  }

  void setAge(String value) {
    _model = _model.copyWith(age: value);
    _clearFieldError('age');
    notifyListeners();
  }

  void setAbout(String value) {
    _model = _model.copyWith(about: value);
    _clearFieldError('about');
    notifyListeners();
  }

  void setGender(ProfileGender gender) {
    _model = _model.copyWith(gender: gender);
    _clearFieldError('gender');
    notifyListeners();
  }

  void toggleIntent(LookingForIntent intent) {
    final next = Set<LookingForIntent>.from(_model.intents);
    LookingForGender? dateLookingFor;
    LookingForGender? friendsLookingFor;
    var clearDateLookingFor = false;
    var clearFriendsLookingFor = false;

    if (next.contains(intent)) {
      next.remove(intent);
      if (intent == LookingForIntent.date) {
        clearDateLookingFor = true;
      } else if (intent == LookingForIntent.makeFriends) {
        clearFriendsLookingFor = true;
      }
    } else {
      next.add(intent);
      if (intent == LookingForIntent.date) {
        dateLookingFor =
            _model.gender?.oppositeLookingFor ?? LookingForGender.any;
      } else if (intent == LookingForIntent.makeFriends) {
        friendsLookingFor = LookingForGender.any;
      }
    }

    _model = _model.copyWith(
      intents: next,
      dateLookingFor: dateLookingFor,
      friendsLookingFor: friendsLookingFor,
      clearDateLookingFor: clearDateLookingFor,
      clearFriendsLookingFor: clearFriendsLookingFor,
    );
    _clearFieldError('intents');
    notifyListeners();
  }

  void setDateLookingFor(LookingForGender value) {
    if (!_model.intents.contains(LookingForIntent.date)) {
      _model = _model.copyWith(
        intents: {..._model.intents, LookingForIntent.date},
        dateLookingFor: value,
      );
    } else {
      _model = _model.copyWith(dateLookingFor: value);
    }
    notifyListeners();
  }

  void setFriendsLookingFor(LookingForGender value) {
    if (!_model.intents.contains(LookingForIntent.makeFriends)) {
      _model = _model.copyWith(
        intents: {..._model.intents, LookingForIntent.makeFriends},
        friendsLookingFor: value,
      );
    } else {
      _model = _model.copyWith(friendsLookingFor: value);
    }
    notifyListeners();
  }

  Future<bool> save() async {
    if (_isSaving) return false;
    _saveMessage = null;
    final errors = _model.validate();
    _errors = errors;
    notifyListeners();
    if (errors.isNotEmpty) return false;

    _isSaving = true;
    notifyListeners();
    try {
      _model = await _profileApi.updateProfile(_model);
      _saveMessage = 'Profile saved';
      return true;
    } on ApiException catch (e) {
      if (e.fieldErrors != null && e.fieldErrors!.isNotEmpty) {
        _errors = Map<String, String>.from(e.fieldErrors!);
      } else {
        _saveMessage = e.message;
      }
      return false;
    } catch (_) {
      _saveMessage = 'Could not save profile. Please try again.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _clearFieldError(String key) {
    if (!_errors.containsKey(key)) return;
    _errors = Map<String, String>.from(_errors)..remove(key);
  }
}
