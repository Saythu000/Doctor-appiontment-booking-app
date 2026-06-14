import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../core/widgets/image_helper.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/profile_viewmodel.dart';

import '../../domain/model/patient_profile.dart';
import '../../core/utils/language_helper.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileViewModel>().fetchOrInitProfile();
    });
  }

  Future<void> _showPhotoPickerBottomSheet(BuildContext context, ProfileViewModel profileVM) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0E0F),
      shape: const Border(
        top: BorderSide(color: Colors.white12, width: 1.0),
      ),
      builder: (BuildContext sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PROFILE IMAGE SOURCE',
                style: GoogleFonts.bebasNeue(
                  fontSize: 20,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt,
                    label: 'CAMERA',
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.camera);
                      if (image != null) {
                        await profileVM.saveProfileImagePath(image.path);
                      }
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library,
                    label: 'GALLERY',
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        await profileVM.saveProfileImagePath(image.path);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'PRESET NEURAL AVATARS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final avatarPath = 'assets/avatars/avatar_${index + 1}.png';
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await profileVM.saveProfileImagePath(avatarPath);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 72,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: profileVM.profileImagePath == avatarPath
                                ? PhiaColors.skyBlue
                                : Colors.white.withValues(alpha: 0.12),
                            width: profileVM.profileImagePath == avatarPath ? 2 : 1,
                          ),
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage(avatarPath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (profileVM.profileImagePath != null) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await profileVM.saveProfileImagePath(null);
                  },
                  icon: const Icon(Icons.delete_outline, color: PhiaColors.pulseRed, size: 18),
                  label: Text(
                    'REMOVE PROFILE PICTURE',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 14,
                      letterSpacing: 1.0,
                      color: PhiaColors.pulseRed,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          color: const Color(0xFF141517),
        ),
        child: Column(
          children: [
            Icon(icon, color: PhiaColors.skyBlue, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.bebasNeue(
                fontSize: 12,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectedDevicesComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF0D0E0F),
          shape: const Border.fromBorderSide(
            BorderSide(color: Colors.white12, width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.watch, color: PhiaColors.skyBlue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'CONNECTED DEVICES',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 20,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'LINKED SMARTWATCHES & SENSORS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: PhiaColors.skyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We are developing integration models for major smartwatches and medical-grade hardware telemetry sensors. Soon, you will be able to synchronize step data, real-time heart rate, SpO2, and other vital stats directly into your DRGODLY personal health ledger offline.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pop(dialogCtx),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      color: Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'ACKNOWLEDGE',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 14,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _showEditProfileBottomSheet(BuildContext context, PlainPatient? currentProfile) {
    final givenNameController = TextEditingController(
      text: currentProfile?.name != null && currentProfile!.name!.isNotEmpty
          ? currentProfile.name!.first.givenName
          : '',
    );
    final familyNameController = TextEditingController(
      text: currentProfile?.name != null && currentProfile!.name!.isNotEmpty
          ? currentProfile.name!.first.familyName ?? ''
          : '',
    );
    final genderController = TextEditingController(text: currentProfile?.gender ?? 'male');
    final birthDateController = TextEditingController(text: currentProfile?.birthDate ?? '2000-01-01');
    final emailController = TextEditingController(text: currentProfile?.primaryEmail ?? '');
    final phoneController = TextEditingController(text: currentProfile?.primaryPhone ?? '');

    // Address extraction
    String street = '';
    String city = '';
    String state = '';
    String zip = '';
    String country = '';
    if (currentProfile?.address != null && currentProfile!.address!.isNotEmpty) {
      final addr = currentProfile.address!.first;
      street = addr.line.isNotEmpty ? addr.line.first : '';
      city = addr.city ?? '';
      state = addr.state ?? '';
      zip = addr.postalCode ?? '';
      country = addr.country ?? '';
    }

    final streetController = TextEditingController(text: street);
    final cityController = TextEditingController(text: city);
    final stateController = TextEditingController(text: state);
    final zipController = TextEditingController(text: zip);
    final countryController = TextEditingController(text: country);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const Border(
        top: BorderSide(color: PhiaColors.skyBlue, width: 2.0),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLanguageHelper.translate(context, 'patient_profile', defaultText: 'PATIENT PROFILE'),
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 2.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Name Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputGroup('GIVEN NAME', givenNameController, 'First Name'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputGroup('FAMILY NAME', familyNameController, 'Last Name'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Gender & Birthdate
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputGroup('GENDER (male|female|other)', genderController, 'male'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputGroup('BIRTH DATE (YYYY-MM-DD)', birthDateController, '2000-01-01'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Contact info
                      _buildInputGroup('EMAIL ADDRESS', emailController, 'operator@domain.sys'),
                      const SizedBox(height: 16),
                      _buildInputGroup('CONTACT PHONE', phoneController, '+10000000000'),
                      const SizedBox(height: 16),

                      // Address Info
                      _buildInputGroup('STREET RESIDENCE', streetController, 'Street line'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputGroup('CITY', cityController, 'City'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputGroup('STATE', stateController, 'State'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputGroup('POSTAL CODE / ZIP', zipController, 'Zip'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputGroup('COUNTRY', countryController, 'Country'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 54),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: () async {
                          final profileVM = context.read<ProfileViewModel>();
                          try {
                            await profileVM.saveProfileDetails(
                              givenName: givenNameController.text,
                              familyName: familyNameController.text,
                              gender: genderController.text,
                              birthDate: birthDateController.text,
                              email: emailController.text,
                              phone: phoneController.text,
                              street: streetController.text,
                              city: cityController.text,
                              state: stateController.text,
                              zip: zipController.text,
                              country: countryController.text,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile updated successfully!')),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sync failed: $e')),
                              );
                            }
                          }
                        },
                        child: Text(
                          AppLanguageHelper.translate(context, 'save_profile', defaultText: 'SAVE PROFILE'),
                          style: GoogleFonts.bebasNeue(
                            fontSize: 18,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputGroup(String label, TextEditingController controller, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            color: const Color(0xFF0D0E0F),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileVM = context.watch<ProfileViewModel>();
    final profile = profileVM.currentProfile;

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // Dot Matrix Background Grid overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header (⚡ KINETIC and Notification Bell)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
                              letterSpacing: 4.0,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => showNotificationCenter(context),
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: profileVM.isProfileLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: PhiaColors.skyBlue),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          children: [
                            const SizedBox(height: 16),

                            // 1. AVATAR BLOCK
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Double circle athlete avatar frame
                                  Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      Container(
                                        width: 104,
                                        height: 104,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            width: 2.0,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(
                                              image: getImageProvider(
                                                profileVM.profileImagePath,
                                                fallback: 'assets/avatars/avatar_1.png',
                                              ),
                                              fit: BoxFit.cover,
                                              colorFilter: const ColorFilter.matrix(<double>[
                                                0.2126, 0.7152, 0.0722, 0, -20,
                                                0.2126, 0.7152, 0.0722, 0, -20,
                                                0.2126, 0.7152, 0.0722, 0, -20,
                                                0,      0,      0,      1, 0,
                                              ]),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Edit camera overlay button
                                      Positioned(
                                        bottom: 0,
                                        right: -2,
                                        child: GestureDetector(
                                          onTap: () => _showPhotoPickerBottomSheet(context, profileVM),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: PhiaColors.skyBlue,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.black, width: 2),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 14,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // ELITE Overlaid pill tag at the bottom
                                      Positioned(
                                        bottom: -10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            AppLanguageHelper.translate(context, 'patient', defaultText: 'PATIENT'),
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  // User Name
                                  Text(
                                    profile?.primaryName.toUpperCase() ?? 'LOADING PROFILE...',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 32,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Calibration ID
                                  Text(
                                    profile != null ? 'SECURE PROFILE ENABLED' : 'OFFLINE MODE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: PhiaColors.skyBlue,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // 2. PERFORMANCE STATS CARD (3 Columns)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: PhiaColors.surface,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  _buildStatItem('GENDER', profile?.gender?.toUpperCase() ?? 'NONE'),
                                  _buildVerticalDivider(),
                                  _buildStatItem('BIRTH DATE', profile?.birthDate ?? 'NONE'),
                                  _buildVerticalDivider(),
                                  _buildStatItem('CONTACTS', (profile != null && profile.telecom != null && profile.telecom!.isNotEmpty) ? '${profile.telecom!.length} ENTRIES' : '0 ENTRIES'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 3. SETTINGS LIST BENTO BOX
                            Container(
                              decoration: BoxDecoration(
                                color: PhiaColors.surface,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                children: [
                                  _buildSettingsTile(
                                    icon: Icons.person_outline,
                                    title: 'Edit Profile Details',
                                    subContent: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'Update name, DOB, email and addresses',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.38),
                                        ),
                                      ),
                                    ),
                                    onTap: () => _showEditProfileBottomSheet(context, profile),
                                  ),
                                  _buildHorizontalDivider(),
                                  _buildSettingsTile(
                                    icon: Icons.calendar_month_outlined,
                                    title: 'Appointment History',
                                    subContent: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'View upcoming and past consultations',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.38),
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pushNamed(context, '/appointment_history');
                                    },
                                  ),
                                  _buildHorizontalDivider(),
                                  _buildSettingsTile(
                                    icon: Icons.alarm_outlined,
                                    title: AppLanguageHelper.translate(context, 'meds_vitals_reminders', defaultText: 'Meds & Vitals Reminders'),
                                    subContent: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'Schedule medication doses and vitals monitoring checks',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.38),
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pushNamed(context, '/vitals_reminders');
                                    },
                                  ),
                                  _buildHorizontalDivider(),
                                  _buildSettingsTile(
                                    icon: Icons.trending_up_outlined,
                                    title: 'Vitals Warning Thresholds',
                                    subContent: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'Define safe boundaries for blood pressure & heart rate',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.38),
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pushNamed(context, '/vitals_thresholds');
                                    },
                                  ),
                                  _buildHorizontalDivider(),
                                  _buildSettingsTile(
                                    icon: Icons.square_foot_outlined,
                                    title: 'Clinical Measurement Units',
                                    subContent: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'Configure display units (kg/lbs, cm/inches, etc.)',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.38),
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pushNamed(context, '/clinical_units');
                                    },
                                  ),
                                  _buildHorizontalDivider(),
                                  _buildSettingsTile(
                                    icon: Icons.settings_applications_outlined,
                                    title: AppLanguageHelper.translate(context, 'general_app_config', defaultText: 'General App Config'),
                                    subContent: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'Configure language localization and start week preferences',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.38),
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pushNamed(context, '/general_settings');
                                    },
                                  ),
                                  _buildHorizontalDivider(),
                                  _buildSettingsTile(
                                    icon: Icons.watch_outlined,
                                    title: AppLanguageHelper.translate(context, 'connected_devices', defaultText: 'Connected Devices'),
                                    onTap: () => _showConnectedDevicesComingSoonDialog(context),
                                    subContent: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Coming Soon: Linked smartwatches and medical sensors',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: PhiaColors.skyBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildOutlineChip('STEP SENSOR'),
                                              const SizedBox(width: 8),
                                              _buildOutlineChip('LOCATION SERVICES'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // 4. LOG OUT ACCOUNT OUTLINED BUTTON
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: Center(
                                  child: Text(
                                    'LOG OUT',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),
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

  // Stat item helper
  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Divider helpers
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildHorizontalDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // Outline capsule chip helper
  Widget _buildOutlineChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Premium list settings tile builder
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? subContent,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (subContent != null) subContent,
                ],
               ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.24),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
