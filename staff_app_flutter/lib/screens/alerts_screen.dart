import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _incidents = [];

  static const String _baseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/incidents'));
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw is Map) {
          final list = raw.values
              .where((v) => v is Map)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          list.sort((a, b) =>
              (b['createdAt'] as int? ?? 0)
                  .compareTo(a['createdAt'] as int? ?? 0));
          setState(() {
            _incidents = list;
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      // Use mock data if backend unreachable
      setState(() {
        _incidents = _mockIncidents;
        _loading = false;
      });
    }
  }

  Future<void> _resolve(String id) async {
    try {
      await http.post(Uri.parse('$_baseUrl/incidents/$id/resolve'));
      await _loadIncidents();
    } catch (_) {}
  }

  Future<void> _markFalseAlarm(String id) async {
    try {
      await http.post(Uri.parse('$_baseUrl/incidents/$id/false-alarm'));
      await _loadIncidents();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentCyan),
                ),
              )
            else if (_incidents.isEmpty)
              const Expanded(child: _EmptyState())
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadIncidents,
                  color: AppTheme.accentCyan,
                  backgroundColor: AppTheme.bgCard,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _incidents.length,
                    itemBuilder: (_, i) => _buildIncidentTile(_incidents[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final active =
        _incidents.where((i) => i['status'] == 'active' || i['status'] == 'pending').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(bottom: BorderSide(color: AppTheme.borderDefault)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Incident Log',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            Text('${_incidents.length} total • $active active',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
          ]),
          Row(children: [
            if (active > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.criticalRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                      color: AppTheme.criticalRed.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.alertTriangle,
                      color: AppTheme.criticalRed, size: 12),
                  const SizedBox(width: 5),
                  Text('$active ACTIVE',
                      style: const TextStyle(
                          color: AppTheme.criticalRed,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() => _loading = true);
                _loadIncidents();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDefault),
                ),
                child: const Icon(LucideIcons.refreshCw,
                    color: AppTheme.accentCyan, size: 16),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildIncidentTile(Map<String, dynamic> incident) {
    final status = incident['status'] as String? ?? 'unknown';
    final severity = incident['severity'] as String? ?? 'info';
    final id = incident['id'] as String? ?? '';
    final isActive = status == 'active' || status == 'pending';

    Color statusColor;
    Color severityColor;
    IconData severityIcon;

    switch (severity) {
      case 'critical':
        severityColor = AppTheme.criticalRed;
        severityIcon = LucideIcons.alertOctagon;
        break;
      case 'warning':
        severityColor = AppTheme.warningAmber;
        severityIcon = LucideIcons.alertTriangle;
        break;
      default:
        severityColor = AppTheme.infoBlue;
        severityIcon = LucideIcons.info;
    }

    switch (status) {
      case 'active':
      case 'pending':
        statusColor = AppTheme.criticalRed;
        break;
      case 'assigned':
        statusColor = AppTheme.warningAmber;
        break;
      case 'resolved':
        statusColor = AppTheme.successGreen;
        break;
      default:
        statusColor = AppTheme.textMuted;
    }

    final createdAt = incident['createdAt'];
    String timeStr = '';
    if (createdAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(createdAt.toString()) ?? 0);
      timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isActive
              ? severityColor.withValues(alpha: 0.4)
              : AppTheme.borderDefault,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: severityColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(severityIcon, color: severityColor, size: 16),
                const SizedBox(width: 8),
                Text(severity.toUpperCase(),
                    style: TextStyle(
                        color: severityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ]),
              Row(children: [
                if (timeStr.isNotEmpty)
                  Text(timeStr,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 10),
          Text(incident['title'] as String? ?? 'Untitled',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          if (incident['description'] != null) ...[
            const SizedBox(height: 4),
            Text(incident['description'] as String,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (incident['zoneId'] != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(LucideIcons.mapPin,
                  color: AppTheme.textMuted, size: 11),
              const SizedBox(width: 5),
              Text(incident['zoneId'] as String,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ],
          if (isActive && id.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _resolve(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusButton),
                      border: Border.all(
                          color:
                              AppTheme.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Text('✓ RESOLVE',
                          style: TextStyle(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _markFalseAlarm(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusButton),
                      border: Border.all(
                          color: AppTheme.textMuted.withValues(alpha: 0.2)),
                    ),
                    child: const Center(
                      child: Text('FALSE ALARM',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.8)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.shieldCheck,
                color: AppTheme.successGreen, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('All Clear',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('No active incidents.\nAll systems operational.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

// Mock data for when backend is offline
const List<Map<String, dynamic>> _mockIncidents = [
  {
    'id': 'INC-001',
    'title': 'Smoke Detected — Kitchen Alpha',
    'description':
        'Sensor SMK-402 triggered. Elevated particulate at 340 PPM.',
    'zoneId': 'kitchen-alpha',
    'severity': 'critical',
    'status': 'active',
    'createdAt': 0,
  },
  {
    'id': 'INC-002',
    'title': 'Guest Medical Request — Room 214',
    'description': 'Guest reported feeling unwell. Medical team dispatched.',
    'zoneId': 'lobby',
    'severity': 'warning',
    'status': 'assigned',
    'createdAt': 0,
  },
  {
    'id': 'INC-003',
    'title': 'Pool Area — Slip Hazard',
    'description': 'Wet floor reported near pool entrance.',
    'zoneId': 'pool',
    'severity': 'info',
    'status': 'resolved',
    'createdAt': 0,
  },
];
