import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isLocalStorageMode => true;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final localProfile = await _db.getLocalUserProfile();
      if (localProfile != null) {
        _currentUser = UserModel(
          id: 1,
          name: localProfile['name'] ?? 'User',
          email: localProfile['email'] ?? '',
          token: 'local_storage_token',
        );
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error loading local profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save or update profile in 100% Local Device SQLite Storage
  Future<bool> saveLocalProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _db.saveLocalUserProfile(name: name, email: email, phone: phone);
      _currentUser = UserModel(
        id: 1,
        name: name,
        email: email,
        token: 'local_storage_token',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save local profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Backward-compatible registration that stores directly into Local Storage
  Future<bool> register(String name, String email, [String? password]) async {
    return await saveLocalProfile(name: name, email: email);
  }

  /// Backward-compatible login that authenticates directly with Local Storage
  Future<bool> login(String email, [String? password]) async {
    final local = await _db.getLocalUserProfile();
    if (local != null) {
      _currentUser = UserModel(
        id: 1,
        name: local['name'] ?? 'User',
        email: local['email'] ?? email,
        token: 'local_storage_token',
      );
      notifyListeners();
      return true;
    }
    // Auto-create local profile if none exists
    return await saveLocalProfile(name: email.split('@').first, email: email);
  }

  Future<void> logout() async {
    await _db.clearLocalUserProfile();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
