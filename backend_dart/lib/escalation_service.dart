/// 3-tier escalation service — mirrors Node.js escalationService.ts
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'firebase_service.dart';
import 'websocket_service.dart';

// ── Confidence thresholds ──────────────────────────────────────────
const double _thresholdZoneOnly = 0.50;
const double _thresholdAllStaff = 0.80;

// ── BLE zone cache (reloaded from Firebase every 5 minutes) ───────
Map<String, List<Map<String, String>>>? _dynamicBleZones;
DateTime? _bleZonesLoadedAt;

// ── Fallback static BLE staff per zone ────────────────────────────
const Map<String, List<Map<String, String>>> _bleStaffZones = {
  'kitchen-alpha': [
    {'id': 'mc', 'name': 'Marcus Chen', 'role': 'Security Lead'},
    {'id': 'dp', 'name': 'David Park', 'role': 'Fire Safety'},
  ],
  'lobby': [
    {'id': 'sm', 'name': 'Sarah Miller', 'role': 'Medic'},
  ],
  'pool': [
    {'id': 'lt', 'name': 'Lisa Tran', 'role': 'Maintenance'},
  ],
  'parking': [],
  'restaurant': [],
};

const Map<String, List<String>> _responderTypes = {
  'fire': ['🚒 Fire Department', '🚑 Ambulance'],
  'medical': ['🚑 Ambulance', '🏥 Medical Team'],
  'security': ['🚔 Police', '🛡️ Security Command'],
  'flood': ['🚒 Fire Department', '🏛️ Civil Emergency'],
};

const List<String> _defaultResponders = [
  '🚑 Ambulance',
  '🚒 Fire Department',
  '🚔 Police',
];

// ── Load BLE staff zones from Firebase (cached 5 min) ─────────────
Future<Map<String, List<Map<String, String>>>> _getActiveBleZones() async {
  final now = DateTime.now();
  final cacheValid = _bleZonesLoadedAt != null &&
      now.difference(_bleZonesLoadedAt!).inMinutes < 5;

  if (_dynamicBleZones != null && cacheValid) return _dynamicBleZones!;

  try {
    final raw = await dbGet('ble_staff_zones');
    if (raw != null && raw is Map) {
      final parsed = <String, List<Map<String, String>>>{};
      for (final entry in raw.entries) {
        final zoneId = entry.key as String;
        final staffList = entry.value;
        if (staffList is List) {
          parsed[zoneId] = staffList
              .whereType<Map>()
              .map((s) => s.map((k, v) => MapEntry(k.toString(), v.toString())))
              .toList();
        }
      }
      _dynamicBleZones = parsed;
      _bleZonesLoadedAt = now;
      print('[BLE] Loaded ${parsed.length} zones from Firebase');
      return _dynamicBleZones!;
    }
  } catch (e) {
    print('[BLE] Firebase load failed — using static fallback: $e');
  }

  return _bleStaffZones;
}

