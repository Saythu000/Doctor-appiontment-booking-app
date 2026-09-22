import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/image_helper.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../domain/model/patient_profile.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _biometricEnabled = true;

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
      backgroundColor: PhiaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Change Profile Photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: PhiaColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      final ImagePicker picker = ImagePicker();
                      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                      if (photo != null) {
                        await profileVM.saveProfileImagePath(photo.path);
                      }
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
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
              const SizedBox(height: 20),
              if (profileVM.profileImagePath != null)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await profileVM.saveProfileImagePath(null);
                  },
                  child: Text(
                    'Remove Photo',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PhiaColors.pulseRed,
                    ),
                  ),
                ),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: PhiaColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PhiaColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: PhiaColors.primary, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PhiaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileBottomSheet(BuildContext context, PlainPatient? currentProfile) {
    final givenNameController = TextEditingController(
      text: currentProfile?.name != null && currentProfile!.name!.isNotEmpty
          ? currentProfile.name!.first.givenName
          : 'Sarah',
    );
    final familyNameController = TextEditingController(
      text: currentProfile?.name != null && currentProfile!.name!.isNotEmpty
          ? currentProfile.name!.first.familyName ?? ''
          : 'Chen',
    );
    final emailController = TextEditingController(text: currentProfile?.primaryEmail ?? 'sarah.chen@example.com');
    final phoneController = TextEditingController(text: currentProfile?.primaryPhone ?? '+1 (555) 234-5678');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PhiaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Personal Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: PhiaColors.navyAnchor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: PhiaColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCleanInput('FIRST NAME', givenNameController, 'First Name'),
                const SizedBox(height: 14),
                _buildCleanInput('LAST NAME', familyNameController, 'Last Name'),
                const SizedBox(height: 14),
                _buildCleanInput('EMAIL ADDRESS', emailController, 'sarah.chen@example.com'),
                const SizedBox(height: 14),
                _buildCleanInput('PHONE NUMBER', phoneController, '+1 (555) 234-5678'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhiaColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCleanInput(String label, TextEditingController controller, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: PhiaColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PhiaColors.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
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
    final patientName = profile?.primaryName ?? 'Sarah J. Chen';
    final patientId = 'DG987654';

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        leading: widget.isTab
            ? const Icon(Icons.menu_rounded, color: Colors.white)
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        centerTitle: true,
        title: Text(
          'Patient Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => showNotificationCenter(context),
            icon: const Icon(Icons.search_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          children: [
            // Centered Avatar & Identity Section (matching reference image)
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: PhiaColors.navyAnchor.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: SafeNetworkImage(
                            imageUrl: profileVM.profileImagePath ?? 'assets/avatars/avatar_1.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.person,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => _showPhotoPickerBottomSheet(context, profileVM),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: PhiaColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    patientName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: PhiaColors.navyAnchor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Patient ID: $patientId',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: PhiaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CARD 1: Personal Information (Navy Header Banner)
            _buildNavyHeaderCard(
              title: 'Personal Information',
              actionIcon: Icons.edit_rounded,
              onAction: () => _showEditProfileBottomSheet(context, profile),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoGridRow(
                      leftLabel: 'Full Name',
                      leftValue: patientName,
                      rightLabel: 'Date of Birth',
                      rightValue: profile?.birthDate ?? '1988-03-15',
                    ),
                    const Divider(color: PhiaColors.borderSubtle, height: 24),
                    _buildGenderRow(selectedGender: profile?.gender?.toLowerCase() ?? 'female'),
                    const Divider(color: PhiaColors.borderSubtle, height: 24),
                    _buildFullWidthInfoRow(
                      label: 'Address',
                      value: '123 Medical Center Dr, Suite 400\nBoston, MA 02115',
                    ),
                    const Divider(color: PhiaColors.borderSubtle, height: 24),
                    _buildInfoGridRow(
                      leftLabel: 'Phone Number',
                      leftValue: profile?.primaryPhone ?? '+1 (555) 234-5678',
                      rightLabel: 'Email Address',
                      rightValue: profile?.primaryEmail ?? 'sarah.chen@example.com',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARD 2: Account Settings (Navy Header Banner)
            _buildNavyHeaderCard(
              title: 'Account Settings',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    _buildToggleRow(
                      title: 'Notifications',
                      subtitle: 'Receive appointment updates & alerts',
                      value: _notificationsEnabled,
                      onChanged: (val) {
                        setState(() {
                          _notificationsEnabled = val;
                        });
                      },
                    ),
                    const Divider(color: PhiaColors.borderSubtle, height: 1),
                    _buildToggleRow(
                      title: 'App Security',
                      subtitle: 'Biometric Face ID / Fingerprint login',
                      value: _biometricEnabled,
                      onChanged: (val) {
                        setState(() {
                          _biometricEnabled = val;
                        });
                      },
                    ),
                    const Divider(color: PhiaColors.borderSubtle, height: 1),
                    _buildNavActionRow(
                      title: 'Preferred Language',
                      value: 'English (US)',
                      onTap: () => Navigator.pushNamed(context, '/general_settings'),
                    ),
                    const Divider(color: PhiaColors.borderSubtle, height: 1),
                    _buildNavActionRow(
                      title: 'Vitals Reminders & Thresholds',
                      value: 'Configured',
                      onTap: () => Navigator.pushNamed(context, '/vitals_reminders'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARD 3: Clinical Unit Registrations (Navy Header Banner)
            _buildNavyHeaderCard(
              title: 'Clinical Unit Registrations',
              actionWidget: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/clinical_units'),
                child: Text(
                  'Manage',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Unit 1: Neurology Unit (Sky Blue Card)
                          _buildUnitCard(
                            unitName: 'Neurology Unit',
                            doctorName: 'Dr. Michael Chang',
                            status: 'ACTIVE',
                            cardBgColor: const Color(0xFF4BAAE5),
                            textColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          // Unit 2: Cardiology Unit (Sky Blue Card)
                          _buildUnitCard(
                            unitName: 'Cardiology Unit',
                            doctorName: 'Dr. Elena Rostova',
                            status: 'ACTIVE',
                            cardBgColor: const Color(0xFF4BAAE5),
                            textColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          // Unit 3: Primary Care (Navy Card)
                          _buildUnitCard(
                            unitName: 'Primary Care',
                            doctorName: 'Dr. Sarah Jenkins',
                            status: 'ACTIVE',
                            cardBgColor: PhiaColors.navyAnchor,
                            textColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sign Out / Log Out Button
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                icon: const Icon(Icons.logout_rounded, color: PhiaColors.pulseRed, size: 18),
                label: Text(
                  'Sign Out of Account',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.pulseRed,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS MATCHING REFERENCE IMAGE ---

  Widget _buildNavyHeaderCard({
    required String title,
    required Widget child,
    IconData? actionIcon,
    VoidCallback? onAction,
    Widget? actionWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Deep Oxford Navy Top Banner Header
          Container(
            color: PhiaColors.navyAnchor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (actionWidget != null)
                  actionWidget
                else if (actionIcon != null && onAction != null)
                  InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(actionIcon, color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          // White Card Body
          child,
        ],
      ),
    );
  }

  Widget _buildInfoGridRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leftLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PhiaColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                leftValue,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PhiaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rightLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PhiaColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                rightValue,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PhiaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderRow({required String selectedGender}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: PhiaColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildGenderChip('Female', selectedGender == 'female'),
            const SizedBox(width: 8),
            _buildGenderChip('Male', selectedGender == 'male'),
            const SizedBox(width: 8),
            _buildGenderChip('Other', selectedGender == 'other'),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE1F2FC) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? PhiaColors.primary : PhiaColors.borderSubtle,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? PhiaColors.navyAnchor : PhiaColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFullWidthInfoRow({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: PhiaColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PhiaColors.textPrimary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: PhiaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: PhiaColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: PhiaColors.borderSubtle,
          ),
        ],
      ),
    );
  }

  Widget _buildNavActionRow({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PhiaColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: PhiaColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PhiaColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard({
    required String unitName,
    required String doctorName,
    required String status,
    required Color cardBgColor,
    required Color textColor,
  }) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: cardBgColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  unitName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            doctorName,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'View Details',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cardBgColor == PhiaColors.navyAnchor ? PhiaColors.navyAnchor : const Color(0xFF228BCA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
