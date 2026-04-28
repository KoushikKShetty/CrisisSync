/// 3-tier escalation service — mirrors Node.js escalationService.ts
library;

import 'firebase_service.dart';
import 'websocket_service.dart';

// ── Confidence thresholds ──────────────────────────────────────────
const double _thresholdZoneOnly = 0.50;
const double _thresholdAllStaff = 0.80;

// ── Mock BLE staff per zone ────────────────────────────────────────
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
  final nearbyStaff = _bleStaffZones[zoneId] ?? [];
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

  await dbUpdate(
      'incidents/$incidentId', {'escalation': result, 'status': level == 'first_responders' ? 'escalated' : 'active'});

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
