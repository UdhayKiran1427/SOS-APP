import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _api.getProfile();
      _currentUser = user;
      if (_currentUser != null) {
        SyncService.instance.syncAll();
      }
    } catch (_) {
      _currentUser = null;
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
        return 'Server connection timed out. Please try again.';
      }
      if (e.response?.statusCode == 404) {
        return 'Server endpoint not found. Please verify backend deployment.';
      }
      return 'Unable to reach backend server. Please check internet connection.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _api.login(email, password);
      SyncService.instance.syncAll();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
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

    try {
      _currentUser = await _api.register(name, email, password);
      SyncService.instance.syncAll();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
