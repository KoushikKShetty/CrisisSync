import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

// ─── BLE ZONE MODEL ───────────────────────────────────────────────
class BleZone {
  final String id;
  final String name;
  final LatLng center;
  final double radiusMeters;
  final Color color;
  bool hasAlert;

  BleZone({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusMeters,
    required this.color,
    this.hasAlert = false,
  });
}

// ─── STAFF MODEL ──────────────────────────────────────────────────
class StaffMember {
  final String id;
  final String name;
  final String role;
  final String avatar;
  String zoneId;
  String status;
  LatLng position;

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.zoneId,
    required this.status,
    required this.position,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _bleSimTimer;

  // Hotel center — Bangalore example (update to real hotel coords)
  static const LatLng _hotelCenter = LatLng(12.9716, 77.5946);

  // ─── BLE ZONES ───────────────────────────────────────────────────
  final List<BleZone> _zones = [
    BleZone(id: 'lobby', name: 'Main Lobby',
        center: LatLng(12.9718, 77.5944), radiusMeters: 30,
        color: AppTheme.successGreen),
    BleZone(id: 'kitchen-alpha', name: 'Kitchen Alpha',
        center: LatLng(12.9714, 77.5950), radiusMeters: 25,
        color: AppTheme.criticalRed, hasAlert: true),
    BleZone(id: 'pool', name: 'Pool Area',
        center: LatLng(12.9720, 77.5942), radiusMeters: 40,
        color: AppTheme.infoBlue),
    BleZone(id: 'parking', name: 'Parking B',
        center: LatLng(12.9712, 77.5945), radiusMeters: 35,
        color: AppTheme.warningAmber),
    BleZone(id: 'restaurant', name: 'Restaurant',
        center: LatLng(12.9716, 77.5952), radiusMeters: 20,
        color: Color(0xFFA855F7)),
  ];

  late List<StaffMember> _staff;

  @override
  void initState() {
    super.initState();
    _staff = [
      StaffMember(id: 'mc', name: 'Marcus Chen', role: 'Security Lead',
          avatar: 'MC', zoneId: 'kitchen-alpha', status: 'en_route',
          position: LatLng(12.9714, 77.5949)),
      StaffMember(id: 'sm', name: 'Sarah Miller', role: 'Medic',
          avatar: 'SM', zoneId: 'lobby', status: 'available',
          position: LatLng(12.9718, 77.5943)),
      StaffMember(id: 'dp', name: 'David Park', role: 'Fire Safety',
          avatar: 'DP', zoneId: 'kitchen-alpha', status: 'deployed',
          position: LatLng(12.9715, 77.5951)),
      StaffMember(id: 'lt', name: 'Lisa Tran', role: 'Maintenance',
          avatar: 'LT', zoneId: 'pool', status: 'standby',
          position: LatLng(12.9721, 77.5942)),
    ];

    // BLE simulation: update positions every 4 seconds
    _bleSimTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final rng = Random();
      setState(() {
        for (final s in _staff) {
          if (s.status == 'en_route' || s.status == 'deployed') {
            s.position = LatLng(
              s.position.latitude + (rng.nextDouble() - 0.5) * 0.00005,
              s.position.longitude + (rng.nextDouble() - 0.5) * 0.00005,
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _bleSimTimer?.cancel();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available': return AppTheme.successGreen;
      case 'en_route':  return AppTheme.warningAmber;
      case 'deployed':  return AppTheme.infoBlue;
      default:          return AppTheme.textMuted;
    }
  }

  String _zoneName(String zoneId) =>
      _zones.firstWhere((z) => z.id == zoneId,
          orElse: () => _zones.first).name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            flex: 6,
            child: Stack(children: [
              // ── OpenStreetMap via flutter_map ──────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _hotelCenter,
                  initialZoom: 18.5,
                  minZoom: 15,
                  maxZoom: 22,
                ),
                children: [
                  // Base tile layer (OpenStreetMap — free, no key)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.crisisync.staff',
                  ),
                  // BLE zone circles
                  CircleLayer(
                    circles: _zones.map((z) => CircleMarker(
                      point: z.center,
                      radius: z.radiusMeters,
                      useRadiusInMeter: true,
                      color: z.color.withValues(alpha: z.hasAlert ? 0.25 : 0.12),
                      borderColor: z.color.withValues(alpha: z.hasAlert ? 0.9 : 0.5),
                      borderStrokeWidth: z.hasAlert ? 3 : 1.5,
                    )).toList(),
                  ),
                  // Zone label markers
                  MarkerLayer(
                    markers: _zones.map((z) => Marker(
                      point: z.center,
                      width: 100,
                      height: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: z.color.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (z.hasAlert)
                              const Icon(LucideIcons.alertTriangle,
                                  color: Colors.white, size: 10),
                            if (z.hasAlert) const SizedBox(width: 3),
                            Flexible(
                              child: Text(z.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                  // Staff position markers (BLE-updated)
                  MarkerLayer(
                    markers: _staff.map((s) {
                      final color = _statusColor(s.status);
                      return Marker(
                        point: s.position,
                        width: 40,
                        height: 50,
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8)
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(s.avatar,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Icon(LucideIcons.chevronDown,
                                color: color, size: 10),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              // Legend overlay
              Positioned(top: 12, right: 12, child: _buildLegend()),
              // Navigate to incident button
              Positioned(
                bottom: 16, left: 16, right: 16,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final alertZone = _zones.firstWhere(
                        (z) => z.hasAlert, orElse: () => _zones.first);
                    _mapController.move(alertZone.center, 20);
                  },
                  icon: const Icon(LucideIcons.navigation2,
                      color: AppTheme.bgPrimary, size: 18),
                  label: const Text('Navigate to Incident',
                      style: TextStyle(
                          color: AppTheme.bgPrimary,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
          // Staff BLE roster
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('BLE ZONE TRACKING',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2)),
                      Row(children: [
                        Container(width: 6, height: 6,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentCyan)),
                        const SizedBox(width: 6),
                        const Text('LIVE',
                            style: TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ]),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _staff.length,
                    itemBuilder: (_, i) => _buildStaffTile(_staff[i]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final alerts = _zones.where((z) => z.hasAlert).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(bottom: BorderSide(color: AppTheme.borderDefault)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Zone Command Map',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text('${_zones.length} zones • ${_staff.length} staff via BLE',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
          ]),
          if (alerts > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.criticalRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                    color: AppTheme.criticalRed.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.alertTriangle,
                    color: AppTheme.criticalRed, size: 14),
                const SizedBox(width: 6),
                Text('$alerts ALERT${alerts > 1 ? 'S' : ''}',
                    style: const TextStyle(
                        color: AppTheme.criticalRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BLE ZONES',
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        ..._zones.map((z) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: z.color.withValues(alpha: 0.85))),
            const SizedBox(width: 6),
            Text(z.name,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
            if (z.hasAlert) ...[
              const SizedBox(width: 4),
              const Icon(LucideIcons.alertTriangle,
                  color: AppTheme.criticalRed, size: 10),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _buildStaffTile(StaffMember s) {
    final color = _statusColor(s.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(s.avatar,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(LucideIcons.bluetooth,
                  color: AppTheme.accentCyan, size: 11),
              const SizedBox(width: 4),
              Text(_zoneName(s.zoneId),
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(s.status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 4),
          Text(s.role,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 10)),
        ]),
      ]),
    );
  }
}
