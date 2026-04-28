/// Incidents handler — /incidents/* endpoints
library;

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../firebase_service.dart';

Response _json(int status, dynamic body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Future<Map<String, dynamic>> _parseBody(Request req) async {
  final body = await req.readAsString();
  return body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
}

Router buildIncidentsRouter() {
  final router = Router();

  // GET /incidents
  router.get('/', (Request req) async {
    try {
      final data = await dbGet('incidents');
      return _json(200, data ?? {});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /incidents
  router.post('/', (Request req) async {
    try {
      final body = await _parseBody(req);
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final incident = {
        'id': id,
        'title': body['title'] ?? '',
        'description': body['description'] ?? '',
        'zoneId': body['zoneId'] ?? '',
        'severity': body['severity'] ?? 'warning',
        'status': 'pending',
        'createdBy': body['createdBy'] ?? 'unknown',
        'standbyResponders': [],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      await dbSet('incidents/$id', incident);
      return _json(201, {'message': 'Incident created', 'incident': incident});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /incidents/:id/accept
  router.post('/<id>/accept', (Request req, String id) async {
    try {
      final body = await _parseBody(req);
      final userId = body['userId'] as String? ?? '';
      final incident = await dbGet('incidents/$id') as Map?;
      if (incident == null) {
        return _json(404, {'error': 'Incident not found.'});
      }
      if (incident['status'] != 'pending') {
        return _json(409, {'error': 'Incident already assigned or resolved.'});
      }
      await dbUpdate('incidents/$id', {
        'status': 'assigned',
        'assignedTo': userId,
        'assignedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return _json(200, {'message': 'Incident accepted'});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /incidents/:id/resolve
  router.post('/<id>/resolve', (Request req, String id) async {
    try {
      await dbUpdate('incidents/$id', {
        'status': 'resolved',
        'resolvedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return _json(200, {'message': 'Incident resolved'});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /incidents/:id/false-alarm
  router.post('/<id>/false-alarm', (Request req, String id) async {
    try {
      await dbUpdate('incidents/$id', {
        'status': 'false_alarm',
        'resolvedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return _json(200, {'message': 'Marked as false alarm'});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  // POST /incidents/:id/escalate
  router.post('/<id>/escalate', (Request req, String id) async {
    try {
      await dbUpdate('incidents/$id', {'escalated': true});
      return _json(200, {'message': 'Incident escalated'});
    } catch (e) {
      return _json(500, {'error': e.toString()});
    }
  });

  return router;
}
