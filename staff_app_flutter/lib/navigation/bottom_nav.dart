import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/duty_screen.dart';
import '../screens/alerts_screen.dart';

class BottomNavScaffold extends StatefulWidget {
  const BottomNavScaffold({super.key});

  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _sosActive = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const HomeScreen(), // SOS placeholder — index 2 never rendered, SOS sheet opens instead
    const AlertsScreen(),
    const DutyScreen(),
  ];

  void _triggerSOS() {
    setState(() => _sosActive = !_sosActive);
    if (_sosActive) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _buildSOSSheet(),
      ).then((_) => setState(() => _sosActive = false));
    }
  }

  Widget _buildSOSSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(top: BorderSide(color: AppTheme.criticalRed, width: 3)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.criticalGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.criticalRed.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(LucideIcons.alertOctagon,
                color: AppTheme.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'EMERGENCY SOS',
            style: TextStyle(
              color: AppTheme.criticalRed,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This will alert all nearby responders\nand escalate to central command.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                _buildSOSOption(LucideIcons.flame, 'Fire Emergency', AppTheme.criticalRed),
                const SizedBox(height: 12),
                _buildSOSOption(LucideIcons.heartPulse, 'Medical Emergency', AppTheme.warningAmber),
                const SizedBox(height: 12),
                _buildSOSOption(LucideIcons.shield, 'Security Threat', AppTheme.infoBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSOSEvent(String type) async {
    Navigator.pop(context);
    final zoneMap = {'fire': 'kitchen-alpha', 'medical': 'lobby', 'security': 'lobby'};
    final zoneNameMap = {'fire': 'Kitchen Alpha', 'medical': 'Lobby', 'security': 'Lobby'};
    try {
      await http.post(
        Uri.parse('http://localhost:8080/mock/hardware-event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sensorId': 'STAFF-SOS-${DateTime.now().millisecondsSinceEpoch}',
          'zone': zoneNameMap[type] ?? 'Unknown',
          'zoneId': zoneMap[type] ?? 'lobby',
          'type': type,
          'description': 'Staff SOS triggered manually — $type emergency',
          'confidence': 0.95,
        }),
      );
    } catch (_) {}
  }

  Widget _buildSOSOption(IconData icon, String label, Color color) {
    final typeMap = {'Fire Emergency': 'fire', 'Medical Emergency': 'medical', 'Security Threat': 'security'};
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _triggerSOSEvent(typeMap[label] ?? 'security'),
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Icon(LucideIcons.chevronRight, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: _screens[_currentIndex],
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 30),
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.criticalGradient,
          border: Border.all(color: AppTheme.bgPrimary, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppTheme.sosRed.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _triggerSOS,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(LucideIcons.alertOctagon,
              color: AppTheme.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgSecondary,
          border: Border(top: BorderSide(color: AppTheme.borderDefault, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index != 2) setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.accentCyan,
          unselectedItemColor: AppTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.layoutDashboard), label: 'Command'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.map), label: 'Map'),
            BottomNavigationBarItem(
                icon: SizedBox.shrink(), label: 'SOS'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.bell), label: 'Alerts'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.shield), label: 'Status'),
          ],
        ),
      ),
    );
  }
}
