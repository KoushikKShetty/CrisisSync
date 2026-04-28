import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class DutyScreen extends StatefulWidget {
  const DutyScreen({super.key});

  @override
  State<DutyScreen> createState() => _DutyScreenState();
}

class _DutyScreenState extends State<DutyScreen> {
  String _selectedSector = 'hotel';
  bool _isOnDuty = true;

  final List<Map<String, dynamic>> _sectors = [
    {
      'id': 'hotel',
      'name': 'Hotel',
      'icon': LucideIcons.building2,
      'zones': 'Lobby, Rooms, Pool',
      'protocols': 12,
    },
    {
      'id': 'resort',
      'name': 'Resort',
      'icon': LucideIcons.palmtree,
      'zones': 'Beach, Trails, Villas',
      'protocols': 8,
    },
    {
      'id': 'restaurant',
      'name': 'Restaurant',
      'icon': LucideIcons.chefHat,
      'zones': 'Kitchen, Dining, Bar',
      'protocols': 15,
    },
    {
      'id': 'travel',
      'name': 'Travel Hub',
      'icon': LucideIcons.plane,
      'zones': 'Terminal, Gate, Route',
      'protocols': 10,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header
              _buildProfileHeader(),
              const SizedBox(height: 20),
              // Duty Toggle
              _buildDutyToggle(),
              const SizedBox(height: 20),
              // Stats
              _buildStatCards(),
              const SizedBox(height: 24),
              // Sector Selection
              const Text('SECTOR CONFIGURATION',
                  style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('Select your active sector to load relevant protocols',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              ..._sectors.map((s) => _buildSectorTile(s)),
              const SizedBox(height: 16),
              // Apply
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusButton)),
                  elevation: 0,
                ),
                child: const Text('DEPLOY SECTOR CONFIG',
                    style: TextStyle(
                        color: AppTheme.bgPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.cyanGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('AR',
                style: TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alex Rivera',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: const Text('SECURITY LEAD',
                          style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: const Text('LEVEL 3',
                          style: TextStyle(
                              color: AppTheme.successGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyToggle() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: _isOnDuty
            ? AppTheme.successGreen.withValues(alpha: 0.08)
            : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: _isOnDuty
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : AppTheme.borderDefault,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(
              _isOnDuty ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
              color: _isOnDuty ? AppTheme.successGreen : AppTheme.textMuted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                  style: TextStyle(
                      color: _isOnDuty
                          ? AppTheme.successGreen
                          : AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(
                  _isOnDuty
                      ? 'Receiving live alerts'
                      : 'Alerts paused',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
          ]),
          Switch(
            value: _isOnDuty,
            onChanged: (v) => setState(() => _isOnDuty = v),
            activeThumbColor: AppTheme.successGreen,
            activeTrackColor: AppTheme.successGreen.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textMuted,
            inactiveTrackColor: AppTheme.bgSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(children: [
      _buildMiniStat('Shift', '8h 23m', LucideIcons.clock, AppTheme.accentCyan),
      const SizedBox(width: 10),
      _buildMiniStat(
          'Resolved', '7', LucideIcons.checkCircle2, AppTheme.successGreen),
      const SizedBox(width: 10),
      _buildMiniStat(
          'Response', '2.3m', LucideIcons.zap, AppTheme.warningAmber),
    ]);
  }

  Widget _buildMiniStat(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorTile(Map<String, dynamic> sector) {
    final isSelected = _selectedSector == sector['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedSector = sector['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentCyanBg : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : AppTheme.borderDefault,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentCyan.withValues(alpha: 0.15)
                    : AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(sector['icon'],
                  color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sector['name'],
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppTheme.accentCyan
                                  : AppTheme.textPrimary)),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: const Text('ACTIVE',
                              style: TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${sector['zones']} • ${sector['protocols']} protocols',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
