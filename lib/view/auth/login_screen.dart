import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() => _isEmailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _isPasswordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(Icons.bolt, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'PHIA',
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
                      'PERFORMANCE INSTRUMENT V2.0',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white60,
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),

                  // Login Form Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            hintText: 'USER@PHIA.SYS',
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

                      // Action Login Button
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
                        onPressed: () {
                          Navigator.pushNamed(context, '/welcome');
                        },
                        child: Text(
                          'LOGIN',
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
                        'NEW OPERATOR?  ',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          'CREATE ACCOUNT',
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
                        const SizedBox(height: 24),
                        Text(
                          'System encryption active: AES-256-GCM\nBuild ID: PHIA-8822-PROD',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: Colors.white24,
                            height: 1.4,
                          ),
                        ),
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
