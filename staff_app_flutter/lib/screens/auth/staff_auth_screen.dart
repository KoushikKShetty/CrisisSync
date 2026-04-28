import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../navigation/bottom_nav.dart';
import '_auth_widgets.dart';

class StaffAuthScreen extends StatefulWidget {
  const StaffAuthScreen({super.key});

  @override
  State<StaffAuthScreen> createState() => _StaffAuthScreenState();
}

class _StaffAuthScreenState extends State<StaffAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign Up controllers
  final _orgCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();

  // Sign In
  final _signInEmailCtrl = TextEditingController();
  final _signInPasswordCtrl = TextEditingController();

  // State
  bool _loading = false;
  bool _lookingUpOrg = false;
  bool _showSignUpPass = false;
  bool _showSignInPass = false;
  String? _errorMsg;

  // Org lookup result
  Map<String, dynamic>? _foundOrg;
  String _selectedRole = 'Security';

  static const List<String> _staffRoles = [
    'Security',
    'Medical',
    'Maintenance',
    'Front Desk',
    'Manager',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _errorMsg = null));

    _orgCodeCtrl.addListener(_onOrgCodeChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orgCodeCtrl.removeListener(_onOrgCodeChanged);
    _orgCodeCtrl.dispose();
    _nameCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _signInEmailCtrl.dispose();
    _signInPasswordCtrl.dispose();
    super.dispose();
  }

  // Auto-lookup when 6 chars are entered
  void _onOrgCodeChanged() {
    final code = _orgCodeCtrl.text.trim().toUpperCase();
    if (code.length == 6 && _foundOrg == null) {
      _lookupOrg(code);
    } else if (code.length < 6) {
      setState(() { _foundOrg = null; _errorMsg = null; });
    }
  }

  Future<void> _lookupOrg(String code) async {
    setState(() { _lookingUpOrg = true; _errorMsg = null; _foundOrg = null; });
    try {
      final org = await AuthService.lookupOrg(code);
      setState(() { _lookingUpOrg = false; _foundOrg = org; });
    } catch (e) {
      setState(() {
        _lookingUpOrg = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _signUp() async {
    if (_foundOrg == null) {
      setState(() => _errorMsg = 'Please enter a valid Org Code first.');
      return;
    }
    if (_nameCtrl.text.isEmpty ||
        _signUpEmailCtrl.text.isEmpty ||
        _signUpPasswordCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await AuthService.registerStaff(
        orgCode: _orgCodeCtrl.text.trim().toUpperCase(),
        name: _nameCtrl.text.trim(),
        staffRole: _selectedRole,
        email: _signUpEmailCtrl.text.trim(),
        password: _signUpPasswordCtrl.text,
      );
      // Auto login
      await AuthService.loginStaff(
        email: _signUpEmailCtrl.text.trim(),
        password: _signUpPasswordCtrl.text,
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

  Future<void> _signIn() async {
    if (_signInEmailCtrl.text.isEmpty || _signInPasswordCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Please enter email and password.');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await AuthService.loginStaff(
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
                          color: AppTheme.successGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.successGreen.withOpacity(0.3)),
                        ),
                        child: const Text('STAFF',
                            style: TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                      ),
                      const SizedBox(width: 12),
                      const Text('Staff Member',
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
                      color: AppTheme.successGreen,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Join Organization'),
                      Tab(text: 'Sign In'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_errorMsg != null)
                  ErrorBanner(message: _errorMsg!),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildJoinForm(),
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

  Widget _buildJoinForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'STEP 1 — ENTER ORG CODE'),
          const SizedBox(height: 12),
          // Org code field
          TextField(
            controller: _orgCodeCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 24,
                letterSpacing: 10,
              ),
              filled: true,
              fillColor: AppTheme.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _foundOrg != null
                      ? AppTheme.successGreen.withOpacity(0.5)
                      : AppTheme.borderDefault,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.successGreen),
              ),
              suffix: _lookingUpOrg
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.accentCyan))
                  : _foundOrg != null
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppTheme.successGreen, size: 22)
                      : null,
            ),
          ),
          // Org info card
          if (_foundOrg != null) ...[
            const SizedBox(height: 12),
            _OrgInfoCard(org: _foundOrg!),
          ],
          const SizedBox(height: 24),
          const SectionLabel(label: 'STEP 2 — YOUR DETAILS'),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _nameCtrl,
            label: 'Full Name',
            hint: 'e.g. Marcus Chen',
            icon: Icons.person_rounded,
            iconColor: AppTheme.successGreen,
          ),
          const SizedBox(height: 14),
          // Role dropdown
          _RoleDropdown(
            value: _selectedRole,
            roles: _staffRoles,
            onChanged: (val) => setState(() => _selectedRole = val!),
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _signUpEmailCtrl,
            label: 'Email Address',
            hint: 'you@hotel.com',
            icon: Icons.email_rounded,
            iconColor: AppTheme.successGreen,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _signUpPasswordCtrl,
            label: 'Password',
            hint: 'Min. 6 characters',
            icon: Icons.lock_rounded,
            iconColor: AppTheme.successGreen,
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
            label: 'Join & Create Account',
            icon: Icons.shield_rounded,
            color: AppTheme.successGreen,
            loading: _loading,
            onTap: _signUp,
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
          const SectionLabel(label: 'STAFF SIGN IN'),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _signInEmailCtrl,
            label: 'Email Address',
            hint: 'you@hotel.com',
            icon: Icons.email_rounded,
            iconColor: AppTheme.successGreen,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _signInPasswordCtrl,
            label: 'Password',
            hint: 'Your password',
            icon: Icons.lock_rounded,
            iconColor: AppTheme.successGreen,
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
            color: AppTheme.successGreen,
            loading: _loading,
            onTap: _signIn,
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _OrgInfoCard extends StatelessWidget {
  final Map<String, dynamic> org;
  const _OrgInfoCard({required this.org});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successGreenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded,
              color: AppTheme.successGreen, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  org['orgName'] ?? '',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  org['location'] ?? '',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('VERIFIED',
                style: TextStyle(
                    color: AppTheme.successGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final String value;
  final List<String> roles;
  final ValueChanged<String?> onChanged;

  const _RoleDropdown({
    required this.value,
    required this.roles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textMuted),
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500),
          hint: const Row(
            children: [
              Icon(Icons.work_rounded,
                  color: AppTheme.successGreen, size: 20),
              SizedBox(width: 12),
              Text('Select Department',
                  style: TextStyle(color: AppTheme.textMuted)),
            ],
          ),
          items: roles
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Row(
                      children: [
                        Icon(_roleIcon(r),
                            color: AppTheme.successGreen, size: 20),
                        const SizedBox(width: 12),
                        Text(r),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'Security':
        return Icons.shield_rounded;
      case 'Medical':
        return Icons.medical_services_rounded;
      case 'Maintenance':
        return Icons.build_rounded;
      case 'Front Desk':
        return Icons.hotel_rounded;
      case 'Manager':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}
