import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../navigation/bottom_nav.dart';
import '_auth_widgets.dart';

class OrgAuthScreen extends StatefulWidget {
  const OrgAuthScreen({super.key});

  @override
  State<OrgAuthScreen> createState() => _OrgAuthScreenState();
}

class _OrgAuthScreenState extends State<OrgAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign Up controllers
  final _orgNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();

  // Sign In controllers
  final _signInEmailCtrl = TextEditingController();
  final _signInPasswordCtrl = TextEditingController();

  bool _loading = false;
  bool _showSignUpPass = false;
  bool _showSignInPass = false;
  String? _errorMsg;

  // After org registration, show the org code
  String? _createdOrgCode;
  String? _createdOrgName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _errorMsg = null));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orgNameCtrl.dispose();
    _locationCtrl.dispose();
    _adminNameCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _signInEmailCtrl.dispose();
    _signInPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_orgNameCtrl.text.isEmpty ||
        _locationCtrl.text.isEmpty ||
        _adminNameCtrl.text.isEmpty ||
        _signUpEmailCtrl.text.isEmpty ||
        _signUpPasswordCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final result = await AuthService.registerOrg(
        orgName: _orgNameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        adminName: _adminNameCtrl.text.trim(),
        email: _signUpEmailCtrl.text.trim(),
        password: _signUpPasswordCtrl.text,
      );
      setState(() {
        _loading = false;
        _createdOrgCode = result['orgCode'];
        _createdOrgName = _orgNameCtrl.text.trim();
      });
    } catch (e) {
      setState(() { _loading = false; _errorMsg = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _signIn() async {
    if (_signInEmailCtrl.text.isEmpty || _signInPasswordCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Please enter email and password.');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await AuthService.loginOrg(
        email: _signInEmailCtrl.text.trim(),
        password: _signInPasswordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const BottomNavScaffold(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() { _loading = false; _errorMsg = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdOrgCode != null) {
      return _OrgCodeSuccessScreen(
        orgName: _createdOrgName!,
        orgCode: _createdOrgCode!,
        onContinue: () => Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const BottomNavScaffold(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
          (route) => false,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Stack(
        children: [
          CustomPaint(
            painter: AuthGridPainter(),
            size: MediaQuery.of(context).size,
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                        ),
                        child: const Text('ADMIN',
                            style: TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                      ),
                      const SizedBox(width: 12),
                      const Text('Organization',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                // Tab bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderDefault),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0891B2), Color(0xFF06B6D4)]),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Register Org'),
                      Tab(text: 'Sign In'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Error
                if (_errorMsg != null)
                  ErrorBanner(message: _errorMsg!),
                // Forms
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSignUpForm(),
                      _buildSignInForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'ORGANIZATION DETAILS'),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _orgNameCtrl,
            label: 'Organization Name',
            hint: 'e.g. Grand Thalassa Hotel',
            icon: Icons.business_rounded,
            iconColor: AppTheme.accentCyan,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _locationCtrl,
            label: 'Location / City',
            hint: 'e.g. Mumbai, India',
            icon: Icons.location_on_rounded,
            iconColor: AppTheme.accentCyan,
          ),
          const SizedBox(height: 24),
          const SectionLabel(label: 'ADMIN ACCOUNT'),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _adminNameCtrl,
            label: 'Your Full Name',
            hint: 'e.g. John Smith',
            icon: Icons.person_rounded,
            iconColor: AppTheme.accentCyan,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _signUpEmailCtrl,
            label: 'Email Address',
            hint: 'admin@yourhotel.com',
            icon: Icons.email_rounded,
            iconColor: AppTheme.accentCyan,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _signUpPasswordCtrl,
            label: 'Password',
            hint: 'Min. 6 characters',
            icon: Icons.lock_rounded,
            iconColor: AppTheme.accentCyan,
            obscure: !_showSignUpPass,
            suffix: IconButton(
              icon: Icon(
                _showSignUpPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _showSignUpPass = !_showSignUpPass),
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Register Organization',
            icon: Icons.rocket_launch_rounded,
            color: AppTheme.accentCyan,
            loading: _loading,
            onTap: _signUp,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.accentCyan.withOpacity(0.7), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'After registration you\'ll get a 6-character Org Code to share with your staff.',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSignInForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'ADMIN SIGN IN'),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _signInEmailCtrl,
            label: 'Email Address',
            hint: 'admin@yourhotel.com',
            icon: Icons.email_rounded,
            iconColor: AppTheme.accentCyan,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _signInPasswordCtrl,
            label: 'Password',
            hint: 'Your password',
            icon: Icons.lock_rounded,
            iconColor: AppTheme.accentCyan,
            obscure: !_showSignInPass,
            suffix: IconButton(
              icon: Icon(
                _showSignInPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _showSignInPass = !_showSignInPass),
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Sign In',
            icon: Icons.login_rounded,
            color: AppTheme.accentCyan,
            loading: _loading,
            onTap: _signIn,
          ),
        ],
      ),
    );
  }
}

// ─── Success Screen — show org code ───────────────────────────────────────────

class _OrgCodeSuccessScreen extends StatelessWidget {
  final String orgName;
  final String orgCode;
  final VoidCallback onContinue;

  const _OrgCodeSuccessScreen({
    required this.orgName,
    required this.orgCode,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.successGreenBg,
                  border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppTheme.successGreen, size: 48),
              ),
              const SizedBox(height: 28),
              const Text('Organization Created!',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                orgName,
                style: const TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 40),
              // Org Code display
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppTheme.bgCard,
                  border: Border.all(
                      color: AppTheme.accentCyan.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('YOUR ORG CODE',
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Text(
                      orgCode,
                      style: const TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: orgCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Org Code copied!'),
                            backgroundColor: AppTheme.accentCyan,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.accentCyan.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                color: AppTheme.accentCyan, size: 16),
                            SizedBox(width: 6),
                            Text('Copy Code',
                                style: TextStyle(
                                    color: AppTheme.accentCyan,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmberBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.warningAmber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppTheme.warningAmber, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Share this code with your staff. They\'ll use it to join your organization.',
                        style: TextStyle(
                            color: AppTheme.warningAmber,
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Continue to Dashboard',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
