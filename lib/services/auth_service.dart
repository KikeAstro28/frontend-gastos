import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_storage.dart';


const _storage = FlutterSecureStorage();
const _tokenKey = 'access_token';

class AuthService {
  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> logout() => _storage.delete(key: _tokenKey);

  static Future<void> register(String nickname, String password) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nickname': nickname, 'password': password}),
    );

    if (r.statusCode != 200) {
      throw Exception('Register error ${r.statusCode}: ${r.body}');
    }
  }

  static Future<void> login(String nickname, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nickname': nickname, 'password': password}),
    );

    if (r.statusCode != 200) {
      throw Exception('Login error ${r.statusCode}: ${r.body}');
    }

    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final token = (j['access_token'] as String?) ?? '';
    if (token.isEmpty) {
      throw Exception('Login error: token vacío. Body: ${r.body}');
    }
    await saveToken(token);
    print("TOKEN GUARDADO: $token");
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // =========================
  // ✅ NUEVO: MI CUENTA
  // =========================

  /// GET /me  -> { nickname: "...", email: "..." }
  static Future<Map<String, dynamic>> me() async {
    final uri = Uri.parse('$baseUrl/me');
    final headers = await authHeaders();

    final r = await http.get(uri, headers: headers);

    if (r.statusCode != 200) {
      throw Exception('Me error ${r.statusCode}: ${r.body}');
    }

    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// POST /me/email  body: { "email": "..." }
  static Future<void> updateEmail(String email) async {
    final uri = Uri.parse('$baseUrl/me/email');
    final headers = await authHeaders();

    final r = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'email': email}),
    );

    if (r.statusCode != 200) {
      throw Exception('Update email error ${r.statusCode}: ${r.body}');
    }
  }

  /// POST /me/change-password
  /// body: { "current_password": "...", "new_password": "..." }
  static Future<void> changePassword(String currentPw, String newPw) async {
    final uri = Uri.parse('$baseUrl/me/change-password');
    final headers = await authHeaders();

    final r = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'current_password': currentPw,
        'new_password': newPw,
      }),
    );

    if (r.statusCode != 200) {
      throw Exception('Change password error ${r.statusCode}: ${r.body}');
    }
  }
}
