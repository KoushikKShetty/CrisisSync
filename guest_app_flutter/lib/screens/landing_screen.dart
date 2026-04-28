import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'chat_screen.dart';
import 'expired_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'Validating QR code...';
  bool _loading = true;
  bool _error = false;
  String _errorTitle = '';
  String _errorMsg = '';

  late AnimationController _pulse;

  static const String _backendUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Small delay to let Flutter web read URL
    Future.delayed(const Duration(milliseconds: 200), _validateToken);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String? _getUrlParam(String key) {
    // Works in Flutter Web — reads from window.location.href
    try {
      final uri = Uri.base;
      return uri.queryParameters[key];
    } catch (_) {
      return null;
    }
  }

  Future<void> _validateToken() async {
    final token = _getUrlParam('token');
    final zone = _getUrlParam('zone') ?? 'Unknown Zone';

    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
        _errorTitle = 'Invalid QR Code';
        _errorMsg =
            'No session token found. Please re-scan the QR code at the nearest information point.';
      });
      return;
    }

    // ── Step 1: Get GPS BEFORE token verification ──────────────────
    setState(() => _status = '📍 Verifying your location...');
    final gpsResult = await _getGpsLocation();

    if (gpsResult['blocked'] == true) {
      setState(() {
        _loading = false;
        _error = true;
        _errorTitle = gpsResult['title'] as String;
        _errorMsg = gpsResult['message'] as String;
      });
      return;
    }

    // ── Step 2: Verify token + location together ────────────────────
    setState(() => _status = '🔐 Establishing secure session...');

    try {
      final body = <String, dynamic>{'token': token};
      if (gpsResult['lat'] != null) {
        body['lat'] = gpsResult['lat'];
        body['lng'] = gpsResult['lng'];
      }

      final res = await http.post(
        Uri.parse('$_backendUrl/guest/verify-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        final sessionToken = data['sessionToken'] as String;
        final zoneName = data['zoneName'] as String? ?? zone;
        final zoneId = data['zoneId'] as String? ?? 'lobby';
        final locationStatus = data['locationStatus'] as String? ?? 'verified';
        _goToChat(sessionToken, zoneName, zoneId, locationStatus);
      } else {
        final errCode = data['error'] as String? ?? 'ERROR';
        String title = 'Access Denied';
        String msg = data['message'] as String? ?? 'Unable to start session.';
        if (errCode == 'SESSION_ALREADY_USED') {
          title = 'Session Already Used';
          msg = 'This QR code has already been scanned. Each QR code is single-use. Please re-scan the physical QR code.';
        } else if (errCode == 'TOKEN_EXPIRED_OR_INVALID') {
          title = 'QR Code Expired';
          msg = 'This QR code has expired (valid 15 minutes). Please re-scan the QR code at the information point.';
        } else if (errCode == 'OUTSIDE_PROPERTY') {
          title = '📍 Not Inside Hotel';
          msg = 'This service is only available to guests inside ${zone.isEmpty ? 'the hotel' : zone}. Please scan the QR code from within the property.';
        } else if (errCode == 'LOCATION_REQUIRED') {
          title = '📍 Location Required';
          msg = 'Location access is required to use this service. Please enable location permissions and re-scan the QR code.';
        }
        setState(() {
          _loading = false;
          _error = true;
          _errorTitle = title;
          _errorMsg = msg;
        });
      }
    } catch (e) {
      // Backend unreachable — demo mode
      _startDemoSession(zone);
    }
  }

  /// Get GPS location. Returns a map with lat/lng, or blocked=true with title/message.
  Future<Map<String, dynamic>> _getGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'blocked': true,
          'title': '📍 Location Service Off',
          'message':
              'Please enable location services on your device and re-scan the QR code. '
              'This service is only available to guests physically inside the hotel.',
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return {
          'blocked': true,
          'title': '📍 Location Permission Required',
          'message':
              'CrisisSync needs your location to confirm you are inside the hotel. '
              'Please grant location permission in your browser/device settings and re-scan.',
        };
      }

      setState(() => _status = '📡 Getting GPS coordinates...');
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10)));

      return {'blocked': false, 'lat': pos.latitude, 'lng': pos.longitude};
    } catch (_) {
      // GPS timed out or unavailable — let backend decide
      return {'blocked': false, 'lat': null, 'lng': null};
    }
  }

  void _goToChat(
      String sessionToken, String zoneName, String zoneId, String locationStatus) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sessionToken: sessionToken,
          zoneName: zoneName,
          zoneId: zoneId,
          locationStatus: locationStatus,
          backendUrl: _backendUrl,
        ),
      ),
    );
  }

  void _startDemoSession(String zone) {
    // Demo mode when backend is offline
    _goToChat('demo_session_${DateTime.now().millisecondsSinceEpoch}',
        zone.isEmpty ? 'Grand Lobby' : zone, 'lobby', 'unavailable');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error ? _buildError() : _buildLoading(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                const Color(0xFF0891B2).withValues(alpha: 0.1),
                const Color(0xFF0891B2).withValues(alpha: 0.25),
                _pulse.value,
              ),
              border: Border.all(
                  color: const Color(0xFF0891B2).withValues(alpha: 0.6),
                  width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0891B2)
                      .withValues(alpha: _pulse.value * 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.shield, color: Color(0xFF22D3EE), size: 40),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          '⚡ CrisisSync',
          style: TextStyle(
            color: Color(0xFFF1F5F9),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Guest Emergency Portal',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 40),
        const CircularProgressIndicator(
          color: Color(0xFF0891B2),
          strokeWidth: 2,
        ),
        const SizedBox(height: 20),
        Text(
          _status,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
          ),
          child:
              const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 40),
        ),
        const SizedBox(height: 28),
        Text(
          _errorTitle,
          style: const TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _errorMsg,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A3548)),
          ),
          child: const Row(
            children: [
              Icon(Icons.phone, color: Color(0xFF64748B), size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'For immediate help, contact the front desk or dial the emergency number posted in your room.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
