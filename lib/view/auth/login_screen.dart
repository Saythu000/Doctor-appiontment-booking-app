import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/activity_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isNameFocused = false;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() => _isNameFocused = _nameFocus.hasFocus));
    _emailFocus.addListener(() => setState(() => _isEmailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _isPasswordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Brand Icon & Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PhiaColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: PhiaColors.primary.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: PhiaColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'DrGodly',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: PhiaColors.navyAnchor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoginMode ? 'Sign in to access your health portal' : 'Create your clinical patient account',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: PhiaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Form Card (Navy Header Banner pattern matching reference)
              Container(
                decoration: BoxDecoration(
                  color: PhiaColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PhiaColors.borderSubtle, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Deep Oxford Navy Header
                    Container(
                      color: PhiaColors.navyAnchor,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isLoginMode ? 'Patient Authentication' : 'Patient Registration',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const Icon(Icons.lock_rounded, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),

                    // Card Body Form Fields
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Full Name (Registration only)
                          if (!_isLoginMode) ...[
                            _buildInputLabel('FULL NAME'),
                            const SizedBox(height: 6),
                            _buildInputField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              isFocused: _isNameFocused,
                              hintText: 'e.g. Alex Morgan',
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.name,
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Email / Identifier
                          _buildInputLabel('EMAIL ADDRESS OR PATIENT ID'),
                          const SizedBox(height: 6),
                          _buildInputField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            isFocused: _isEmailFocused,
                            hintText: 'name@example.com',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 18),

                          // Password
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInputLabel('PASSWORD'),
                              if (_isLoginMode)
                                Text(
                                  'Forgot password?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: PhiaColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: PhiaColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isPasswordFocused ? PhiaColors.primary : PhiaColors.borderSubtle,
                                width: _isPasswordFocused ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textMuted),
                                icon: const Icon(Icons.lock_outline_rounded, color: PhiaColors.primary, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: PhiaColors.textMuted,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),

                          // Error Banner
                          if (authVM.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PhiaColors.pulseRedLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: PhiaColors.pulseRed.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: PhiaColors.pulseRed, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      authVM.errorMessage!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: PhiaColors.pulseRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit Action Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PhiaColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: authVM.isLoading
                                ? null
                                : () async {
                                    final email = _emailController.text.trim();
                                    final password = _passwordController.text;
                                    final name = _nameController.text.trim();
                                    final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
                                    final navigator = Navigator.of(context);
                                    final messenger = ScaffoldMessenger.of(context);

                                    if (email.isEmpty || password.isEmpty) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Please fill all required fields'),
                                          backgroundColor: PhiaColors.pulseRed,
                                        ),
                                      );
                                      return;
                                    }

                                    bool success;
                                    if (_isLoginMode) {
                                      success = await authVM.login(email, password);
                                    } else {
                                      if (name.isEmpty) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter your full name'),
                                            backgroundColor: PhiaColors.pulseRed,
                                          ),
                                        );
                                        return;
                                      }
                                      success = await authVM.register(name, email, password);
                                    }

                                    if (success) {
                                      final activityVM = Provider.of<ActivityViewModel>(context, listen: false);
                                      activityVM.resetState();
                                      profileVM.resetState();
                                      await profileVM.fetchOrInitProfile();
                                      await activityVM.initDashboard();
                                      final profile = profileVM.currentProfile;
                                      final bool hasProfile = profile != null &&
                                          profile.name != null &&
                                          profile.name!.isNotEmpty &&
                                          profile.name!.first.givenName.isNotEmpty;

                                      if (hasProfile) {
                                        navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
                                      } else {
                                        navigator.pushNamedAndRemoveUntil('/profile_setup', (route) => false);
                                      }
                                    }
                                  },
                            child: authVM.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    _isLoginMode ? 'Sign In' : 'Create Account',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Switch Mode Toggle
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                      _nameController.clear();
                      _emailController.clear();
                      _passwordController.clear();
                      authVM.signOut();
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isLoginMode ? "Don't have an account? " : "Already registered? ",
                      style: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textSecondary),
                      children: [
                        TextSpan(
                          text: _isLoginMode ? 'Register Now' : 'Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PhiaColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: PhiaColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? PhiaColors.primary : PhiaColors.borderSubtle,
          width: isFocused ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
          icon: Icon(icon, color: PhiaColors.primary, size: 20),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
