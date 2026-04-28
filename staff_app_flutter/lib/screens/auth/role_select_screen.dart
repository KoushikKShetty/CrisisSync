import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'org_auth_screen.dart';
import 'staff_auth_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _card1Controller;
  late AnimationController _card2Controller;

  late Animation<double> _headerOpacity;
  late Animation<Offset> _headerSlide;
  late Animation<double> _card1Opacity;
  late Animation<Offset> _card1Slide;
  late Animation<double> _card2Opacity;
  late Animation<Offset> _card2Slide;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _card1Controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _card2Controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _headerOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeIn));
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOut));

    _card1Opacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _card1Controller, curve: Curves.easeIn));
    _card1Slide = Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _card1Controller, curve: Curves.easeOut));

    _card2Opacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _card2Controller, curve: Curves.easeIn));
    _card2Slide = Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _card2Controller, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    _headerController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _card1Controller.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _card2Controller.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _card1Controller.dispose();
    _card2Controller.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => role == 'org_admin'
            ? const OrgAuthScreen()
            : const StaffAuthScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // Grid bg — positioned so it doesn't constrain Stack height
            Positioned.fill(
              child: CustomPaint(painter: _SubtleGridPainter()),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  // Header
                  AnimatedBuilder(
                    animation: _headerController,
                    builder: (_, child) => Opacity(
                      opacity: _headerOpacity.value,
                      child: SlideTransition(
                          position: _headerSlide, child: child),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
                                ),
                              ),
                              child: const Icon(Icons.crisis_alert_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'CrisisSync',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Welcome.\nHow are you joining?',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Select your role to get started.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Role cards
                  Column(
                    children: [
                      AnimatedBuilder(
                        animation: _card1Controller,
                        builder: (_, child) => Opacity(
                          opacity: _card1Opacity.value,
                          child: SlideTransition(
                              position: _card1Slide, child: child),
                        ),
                        child: _RoleCard(
                          icon: Icons.business_rounded,
                          iconColor: AppTheme.accentCyan,
                          gradientColors: const [
                            Color(0xFF0C2D3E),
                            Color(0xFF0D1B2A),
                          ],
                          borderColor: AppTheme.accentCyan,
                          title: 'Organization Admin',
                          subtitle: 'Register your hotel, resort, or venue.\nManage your entire team from one place.',
                          badge: 'ADMIN',
                          badgeColor: AppTheme.accentCyan,
                          features: const [
                            'Create your organization profile',
                            'Get your unique Org Code',
                            'Monitor all incidents & staff',
                          ],
                          onTap: () => _selectRole('org_admin'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _card2Controller,
                        builder: (_, child) => Opacity(
                          opacity: _card2Opacity.value,
                          child: SlideTransition(
                              position: _card2Slide, child: child),
                        ),
                        child: _RoleCard(
                          icon: Icons.shield_rounded,
                          iconColor: const Color(0xFF22C55E),
                          gradientColors: const [
                            Color(0xFF0A2318),
                            Color(0xFF0B1A13),
                          ],
                          borderColor: const Color(0xFF22C55E),
                          title: 'Staff Member',
                          subtitle: 'Join your organization using the\nOrg Code from your manager.',
                          badge: 'STAFF',
                          badgeColor: const Color(0xFF22C55E),
                          features: const [
                            'Enter your 6-character Org Code',
                            'Select your department & role',
                            'Start responding to incidents',
                          ],
                          onTap: () => _selectRole('staff'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Secure · Encrypted · Real-time',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final Color borderColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final List<String> features;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.features,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            border: Border.all(
              color: widget.borderColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.borderColor.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: widget.iconColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Icon(widget.icon,
                        color: widget.iconColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: widget.badgeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            widget.badge,
                            style: TextStyle(
                              color: widget.badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: widget.iconColor.withValues(alpha: 0.7), size: 16),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: widget.borderColor.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 14),
              ...widget.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: widget.iconColor, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        f,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtleGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
