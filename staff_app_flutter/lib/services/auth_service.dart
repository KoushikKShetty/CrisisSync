import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // ─── Change this to your backend URL ───
  static const String _baseUrl = 'http://localhost:8080';

  static const String _keyUid = 'cs_uid';
  static const String _keyName = 'cs_name';
  static const String _keyEmail = 'cs_email';
  static const String _keyRole = 'cs_role';
  static const String _keyStaffRole = 'cs_staff_role';
  static const String _keyOrgId = 'cs_org_id';
  static const String _keyOrgName = 'cs_org_name';
  static const String _keyOrgCode = 'cs_org_code';

  // ─────────────────────────────────────────────
  // Session helpers
  // ─────────────────────────────────────────────

  static Future<void> saveSession(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, profile['uid'] ?? '');
    await prefs.setString(_keyName, profile['name'] ?? '');
    await prefs.setString(_keyEmail, profile['email'] ?? '');
    await prefs.setString(_keyRole, profile['role'] ?? '');
    await prefs.setString(_keyStaffRole, profile['staffRole'] ?? '');
    await prefs.setString(_keyOrgId, profile['orgId'] ?? '');
    await prefs.setString(_keyOrgName, profile['orgName'] ?? '');
    await prefs.setString(_keyOrgCode, profile['orgCode'] ?? '');
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_keyUid);
    if (uid == null || uid.isEmpty) return null;
    return {
      'uid': uid,
      'name': prefs.getString(_keyName) ?? '',
      'email': prefs.getString(_keyEmail) ?? '',
      'role': prefs.getString(_keyRole) ?? '',
      'staffRole': prefs.getString(_keyStaffRole) ?? '',
      'orgId': prefs.getString(_keyOrgId) ?? '',
      'orgName': prefs.getString(_keyOrgName) ?? '',
      'orgCode': prefs.getString(_keyOrgCode) ?? '',
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final session = await getSession();
    return session != null;
  }

  // ─────────────────────────────────────────────
  // ORG ADMIN — Register
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerOrg({
    required String orgName,
    required String location,
    required String adminName,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/org/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orgName': orgName,
        'location': location,
        'adminName': adminName,
        'contactEmail': email,
        'password': password,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 201) {
      throw Exception(body['error'] ?? 'Registration failed.');
    }
    return body;
  }

  // ─────────────────────────────────────────────
  // ORG ADMIN — Login
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> loginOrg({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/org/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Login failed.');
    }
    await saveSession(body['profile']);
    return body['profile'];
  }

  // ─────────────────────────────────────────────
  // STAFF — Lookup org by code
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> lookupOrg(String code) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/staff/lookup-org?code=${code.trim().toUpperCase()}'),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Invalid org code.');
    }
    return body;
  }

  // ─────────────────────────────────────────────
  // STAFF — Register (join org)
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerStaff({
    required String orgCode,
    required String name,
    required String staffRole,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/staff/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orgCode': orgCode,
        'name': name,
        'staffRole': staffRole,
        'email': email,
        'password': password,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 201) {
      throw Exception(body['error'] ?? 'Registration failed.');
    }
    return body;
  }

  // ─────────────────────────────────────────────
  // STAFF — Login
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> loginStaff({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/staff/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Login failed.');
    }
    await saveSession(body['profile']);
    return body['profile'];
  }
}
