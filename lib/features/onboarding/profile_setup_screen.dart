import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/colors.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedGender = 'MALE';
  bool _initializedFromState = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillExistingData();
    });
  }

  void _prefillExistingData() {
    if (_initializedFromState) return;
    _initializedFromState = true;

    final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
    final activityVM = Provider.of<ActivityViewModel>(context, listen: false);

    // Pre-fill Name
    final nameObj = profileVM.currentProfile?.name?.firstOrNull;
    if (nameObj != null) {
      if (nameObj.givenName.isNotEmpty) {
        _firstNameController.text = nameObj.givenName;
      }
      if (nameObj.familyName != null && nameObj.familyName!.isNotEmpty) {
        _lastNameController.text = nameObj.familyName!;
      }
    }

    // Pre-fill Gender
    final g = profileVM.currentProfile?.gender?.toUpperCase();
    if (g == 'MALE' || g == 'FEMALE' || g == 'OTHER') {
      _selectedGender = g!;
    }

    // Pre-fill DOB & Age
    final dob = profileVM.currentProfile?.birthDate;
    if (dob != null && dob.isNotEmpty) {
      _dobController.text = dob;
      final dt = DateTime.tryParse(dob);
      if (dt != null) {
        final now = DateTime.now();
        int age = now.year - dt.year;
        if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) {
          age--;
        }
        _ageController.text = age > 0 ? age.toString() : '';
      }
    } else if (activityVM.userAge > 0) {
      _ageController.text = activityVM.userAge.toString();
    }

    // Pre-fill Height & Weight
    if (activityVM.userHeight > 0) {
      _heightController.text = activityVM.userHeight.toStringAsFixed(0);
    }
    if (activityVM.userWeight > 0) {
      _weightController.text = activityVM.userWeight.toStringAsFixed(1);
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: PhiaColors.primary,
              onSurface: PhiaColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final String formatted =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      _dobController.text = formatted;

      final today = DateTime.now();
      int age = today.year - picked.year;
      if (today.month < picked.month || (today.month == picked.month && today.day < picked.day)) {
        age--;
      }
      _ageController.text = age.toString();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/app_logo.jpeg',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: PhiaColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: PhiaColors.primary, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'DrGodly',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: PhiaColors.navyAnchor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: PhiaColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: PhiaColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Step 1 of 3',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner Card
                    Container(
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PhiaColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: PhiaColors.navyAnchor,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Patient Intake Registration',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 18),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Please enter your clinical details to calibrate continuous vital tracking, BMI calculations, and doctor consultations.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: PhiaColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Demographics Card
                    _buildSectionHeader('Personal Demographics'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PhiaColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First Name & Last Name
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  label: 'First Name',
                                  hint: 'John',
                                  controller: _firstNameController,
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildInputField(
                                  label: 'Last Name',
                                  hint: 'Doe',
                                  controller: _lastNameController,
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Date of Birth & Age
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: GestureDetector(
                                  onTap: _selectDateOfBirth,
                                  child: AbsorbPointer(
                                    child: _buildInputField(
                                      label: 'Date of Birth',
                                      hint: 'YYYY-MM-DD',
                                      controller: _dobController,
                                      icon: Icons.calendar_today_rounded,
                                      readOnly: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: _buildInputField(
                                  label: 'Age',
                                  hint: 'From DOB',
                                  controller: _ageController,
                                  icon: Icons.cake_outlined,
                                  keyboardType: TextInputType.number,
                                  // Age is derived from the date of birth so the two can't disagree.
                                  readOnly: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Gender Selection
                          Text(
                            'Gender',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: PhiaColors.navyAnchor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildGenderChip('MALE', 'Male'),
                              const SizedBox(width: 10),
                              _buildGenderChip('FEMALE', 'Female'),
                              const SizedBox(width: 10),
                              _buildGenderChip('OTHER', 'Other'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Biometrics Card
                    _buildSectionHeader('Physical Biometrics'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PhiaColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  label: 'Height',
                                  hint: '175',
                                  controller: _heightController,
                                  icon: Icons.height_rounded,
                                  suffixText: 'cm',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildInputField(
                                  label: 'Weight',
                                  hint: '70',
                                  controller: _weightController,
                                  icon: Icons.monitor_weight_outlined,
                                  suffixText: 'kg',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Encryption Note
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF15803D), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your details are sent over an encrypted connection',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PhiaColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: PhiaColors.surface,
                border: const Border(top: BorderSide(color: PhiaColors.borderSubtle)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhiaColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shadowColor: PhiaColors.primary.withValues(alpha: 0.3),
                  ),
                  onPressed: _isSaving ? null : _handleContinue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue to Goals',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: PhiaColors.navyAnchor,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: PhiaColors.navyAnchor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: PhiaColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PhiaColors.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: PhiaColors.textSecondary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PhiaColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: PhiaColors.textSecondary.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffixText != null) ...[
                Text(
                  suffixText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderChip(String value, String label) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? PhiaColors.primaryLight : PhiaColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? PhiaColors.primary : PhiaColors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? PhiaColors.primary : PhiaColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Validates the form. Returns a user-facing message, or null when valid.
  /// Values are never silently replaced with defaults: a wrong height, weight
  /// or age would be synced to the medical record as if it were real.
  String? _validate({
    required String firstName,
    required DateTime? dob,
    required double? height,
    required double? weight,
  }) {
    if (firstName.isEmpty) return 'Please enter your first name.';
    if (dob == null) return 'Please select your date of birth.';
    final age = _ageFromDob(dob);
    if (age < 0 || age > 130) return 'Please check your date of birth.';
    if (height == null || height < 50 || height > 250) {
      return 'Please enter your height in cm (50–250).';
    }
    if (weight == null || weight < 2 || weight > 400) {
      return 'Please enter your weight in kg (2–400).';
    }
    return null;
  }

  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _handleContinue() async {
    final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
    final activityVM = Provider.of<ActivityViewModel>(context, listen: false);

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String dob = _dobController.text.trim();
    final String gender = _selectedGender;
    final DateTime? dobDate = DateTime.tryParse(dob);
    final double? height = double.tryParse(_heightController.text.trim());
    final double? weight = double.tryParse(_weightController.text.trim());

    final error = _validate(
      firstName: firstName,
      dob: dobDate,
      height: height,
      weight: weight,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: PhiaColors.pulseRed),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Save local physical vitals
      await activityVM.saveBioData(
        weight: weight!,
        height: height!,
        age: _ageFromDob(dobDate!).toDouble(),
      );

      // 2. Sync demographics to the FHIR server. Contact and address fields are
      // left blank on purpose: saveProfileDetails keeps the existing values.
      try {
        await profileVM.saveProfileDetails(
          givenName: firstName,
          familyName: lastName,
          gender: gender,
          birthDate: dob,
          email: '',
          phone: '',
          street: '',
          city: '',
          state: '',
          zip: '',
          country: '',
        );
      } catch (e) {
        if (kDebugMode) {
          print('[ProfileSetupScreen] FHIR profile sync error: $e');
        }
      }

      if (mounted) {
        context.push(AppRoutes.goals);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
