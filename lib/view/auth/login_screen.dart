import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';

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
      body: Stack(
        children: [
          // Dot Matrix Background Grid overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // Main scrolling layout
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  
                  // Brand Identity Title
                  const Icon(Icons.medical_services_outlined, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'DRGODLY',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 48,
                      letterSpacing: 8.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      color: const Color(0xFF0D0E0F),
                    ),
                    child: Text(
                      'PATIENT PORTAL V2.0',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white60,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Login Form Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name Field (Sign-up mode only)
                      if (!_isLoginMode) ...[
                        Text(
                          'Full Name'.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isNameFocused ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                            border: Border.all(
                              color: _isNameFocused ? Colors.white : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: TextField(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'JOHN DOE',
                              hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Identification / Email Field
                      Text(
                        'Identification / Email'.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _isEmailFocused ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                          border: Border.all(
                            color: _isEmailFocused ? Colors.white : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: TextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'USER@DRGODLY.COM',
                            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Password Field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Access Key / Password'.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                              color: Colors.white60,
                            ),
                          ),
                          if (_isLoginMode)
                            Text(
                              'Forgot?'.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white38,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _isPasswordFocused ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                          border: Border.all(
                            color: _isPasswordFocused ? Colors.white : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: true,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: '********',
                            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Error message banner
                      if (authVM.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E0C0C),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  authVM.errorMessage!.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Action Login/Signup Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 60),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          elevation: 0,
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
                                    SnackBar(
                                      content: Text('Please fill all fields'.toUpperCase()),
                                      backgroundColor: Colors.red,
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
                                      SnackBar(
                                        content: Text('Please enter your name'.toUpperCase()),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  success = await authVM.register(name, email, password);
                                }

                                if (success) {
                                  await profileVM.fetchOrInitProfile();
                                  
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
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                _isLoginMode ? 'LOGIN' : 'CREATE ACCOUNT',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 22,
                                  letterSpacing: 3.0,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Create Account Secondary CTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLoginMode ? 'NEW PATIENT?  ' : 'ALREADY A PATIENT?  ',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                            _nameController.clear();
                            _emailController.clear();
                            _passwordController.clear();
                            authVM.signOut(); // Clear previous auth state and errors
                          });
                        },
                        child: Text(
                          _isLoginMode ? 'CREATE ACCOUNT' : 'SIGN IN',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // Social Auth Footer
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      children: [
                        Text(
                          'Remote Authentication'.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'G',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.mail_outline, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
