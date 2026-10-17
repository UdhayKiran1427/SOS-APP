import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import '../models/alert_model.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // For Android emulator 10.0.2.2 or physical phone over adb reverse localhost:3000
  static const String defaultBaseUrl = 'http://10.0.2.2:3000';
  String _baseUrl = defaultBaseUrl;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor for dynamic auth token injection
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Log or handle centralized errors
          return handler.next(error);
        },
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  String get baseUrl => _baseUrl;

  // ================= TOKEN MANAGEMENT =================

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // ================= AUTH ENDPOINTS =================

  Future<UserModel> register(String name, String email, String password) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });

    final data = response.data;
    if (data['success'] == true) {
      final token = data['token'] as String;
      await saveToken(token);
      return UserModel.fromJson(data['user'], token: token);
    }
    throw Exception(data['message'] ?? 'Registration failed');
  }

  Future<UserModel> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final data = response.data;
    if (data['success'] == true) {
      final token = data['token'] as String;
      await saveToken(token);
      return UserModel.fromJson(data['user'], token: token);
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<UserModel?> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await _dio.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return UserModel.fromJson(response.data['user'], token: token);
      }
    } catch (_) {
      // offline or token expired
    }
    return null;
  }

  // ================= CONTACTS ENDPOINTS =================

  Future<List<ContactModel>> fetchRemoteContacts() async {
    final response = await _dio.get('/contacts');
    if (response.data['success'] == true) {
      final list = response.data['contacts'] as List<dynamic>;
      return list.map((json) => ContactModel.fromRemoteJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<int?> createRemoteContact(ContactModel contact) async {
    final response = await _dio.post('/contacts', data: contact.toRemoteJson());
    if (response.data['success'] == true && response.data['contact'] != null) {
      return response.data['contact']['id'] as int?;
    }
    return null;
  }

  Future<bool> updateRemoteContact(ContactModel contact) async {
    if (contact.remoteId == null) return false;
    final response = await _dio.put('/contacts/${contact.remoteId}', data: contact.toRemoteJson());
    return response.data['success'] == true;
  }

  Future<bool> deleteRemoteContact(int remoteId) async {
    final response = await _dio.delete('/contacts/$remoteId');
    return response.data['success'] == true;
  }

  // ================= SOS ENDPOINTS =================

  Future<int?> uploadAlert(AlertModel alert) async {
    final response = await _dio.post('/sos/log', data: alert.toRemoteJson());
    if (response.data['success'] == true) {
      return response.data['alert_id'] as int?;
    }
    return null;
  }

  Future<List<AlertModel>> fetchAlertHistory({int page = 1, int limit = 20}) async {
    final response = await _dio.get('/sos/history', queryParameters: {
      'page': page,
      'limit': limit,
    });

    if (response.data['success'] == true) {
      final list = response.data['alerts'] as List<dynamic>;
      return list.map((json) => AlertModel.fromRemoteJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

