import 'package:flutter/material.dart';

class ExpiredScreen extends StatelessWidget {
  const ExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
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
                  child: const Icon(Icons.timer_off,
                      color: Color(0xFFEF4444), size: 40),
                ),
                const SizedBox(height: 28),
                const Text(
                  '⏰ Session Expired',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'This QR session has expired after 15 minutes for your security.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                  child: const Column(
                    children: [
                      Text(
                        'What to do:',
                        style: TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '1. Re-scan the QR code at the nearest information point\n2. Ask a staff member for assistance\n3. Dial the emergency number in your room',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