// ── Webhook dispatch to external emergency system ─────────────────
Future<void> _webhookDispatch({
  required String incidentId,
  required String type,
  required String zone,
  required String description,
  required double confidence,
  required List<String> responderTypes,
  required String eta,
}) async {
  final webhookUrl = env('EMERGENCY_WEBHOOK_URL', '');
  if (webhookUrl.isEmpty) return;

  final payload = {
    'event': 'first_responders_dispatched',
    'incidentId': incidentId,
    'timestamp': DateTime.now().toIso8601String(),
    'incident': {
      'type': type,
      'zone': zone,
      'description': description,
      'confidence': (confidence * 100).round(),
    },
    'dispatch': {
      'responderTypes': responderTypes,
      'eta': eta,
      'dispatchedBy': 'CrisisSync AI',
    },
    'source': 'crisisync-backend',
  };

  try {
    final res = await http
        .post(
          Uri.parse(webhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      print('[Dispatch] Webhook delivered → $webhookUrl (${res.statusCode})');
    } else {
      print('[Dispatch] Webhook returned ${res.statusCode}');
    }

    // Log delivery status to Firebase
    await dbSet('dispatch_logs/$incidentId', {
      ...payload,
      'webhookStatus': res.statusCode,
      'deliveredAt': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    print('[Dispatch] Webhook failed: $e — logging to Firebase only');
    await dbSet('dispatch_logs/$incidentId', {
      ...payload,
      'webhookStatus': 'failed',
      'error': e.toString(),
      'loggedAt': DateTime.now().toIso8601String(),
    });
  }
}

Future<Map<String, dynamic>> escalateIncident({
  required String incidentId,
  required String type,
  required String zone,
  required String zoneId,
  required String description,
  required double confidence,
  required List<String> actionPlan,
  required String source,
}) async {
  final timeline = <Map<String, String>>[];
  final now = DateTime.now().toIso8601String();

  final sourceLabel = source == 'hardware'
      ? 'IoT Sensor'
      : source == 'guest_qr'
          ? 'Guest QR Portal'
          : 'Staff Report';

  timeline.add({
    'timestamp': now,
    'action': 'Incident detected via $sourceLabel',
    'actor': 'CrisisSync AI',
  });

  // ── Level 1: Zone BLE staff (always) ────────────────────────────
  final bleZones = await _getActiveBleZones();
  final nearbyStaff = bleZones[zoneId] ?? [];
  final notifiedStaff = nearbyStaff.map((s) => s['name']!).toList();

  if (nearbyStaff.isNotEmpty) {
    timeline.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action':
          'BLE zone alert sent to ${nearbyStaff.length} staff in $zone',
      'actor': 'BLE Zone System',
    });

    broadcast('zone_alert', {
      'incidentId': incidentId,
      'zone': zone,
      'type': type,
      'description': description,
      'actionPlan': actionPlan,
      'confidence': confidence,
      'targetStaff': nearbyStaff.map((s) => s['id']).toList(),
      'message':
          '⚡ Zone Alert: ${type.toUpperCase()} in your zone ($zone). You are the nearest responder.',
    });
  }

  String level = 'zone_only';
  bool firstRespondersCalled = false;
  List<String> responderTypes = [];

  // ── Level 2: All staff ≥ 50% ────────────────────────────────────
  if (confidence >= _thresholdZoneOnly) {
    level = 'all_staff';
    timeline.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action':
          'All on-duty staff alerted (confidence: ${(confidence * 100).round()}%)',
      'actor': 'CrisisSync AI',
    });

    broadcast('hardware_alert', {
      'incidentId': incidentId,
      'title': '${type.toUpperCase()} — $zone',
      'zone': zone,
      'description': description,
      'actionPlan': actionPlan,
      'confidence': (confidence * 100).round(),
      'severity': confidence >= _thresholdAllStaff ? 'CRITICAL' : 'WARNING',
    });
  }

  // ── Level 3: First responders ≥ 80% ─────────────────────────────
  if (confidence >= _thresholdAllStaff) {
    level = 'first_responders';
    firstRespondersCalled = true;
    responderTypes =
        _responderTypes[type.toLowerCase()] ?? _defaultResponders;

    final eta = '${3 + (DateTime.now().millisecond % 5)} minutes';

    timeline.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action':
          'First responders contacted: ${responderTypes.join(', ')}',
      'actor': 'Emergency Dispatch',
    });

    broadcast('responders_dispatched', {
      'incidentId': incidentId,
      'zone': zone,
      'responderTypes': responderTypes,
      'eta': eta,
      'message':
          '🚨 Emergency services dispatched to $zone. ETA: $eta',
    });

    // Fire-and-forget — don't block the response
    _webhookDispatch(
      incidentId: incidentId,
      type: type,
      zone: zone,
      description: description,
      confidence: confidence,
      responderTypes: responderTypes,
      eta: eta,
    ).ignore();
  }

  // ── Save to Firebase ─────────────────────────────────────────────
  final result = {
    'level': level,
    'confidence': confidence,
    'notifiedStaff': notifiedStaff,
    'firstRespondersCalled': firstRespondersCalled,
    'responderTypes': responderTypes,
    'timeline': timeline,
    'message': _buildMessage(
        level, zone, confidence, responderTypes),
  };

  await dbUpdate('incidents/$incidentId', {
    'escalation': result,
    'status': level == 'first_responders' ? 'escalated' : 'active',
  });

  print(
      '[Escalation] $incidentId → ${level.toUpperCase()} (${(confidence * 100).round()}%)');
  return result;
}

String _buildMessage(String level, String zone, double confidence,
    List<String> responderTypes) {
  final pct = (confidence * 100).round();
  if (level == 'first_responders') {
    return 'CRITICAL ($pct% confidence): Emergency services dispatched to $zone. ${responderTypes.join(', ')} en route.';
  }
  if (level == 'all_staff') {
    return 'HIGH ($pct% confidence): All on-duty staff alerted for incident in $zone.';
  }
  return 'MODERATE ($pct% confidence): BLE-nearest staff in $zone notified only.';
}
