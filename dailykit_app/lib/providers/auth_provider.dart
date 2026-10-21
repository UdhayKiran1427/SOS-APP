import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLocalStorageMode = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isLocalStorageMode => _isLocalStorageMode;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check LocalStorage first (Offline-First)
      final localProfile = await _db.getLocalUserProfile();
      if (localProfile != null) {
        _currentUser = UserModel(
          id: 1,
          name: localProfile['name'] ?? 'User',
          email: localProfile['email'] ?? '',
          token: 'local_storage_token',
        );
        _isLocalStorageMode = true;
      }

      // 2. If token exists and online, attempt cloud profile check
      final token = await _api.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          final remoteUser = await _api.getProfile();
          if (remoteUser != null) {
            _currentUser = remoteUser;
            _isLocalStorageMode = false;
            SyncService.instance.syncAll();
          }
        } catch (_) {
          // Keep local profile if remote check fails
        }
      }
    } catch (_) {
      // Ignore initial lookup errors
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatError(dynamic e) {
    if (e is DioException) {
      if (e.response != null && e.response?.data is Map) {
        final data = e.response!.data as Map;
        if (data['message'] != null) return data['message'].toString();
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return 'Server connection timed out.';
      }
      if (e.response?.statusCode == 404) {
        return 'Server endpoint not found.';
      }
      return 'Unable to reach backend server.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  /// Create or update profile directly in Local Storage (no server required)
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
      _isLocalStorageMode = true;
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

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Try cloud login
    try {
      _currentUser = await _api.login(email, password);
      _isLocalStorageMode = false;
      await _db.saveLocalUserProfile(
        name: _currentUser!.name,
        email: _currentUser!.email,
      );
      SyncService.instance.syncAll();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // 2. If cloud fails, check if local storage has matching profile
      final local = await _db.getLocalUserProfile();
      if (local != null && local['email']?.toLowerCase() == email.trim().toLowerCase()) {
        _currentUser = UserModel(
          id: 1,
          name: local['name'] ?? 'User',
          email: local['email'] ?? email,
          token: 'local_storage_token',
        );
        _isLocalStorageMode = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = _formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Always persist to LocalStorage first so the user is never blocked
    await _db.saveLocalUserProfile(name: name, email: email);

    // 2. Attempt cloud registration
    try {
      _currentUser = await _api.register(name, email, password);
      _isLocalStorageMode = false;
      SyncService.instance.syncAll();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      // 3. Fallback gracefully to Local Storage mode!
      _currentUser = UserModel(
        id: 1,
        name: name,
        email: email,
        token: 'local_storage_token',
      );
      _isLocalStorageMode = true;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    await _db.clearLocalUserProfile();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
