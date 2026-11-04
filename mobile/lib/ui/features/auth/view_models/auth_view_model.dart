import 'package:flutter/foundation.dart';
import '../../../../data/models/auth_models.dart';
import '../../../../data/repositories/fitness_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final FitnessRepository _repository;

  AuthViewModel({
    required FitnessRepository repository,
  }) : _repository = repository;

  UserProfileModel? _currentUser;
  UserProfileModel? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  bool get needsOnboarding =>
      _currentUser != null && !_currentUser!.onboardingCompleted;

  bool _isBootstrapping = true;
  bool get isBootstrapping => _isBootstrapping;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String get apiBaseUrl => _repository.currentApiBaseUrl;

  Future<void> bootstrapSession() async {
    _isBootstrapping = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.initializeSavedApiUrl();
      _currentUser = await _repository.fetchCurrentSessionProfile();
    } catch (_) {
      _currentUser = null;
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> setServerUrl(String url) async {
    await _repository.setCustomApiBaseUrl(url);
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.login(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.register(
        username: username,
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfileOnboarding(ProfileSetupRequestModel payload) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.completeProfileSetup(payload);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('HttpException: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    try {
      final UserProfileModel? refreshed =
          await _repository.fetchCurrentSessionProfile();
      if (refreshed != null) {
        _currentUser = refreshed;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
