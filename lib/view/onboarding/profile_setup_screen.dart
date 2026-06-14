import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/activity_viewmodel.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _dobFocus = FocusNode();
  final _genderFocus = FocusNode();
  final _heightFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _ageFocus = FocusNode();

  bool _isFirstNameFocused = false;
  bool _isLastNameFocused = false;
  bool _isDobFocused = false;
  bool _isGenderFocused = false;
  bool _isHeightFocused = false;
  bool _isWeightFocused = false;
  bool _isAgeFocused = false;

  @override
  void initState() {
    super.initState();
    _firstNameFocus.addListener(() => setState(() => _isFirstNameFocused = _firstNameFocus.hasFocus));
    _lastNameFocus.addListener(() => setState(() => _isLastNameFocused = _lastNameFocus.hasFocus));
    _dobFocus.addListener(() => setState(() => _isDobFocused = _dobFocus.hasFocus));
    _genderFocus.addListener(() => setState(() => _isGenderFocused = _genderFocus.hasFocus));
    _heightFocus.addListener(() => setState(() => _isHeightFocused = _heightFocus.hasFocus));
    _weightFocus.addListener(() => setState(() => _isWeightFocused = _weightFocus.hasFocus));
    _ageFocus.addListener(() => setState(() => _isAgeFocused = _ageFocus.hasFocus));
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _dobFocus.dispose();
    _genderFocus.dispose();
    _heightFocus.dispose();
    _weightFocus.dispose();
    _ageFocus.dispose();
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
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final String formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      _dobController.text = formatted;
      
      // Calculate age
      final today = DateTime.now();
      int age = today.year - picked.year;
      if (today.month < picked.month || (today.month == picked.month && today.day < picked.day)) {
        age--;
      }
      _ageController.text = age.toString();
      setState(() {});
    }
  }

  Future<void> _selectGender() async {
    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          backgroundColor: const Color(0xFF0D0E0F),
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.white24),
          ),
          title: Text(
            'SELECT GENDER',
            style: GoogleFonts.bebasNeue(
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () { Navigator.pop(context, 'MALE'); },
              child: Text('MALE', style: GoogleFonts.inter(color: Colors.white)),
            ),
            SimpleDialogOption(
              onPressed: () { Navigator.pop(context, 'FEMALE'); },
              child: Text('FEMALE', style: GoogleFonts.inter(color: Colors.white)),
            ),
            SimpleDialogOption(
              onPressed: () { Navigator.pop(context, 'OTHER'); },
              child: Text('OTHER', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (selected != null) {
      _genderController.text = selected;
      setState(() {});
    }
  }

  Widget _buildBentoCard({
    required String label,
    required IconData icon,
    required String placeholder,
    required String unit,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    TextInputType keyboardType = TextInputType.number,
    bool readOnly = false,
    VoidCallback? onTap,
    double fontSize = 40,
    bool useBebas = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isFocused ? const Color(0xFF0D0E0F) : Colors.black,
          border: Border.all(
            color: isFocused ? Colors.white : Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: Colors.white60,
                  ),
                ),
                Icon(icon, color: Colors.white54, size: 18),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    readOnly: readOnly,
                    onTap: onTap,
                    style: useBebas 
                      ? GoogleFonts.bebasNeue(
                          fontSize: fontSize,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        )
                      : GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: useBebas
                        ? GoogleFonts.bebasNeue(
                            fontSize: fontSize,
                            color: Colors.white24,
                          )
                        : GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white24,
                          ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix texture background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'DRGODLY',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 24,
                            letterSpacing: 3.0,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main form content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 80.0, bottom: 160.0, left: 24.0, right: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Section
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.white, width: 2.0),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PATIENT PROFILE',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 36,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'CLINICAL_INTAKE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 1. Name Row (First Name, Last Name)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildBentoCard(
                            label: 'FIRST NAME',
                            icon: Icons.person_outline,
                            placeholder: 'First Name',
                            unit: '',
                            controller: _firstNameController,
                            focusNode: _firstNameFocus,
                            isFocused: _isFirstNameFocused,
                            keyboardType: TextInputType.text,
                            useBebas: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildBentoCard(
                            label: 'LAST NAME',
                            icon: Icons.person_outline,
                            placeholder: 'Last Name',
                            unit: '',
                            controller: _lastNameController,
                            focusNode: _lastNameFocus,
                            isFocused: _isLastNameFocused,
                            keyboardType: TextInputType.text,
                            useBebas: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Details Row (Date of Birth, Gender)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildBentoCard(
                            label: 'DATE OF BIRTH',
                            icon: Icons.cake_outlined,
                            placeholder: 'YYYY-MM-DD',
                            unit: '',
                            controller: _dobController,
                            focusNode: _dobFocus,
                            isFocused: _isDobFocused,
                            readOnly: true,
                            onTap: _selectDateOfBirth,
                            useBebas: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildBentoCard(
                            label: 'GENDER',
                            icon: Icons.wc_outlined,
                            placeholder: 'Select',
                            unit: '',
                            controller: _genderController,
                            focusNode: _genderFocus,
                            isFocused: _isGenderFocused,
                            readOnly: true,
                            onTap: _selectGender,
                            useBebas: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Height & Weight Row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildBentoCard(
                            label: 'HEIGHT',
                            icon: Icons.straighten,
                            placeholder: '000',
                            unit: 'CM',
                            controller: _heightController,
                            focusNode: _heightFocus,
                            isFocused: _isHeightFocused,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildBentoCard(
                            label: 'WEIGHT',
                            icon: Icons.monitor_weight_outlined,
                            placeholder: '00.0',
                            unit: 'KG',
                            controller: _weightController,
                            focusNode: _weightFocus,
                            isFocused: _isWeightFocused,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Age Row
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: _buildBentoCard(
                      label: 'AGE',
                      icon: Icons.calendar_today_outlined,
                      placeholder: '00',
                      unit: 'YRS',
                      controller: _ageController,
                      focusNode: _ageFocus,
                      isFocused: _isAgeFocused,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Encryption note
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SYSTEM ENCRYPTION ACTIVE // END-TO-END SECURE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black.withValues(alpha: 0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    onPressed: () async {
                      final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
                      final activityVM = Provider.of<ActivityViewModel>(context, listen: false);
                      final double height = double.tryParse(_heightController.text) ?? 175.0;
                      final double weight = double.tryParse(_weightController.text) ?? 70.0;
                      final double age = double.tryParse(_ageController.text) ?? 25.0;
                      
                      final String firstName = _firstNameController.text.trim();
                      final String lastName = _lastNameController.text.trim();
                      final String dob = _dobController.text.trim();
                      final String gender = _genderController.text.trim();

                      // 1. Save local physical vitals
                      await activityVM.saveBioData(weight: weight, height: height, age: age);
                      
                      // 2. Sync demographics safely to the local/remote FHIR server
                      if (firstName.isNotEmpty || lastName.isNotEmpty || dob.isNotEmpty || gender.isNotEmpty) {
                        try {
                          await profileVM.saveProfileDetails(
                            givenName: firstName,
                            familyName: lastName,
                            gender: gender,
                            birthDate: dob,
                            email: "",
                            phone: "",
                            street: "",
                            city: "",
                            state: "",
                            zip: "",
                            country: "",
                          );
                        } catch (e) {
                          if (kDebugMode) {
                            print('[ProfileSetupScreen] FHIR profile sync swallowed: $e');
                          }
                        }
                      }
                      
                      if (mounted) {
                        Navigator.pushNamed(context, '/goals');
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NEXT',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.0,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'DRGODLY_PATIENT_V1.0.0',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
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
