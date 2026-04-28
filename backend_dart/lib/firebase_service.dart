/// Firebase REST API wrapper — replaces firebase-admin Node SDK
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'config.dart';

String _databaseUrl = '';
String _projectId = '';
String _clientEmail = '';
String _privateKey = '';

// ── cached service account JWT (expires 1h) ────────────────────────
String? _cachedToken;
DateTime? _tokenExpiry;

void initFirebase() {
  _projectId = env('FIREBASE_PROJECT_ID');
  _clientEmail = env('FIREBASE_CLIENT_EMAIL');
  _privateKey = env('FIREBASE_PRIVATE_KEY').replaceAll(r'\n', '\n');
  _databaseUrl = env('FIREBASE_DATABASE_URL').replaceAll(RegExp(r'/$'), '');

  if (_projectId.isEmpty) {
    throw Exception('FIREBASE_PROJECT_ID not set in .env');
  }
  print('🔥 Firebase REST initialized — project: $_projectId');
}

// ── Build a Google service-account OAuth2 JWT ──────────────────────
Future<String> _getAccessToken() async {
  final now = DateTime.now();
  if (_cachedToken != null &&
      _tokenExpiry != null &&
      now.isBefore(_tokenExpiry!)) {
    return _cachedToken!;
  }

  final iat = now.millisecondsSinceEpoch ~/ 1000;
  final exp = iat + 3600;

  // Sign a JWT with the RSA private key
  final jwt = JWT({
    'iss': _clientEmail,
    'sub': _clientEmail,
    'aud': 'https://oauth2.googleapis.com/token',
    'iat': iat,
    'exp': exp,
    'scope':
        'https://www.googleapis.com/auth/firebase https://www.googleapis.com/auth/userinfo.email',
  });

  final token = jwt.sign(
    RSAPrivateKey(_privateKey),
    algorithm: JWTAlgorithm.RS256,
  );

  // Exchange for access token
  final res = await http.post(
    Uri.parse('https://oauth2.googleapis.com/token'),
    body: {
      'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      'assertion': token,
    },
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to get Firebase access token: ${res.body}');
  }

  final data = jsonDecode(res.body);
  _cachedToken = data['access_token'] as String;
  _tokenExpiry = now.add(const Duration(minutes: 55));
  return _cachedToken!;
}

// ── RTDB Read ──────────────────────────────────────────────────────
Future<dynamic> dbGet(String path) async {
  final token = await _getAccessToken();
  final url = Uri.parse('$_databaseUrl/$path.json');
  final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode == 200) {
    return jsonDecode(res.body);
  }
  throw Exception('Firebase GET $path failed: ${res.statusCode} ${res.body}');
}

// ── RTDB Write (SET) ───────────────────────────────────────────────
Future<void> dbSet(String path, dynamic value) async {
  final token = await _getAccessToken();
  final url = Uri.parse('$_databaseUrl/$path.json');
  final res = await http.put(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(value),
  );
  if (res.statusCode != 200) {
    throw Exception('Firebase SET $path failed: ${res.statusCode} ${res.body}');
  }
}

// ── RTDB Update (PATCH) ────────────────────────────────────────────
Future<void> dbUpdate(String path, Map<String, dynamic> updates) async {
  final token = await _getAccessToken();
  final url = Uri.parse('$_databaseUrl/$path.json');
  final res = await http.patch(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(updates),
  );
  if (res.statusCode != 200) {
    throw Exception(
        'Firebase UPDATE $path failed: ${res.statusCode} ${res.body}');
  }
}

// ── RTDB Push (POST) ───────────────────────────────────────────────
Future<String> dbPush(String path, dynamic value) async {
  final token = await _getAccessToken();
  final url = Uri.parse('$_databaseUrl/$path.json');
  final res = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(value),
  );
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['name'] as String;
  }
  throw Exception(
      'Firebase PUSH $path failed: ${res.statusCode} ${res.body}');
}

// ── RTDB Delete ────────────────────────────────────────────────────
Future<void> dbDelete(String path) async {
  final token = await _getAccessToken();
  final url = Uri.parse('$_databaseUrl/$path.json');
  await http.delete(url, headers: {'Authorization': 'Bearer $token'});
}

// ── Query by child (orderBy + equalTo) — uses REST query params ────
Future<Map<String, dynamic>?> dbQueryEqual(
    String path, String orderByChild, String equalTo) async {
  final token = await _getAccessToken();
  final url = Uri.parse(
      '$_databaseUrl/$path.json?orderBy="${Uri.encodeComponent(orderByChild)}"&equalTo="${Uri.encodeComponent(equalTo)}"');
  final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }
  throw Exception(
      'Firebase QUERY $path failed: ${res.statusCode} ${res.body}');
}
