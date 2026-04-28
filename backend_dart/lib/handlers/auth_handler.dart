/// Auth handler — all /auth/* endpoints
library;

import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../firebase_service.dart';
import '../config.dart';

// ── Helper: 6-char org code ────────────────────────────────────────
String _generateOrgCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
}

String _generateUid() =>
    'usr_${DateTime.now().millisecondsSinceEpoch}_${_randStr(9)}';
String _generateOrgId() =>
    'org_${DateTime.now().millisecondsSinceEpoch}_${_randStr(6)}';

String _randStr(int len) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
}

String _signToken(Map<String, dynamic> payload) {
  final secret = env('JWT_SECRET', 'super-secret-key-for-jwt');
  final jwt = JWT(payload);
  return jwt.sign(SecretKey(secret), expiresIn: const Duration(days: 7));
}

Response _json(int status, dynamic body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Future<Map<String, dynamic>> _parseBody(Request req) async {
  final body = await req.readAsString();
  return body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
}

// ── Router ────────────────────────────────────────────────────────
Router buildAuthRouter() {
  final router = Router();

  // POST /auth/org/register
  router.post('/org/register', (Request req) async {
    try {
      final body = await _parseBody(req);
      final orgName = body['orgName'] as String? ?? '';
      final location = body['location'] as String? ?? '';
      final contactEmail = body['contactEmail'] as String? ?? '';
      final password = body['password'] as String? ?? '';
      final adminName = body['adminName'] as String? ?? '';

      if (orgName.isEmpty ||
          location.isEmpty ||
          contactEmail.isEmpty ||
          password.isEmpty ||
          adminName.isEmpty) {
        return _json(400, {'error': 'All fields are required.'});
      }

      // Check email uniqueness
      final emailKey = contactEmail.replaceAll('.', ',');
      final existing = await dbGet('emailIndex/$emailKey');
      if (existing != null) {
        return _json(409,
            {'error': 'An account with this email already exists.'});
      }

      // Generate unique org code
      String orgCode = _generateOrgCode();
      while (true) {
        final snap = await dbQueryEqual(
            'organizations', 'orgCode', orgCode);
        if (snap == null || snap.isEmpty) break;
        orgCode = _generateOrgCode();
      }

      final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
      final uid = _generateUid();
      final orgId = _generateOrgId();
      final now = DateTime.now().millisecondsSinceEpoch;

      await dbSet('organizations/$orgId', {
        'orgId': orgId,
        'orgName': orgName,
        'location': location,
        'contactEmail': contactEmail,
        'orgCode': orgCode,
        'adminUid': uid,
        'createdAt': now,
      });

      await dbSet('users/$uid', {
        'uid': uid,
        'name': adminName,
        'email': contactEmail,
        'role': 'org_admin',
        'orgId': orgId,
        'orgName': orgName,
        'orgCode': orgCode,
        'status': 'online',
        'shiftActive': false,
        'createdAt': now,
      });

      await dbSet('credentials/$uid', {
        'email': contactEmail,
        'passwordHash': passwordHash,
      });
      await dbSet('emailIndex/$emailKey', uid);

      final token = _signToken(
          {'uid': uid, 'role': 'org_admin', 'orgId': orgId});

      return _json(201, {
        'message': 'Organization registered successfully.',
        'orgCode': orgCode,
        'orgId': orgId,
        'uid': uid,
        'token': token,
      });
    } catch (e) {
      print('[auth/org/register] $e');
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /auth/org/login
  router.post('/org/login', (Request req) async {
    try {
      final body = await _parseBody(req);
      final email = body['email'] as String? ?? '';
      final password = body['password'] as String? ?? '';

      if (email.isEmpty || password.isEmpty) {
        return _json(400,
            {'error': 'Email and password are required.'});
      }

      final emailKey = email.replaceAll('.', ',');
      final uid = await dbGet('emailIndex/$emailKey');
      if (uid == null) {
        return _json(404,
            {'error': 'No account found with this email.'});
      }

      final creds = await dbGet('credentials/$uid') as Map?;
      if (creds == null) {
        return _json(404, {'error': 'Credentials not found.'});
      }

      final valid = BCrypt.checkpw(
          password, creds['passwordHash'] as String);
      if (!valid) {
        return _json(401, {'error': 'Incorrect password.'});
      }

      final profile = await dbGet('users/$uid') as Map?;
      if (profile == null) {
        return _json(404, {'error': 'User profile not found.'});
      }

      if (profile['role'] != 'org_admin') {
        return _json(403, {
          'error': 'This account is not an organization admin.'
        });
      }

      await dbUpdate('users/$uid', {'status': 'online'});

      final token = _signToken({
        'uid': uid,
        'role': 'org_admin',
        'orgId': profile['orgId'],
      });

      return _json(200, {
        'message': 'Login successful.',
        'profile': {...Map<String, dynamic>.from(profile), 'status': 'online'},
        'token': token,
      });
    } catch (e) {
      print('[auth/org/login] $e');
      return _json(500, {'error': e.toString()});
    }
  });

  // GET /auth/staff/lookup-org?code=XXXX
  router.get('/staff/lookup-org', (Request req) async {
    try {
      final code =
          req.url.queryParameters['code']?.toUpperCase() ?? '';
      if (code.isEmpty) {
        return _json(400, {'error': 'Org code is required.'});
      }

      final orgs =
          await dbQueryEqual('organizations', 'orgCode', code);
      if (orgs == null || orgs.isEmpty) {
        return _json(404, {
          'error':
              'Invalid organization code. Please check with your manager.'
        });
      }

      final orgId = orgs.keys.first;
      final org = orgs[orgId] as Map;

      return _json(200, {
        'orgId': orgId,
        'orgName': org['orgName'],
        'location': org['location'],
        'orgCode': org['orgCode'],
      });
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /auth/staff/register
  router.post('/staff/register', (Request req) async {
    try {
      final body = await _parseBody(req);
      final orgCode = (body['orgCode'] as String? ?? '').toUpperCase();
      final name = body['name'] as String? ?? '';
      final staffRole = body['staffRole'] as String? ?? '';
      final email = body['email'] as String? ?? '';
      final password = body['password'] as String? ?? '';

      if (orgCode.isEmpty ||
          name.isEmpty ||
          staffRole.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        return _json(400, {'error': 'All fields are required.'});
      }

      final emailKey = email.replaceAll('.', ',');
      final existing = await dbGet('emailIndex/$emailKey');
      if (existing != null) {
        return _json(409,
            {'error': 'An account with this email already exists.'});
      }

      final orgs =
          await dbQueryEqual('organizations', 'orgCode', orgCode);
      if (orgs == null || orgs.isEmpty) {
        return _json(404, {'error': 'Invalid organization code.'});
      }

      final orgId = orgs.keys.first;
      final org = orgs[orgId] as Map;

      final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
      final uid = _generateUid();
      final now = DateTime.now().millisecondsSinceEpoch;

      await dbSet('users/$uid', {
        'uid': uid,
        'name': name,
        'email': email,
        'role': 'staff',
        'staffRole': staffRole,
        'orgId': orgId,
        'orgName': org['orgName'],
        'orgCode': orgCode,
        'status': 'offline',
        'shiftActive': false,
        'zone': null,
        'createdAt': now,
      });

      await dbSet('staff/$uid', {
        'uid': uid,
        'name': name,
        'email': email,
        'role': staffRole,
        'orgId': orgId,
        'status': 'offline',
        'shiftActive': false,
        'lastHeartbeat': now,
      });

      await dbSet('credentials/$uid', {
        'email': email,
        'passwordHash': passwordHash,
      });
      await dbSet('emailIndex/$emailKey', uid);

      final token = _signToken(
          {'uid': uid, 'role': 'staff', 'orgId': orgId});

      return _json(201, {
        'message': 'Staff account created successfully.',
        'uid': uid,
        'orgName': org['orgName'],
        'token': token,
      });
    } catch (e) {
      print('[auth/staff/register] $e');
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /auth/staff/login
  router.post('/staff/login', (Request req) async {
    try {
      final body = await _parseBody(req);
      final email = body['email'] as String? ?? '';
      final password = body['password'] as String? ?? '';

      if (email.isEmpty || password.isEmpty) {
        return _json(400,
            {'error': 'Email and password are required.'});
      }

      final emailKey = email.replaceAll('.', ',');
      final uid = await dbGet('emailIndex/$emailKey');
      if (uid == null) {
        return _json(404,
            {'error': 'No account found with this email.'});
      }

      final creds = await dbGet('credentials/$uid') as Map?;
      if (creds == null) return _json(404, {'error': 'Credentials not found.'});

      final valid = BCrypt.checkpw(
          password, creds['passwordHash'] as String);
      if (!valid) return _json(401, {'error': 'Incorrect password.'});

      final profile = await dbGet('users/$uid') as Map?;
      if (profile == null) return _json(404, {'error': 'User not found.'});

      await dbUpdate('users/$uid', {'status': 'online'});
      await dbUpdate('staff/$uid', {'status': 'available'}).catchError((_) {});

      final token = _signToken({
        'uid': uid,
        'role': profile['role'],
        'orgId': profile['orgId'],
      });

      return _json(200, {
        'message': 'Login successful.',
        'profile': {...Map<String, dynamic>.from(profile), 'status': 'online'},
        'token': token,
      });
    } catch (e) {
      print('[auth/staff/login] $e');
      return _json(500, {'error': e.toString()});
    }
  });

  // GET /auth/me?uid=xxx
  router.get('/me', (Request req) async {
    try {
      final uid = req.url.queryParameters['uid'] ?? '';
      if (uid.isEmpty) return _json(400, {'error': 'uid is required.'});
      final user = await dbGet('users/$uid');
      if (user == null) return _json(404, {'error': 'User not found.'});
      return _json(200, user);
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /auth/start-shift
  router.post('/start-shift', (Request req) async {
    try {
      final body = await _parseBody(req);
      final userId = body['userId'] as String? ?? '';
      await dbUpdate(
          'staff/$userId', {'shiftActive': true, 'status': 'available'});
      await dbUpdate('users/$userId', {'shiftActive': true});
      return _json(200, {'message': 'Shift started'});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /auth/end-shift
  router.post('/end-shift', (Request req) async {
    try {
      final body = await _parseBody(req);
      final userId = body['userId'] as String? ?? '';
      await dbUpdate(
          'staff/$userId', {'shiftActive': false, 'status': 'offline'});
      await dbUpdate(
          'users/$userId', {'shiftActive': false, 'status': 'offline'});
      return _json(200, {'message': 'Shift ended'});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  return router;
}
