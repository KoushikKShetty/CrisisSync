/// Mock/demo handler — hardware sensor simulation + incident reports
library;

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../firebase_service.dart';
import '../gemini_service.dart';
import '../escalation_service.dart';

Response _json(int status, dynamic body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Future<Map<String, dynamic>> _parseBody(Request req) async {
  final body = await req.readAsString();
  return body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
}

Router buildMockRouter() {
  final router = Router();

  // POST /mock/hardware-event
  router.post('/hardware-event', (Request req) async {
    try {
      final body = await _parseBody(req);
      final sensorId = body['sensorId'] as String? ?? '';
      final zone = body['zone'] as String? ?? '';
      final zoneId = body['zoneId'] as String? ??
          zone.toLowerCase().replaceAll(' ', '-');
      final type = body['type'] as String? ?? '';
      final description = body['description'] as String? ?? '';

      if (sensorId.isEmpty || zone.isEmpty || type.isEmpty) {
        return _json(400, {
          'error': 'Missing required fields: sensorId, zone, type'
        });
      }

      final confidenceRaw = body['confidence'];
      final confidence = confidenceRaw != null
          ? (confidenceRaw as num).toDouble().clamp(0.0, 1.0)
          : 0.92;

      final actionPlan = await generateEmergencyProtocol(
          type, zone, description);

      final incidentData = {
        'title': 'Hardware Alert: ${type.toUpperCase()}',
        'description': description.isNotEmpty
            ? description
            : 'Automated alert triggered by sensor $sensorId',
        'zone': zone,
        'zoneId': zoneId,
        'type': type,
        'status': 'active',
        'severity': confidence >= 0.8
            ? 'critical'
            : confidence >= 0.5
                ? 'warning'
                : 'info',
        'createdAt': DateTime.now().toIso8601String(),
        'aiConfidence': confidence,
        'aiClassification': type,
        'createdBy': 'sensor:$sensorId',
        'actionPlan': actionPlan,
      };

      final incidentId =
          await dbPush('incidents', incidentData);

      final escalation = await escalateIncident(
        incidentId: incidentId,
        type: type,
        zone: zone,
        zoneId: zoneId,
        description: incidentData['description'] as String,
        confidence: confidence,
        actionPlan: actionPlan,
        source: 'hardware',
      );

      return _json(200, {
        'success': true,
        'incident': {'id': incidentId, ...incidentData},
        'escalation': {
          'level': escalation['level'],
          'confidence': '${(confidence * 100).round()}%',
          'notifiedStaff': escalation['notifiedStaff'],
          'firstRespondersCalled':
              escalation['firstRespondersCalled'],
          'responderTypes': escalation['responderTypes'],
          'message': escalation['message'],
        },
      });
    } catch (e) {
      print('[mock/hardware-event] $e');
      return _json(500, {'error': 'Failed to process hardware event'});
    }
  });

  // GET /mock/report/:incidentId
  router.get('/report/<incidentId>',
      (Request req, String incidentId) async {
    try {
      final incident = await dbGet('incidents/$incidentId') as Map?;
      if (incident == null) {
        return _json(404, {'error': 'Incident not found'});
      }
      final resolved = incident['status'] == 'resolved';
      final created = incident['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(incident['createdAt'].toString()) ??
                  0)
          : DateTime.now();
      final resolvedAt = incident['resolvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(incident['resolvedAt'].toString()) ??
                  0)
          : DateTime.now();

      return _json(200, {
        'reportId': 'RPT-$incidentId',
        'generatedAt': DateTime.now().toIso8601String(),
        'incident': {
          'id': incidentId,
          'title': incident['title'],
          'type': incident['aiClassification'],
          'zone': incident['zoneId'],
          'severity': incident['severity'],
          'description': incident['description'],
          'source': incident['createdBy'],
          'detectedAt': created.toIso8601String(),
          'resolvedAt':
              resolved ? resolvedAt.toIso8601String() : null,
          'durationMinutes': resolved
              ? resolvedAt.difference(created).inMinutes
              : null,
        },
        'outcome': resolved ? 'RESOLVED' : 'ONGOING',
      });
    } catch (e) {
      return _json(500, {'error': 'Failed to generate report'});
    }
  });

  // POST /mock/resolve/:incidentId
  router.post('/resolve/<incidentId>',
      (Request req, String incidentId) async {
    try {
      await dbUpdate('incidents/$incidentId', {
        'status': 'resolved',
        'resolvedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return _json(200, {'success': true});
    } catch (e) {
      return _json(500, {'error': 'Failed to resolve incident'});
    }
  });

  return router;
}
