import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _isLive = false;
  List<Map<String, dynamic>> _incidents = [];

  WebSocketChannel? _channel;
  late AnimationController _pulseController;

  static const String _baseUrl = 'http://localhost:8080';
  static const String _wsUrl = 'ws://localhost:8080/ws';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadIncidents();
    _connectWs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  // ── WebSocket ────────────────────────────────────────────────────

  void _connectWs() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      if (mounted) setState(() => _isLive = true);

      _channel!.stream.listen(
        (raw) {
          if (!mounted) return;
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            _handleWsEvent(data['event'] as String? ?? '', data);
          } catch (_) {}
        },
        onError: (_) {
          if (mounted) setState(() => _isLive = false);
        },
        onDone: () {
          if (mounted) setState(() => _isLive = false);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _connectWs();
          });
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (mounted) setState(() => _isLive = false);
    }
  }

  void _handleWsEvent(String event, Map<String, dynamic> data) {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (event == 'hardware_alert' || event == 'zone_alert') {
      final isCritical =
          event == 'hardware_alert' && data['severity'] != 'WARNING';
      final incident = <String, dynamic>{
        'id': 'LIVE-$now',
        'title': data['title'] as String? ??
            (event == 'zone_alert'
                ? '⚡ Zone Alert — ${data['zone']}'
                : '🚨 ${data['zone'] ?? 'ALERT'}'),
        'description': data['description'] as String? ?? '',
        'zoneId': data['zone'] as String? ?? '',
        'severity': isCritical ? 'critical' : 'warning',
        'status': 'active',
        'createdAt': now,
        '_live': true,
      };
      setState(() => _incidents.insert(0, incident));
    } else if (event == 'responders_dispatched') {
      // Mark the first active incident as escalated and attach responder info
      setState(() {
        final idx = _incidents.indexWhere(
            (i) => i['status'] == 'active' || i['status'] == 'pending');
        if (idx != -1) {
          _incidents[idx] = {
            ..._incidents[idx],
            'status': 'escalated',
            'responders': data['responderTypes'],
            'responderEta': data['eta'],
          };
        }
      });
    }
  }

  // ── REST ─────────────────────────────────────────────────────────

  Future<void> _loadIncidents() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/incidents'));
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw is Map) {
          final list = raw.values
              .whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v))
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

  // ── Build ────────────────────────────────────────────────────────

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
    final active = _incidents
        .where((i) =>
            i['status'] == 'active' ||
            i['status'] == 'pending' ||
            i['status'] == 'escalated')
        .length;

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
            Row(children: [
              const Text('Incident Log',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              const SizedBox(width: 10),
              _buildLiveIndicator(),
            ]),
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

  Widget _buildLiveIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Row(children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isLive ? AppTheme.successGreen : AppTheme.textMuted,
            boxShadow: _isLive
                ? [
                    BoxShadow(
                      color: AppTheme.successGreen
                          .withValues(alpha: _pulseController.value * 0.7),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _isLive ? 'LIVE' : 'OFFLINE',
          style: TextStyle(
            color: _isLive ? AppTheme.successGreen : AppTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ]),
    );
  }

  Widget _buildIncidentTile(Map<String, dynamic> incident) {
    final status = incident['status'] as String? ?? 'unknown';
    final severity = incident['severity'] as String? ?? 'info';
    final id = incident['id'] as String? ?? '';
    final isLivePush = incident['_live'] == true;
    final isActive =
        status == 'active' || status == 'pending' || status == 'escalated';
    final isEscalated = status == 'escalated';
    final responders = incident['responders'] as List?;
    final responderEta = incident['responderEta'] as String?;

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
      case 'escalated':
        statusColor = const Color(0xFFFF6B35);
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
          color: isEscalated
              ? const Color(0xFFFF6B35).withValues(alpha: 0.5)
              : isActive
                  ? severityColor.withValues(alpha: 0.4)
                  : AppTheme.borderDefault,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (isEscalated
                          ? const Color(0xFFFF6B35)
                          : severityColor)
                      .withValues(alpha: 0.12),
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
                if (isLivePush) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: AppTheme.successGreen,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                  ),
                ],
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
                  child: Text(
                      status == 'escalated'
                          ? 'ESCALATED'
                          : status.replaceAll('_', ' ').toUpperCase(),
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
          // Responder dispatch banner
          if (isEscalated && responders != null && responders.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.siren,
                    color: Color(0xFFFF6B35), size: 13),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${responders.join(', ')} dispatched${responderEta != null ? ' • ETA $responderEta' : ''}',
                    style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],
          if (isActive && id.isNotEmpty && !id.startsWith('LIVE-')) ...[
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
              style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 14, height: 1.5)),
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
