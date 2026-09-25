import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/image_helper.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/activity_viewmodel.dart';
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
    final authVM = context.read<AuthViewModel>();
    final profileVM = context.read<ProfileViewModel>();
    final activityVM = context.read<ActivityViewModel>();
    final defaultGiven = authVM.user?.name.split(' ').first ?? '';
    final defaultFamily = (authVM.user?.name.split(' ').length ?? 0) > 1
        ? authVM.user!.name.split(' ').sublist(1).join(' ')
        : '';
    final defaultEmail = authVM.user?.email ?? '';

    final givenNameController = TextEditingController(
      text: (currentProfile?.name != null && currentProfile!.name!.isNotEmpty && currentProfile.name!.first.givenName.isNotEmpty)
          ? currentProfile.name!.first.givenName
          : defaultGiven,
    );
    final familyNameController = TextEditingController(
      text: (currentProfile?.name != null && currentProfile!.name!.isNotEmpty)
          ? (currentProfile.name!.first.familyName ?? '')
          : defaultFamily,
    );
    final emailController = TextEditingController(
      text: (currentProfile?.primaryEmail.isNotEmpty == true)
          ? currentProfile!.primaryEmail
          : defaultEmail,
    );
    final phoneController = TextEditingController(
      text: currentProfile?.primaryPhone ?? '',
    );
    final dobController = TextEditingController(
      text: currentProfile?.birthDate ?? '',
    );
    final heightController = TextEditingController(
      text: activityVM.userHeight > 0 ? activityVM.userHeight.toStringAsFixed(0) : '',
    );
    final weightController = TextEditingController(
      text: activityVM.userWeight > 0 ? activityVM.userWeight.toStringAsFixed(1) : '',
    );

    String existingStreet = '';
    String existingCity = '';
    String existingState = '';
    String existingZip = '';
    String existingCountry = '';
    if (currentProfile?.address != null && currentProfile!.address!.isNotEmpty) {
      final addr = currentProfile.address!.first;
      existingStreet = addr.line.isNotEmpty ? addr.line.join(', ') : '';
      existingCity = addr.city ?? '';
      existingState = addr.state ?? '';
      existingZip = addr.postalCode ?? '';
      existingCountry = addr.country ?? '';
    }

    final streetController = TextEditingController(text: existingStreet);
    final cityController = TextEditingController(text: existingCity);
    final stateController = TextEditingController(text: existingState);
    final zipController = TextEditingController(text: existingZip);
    final countryController = TextEditingController(text: existingCountry);

    String selectedGender = currentProfile?.gender?.toLowerCase() ?? 'female';
    if (selectedGender != 'male' && selectedGender != 'female' && selectedGender != 'other') {
      selectedGender = 'female';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PhiaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                      const SizedBox(height: 14),

                      // NAME ROW
                      Row(
                        children: [
                          Expanded(child: _buildCleanInput('FIRST NAME', givenNameController, 'First Name')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCleanInput('LAST NAME', familyNameController, 'Last Name')),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // GENDER SELECTOR
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GENDER',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildInteractiveGenderChip('Female', selectedGender == 'female', () {
                                setSheetState(() => selectedGender = 'female');
                              }),
                              const SizedBox(width: 8),
                              _buildInteractiveGenderChip('Male', selectedGender == 'male', () {
                                setSheetState(() => selectedGender = 'male');
                              }),
                              const SizedBox(width: 8),
                              _buildInteractiveGenderChip('Other', selectedGender == 'other', () {
                                setSheetState(() => selectedGender = 'other');
                              }),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // DATE OF BIRTH (with DatePicker tap)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DATE OF BIRTH (YYYY-MM-DD)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              DateTime initial = DateTime.tryParse(dobController.text) ?? DateTime(2000, 1, 1);
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                final formatted = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                setSheetState(() {
                                  dobController.text = formatted;
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: PhiaColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: PhiaColors.borderSubtle),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dobController.text.isNotEmpty ? dobController.text : 'Select Date of Birth',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: dobController.text.isNotEmpty ? PhiaColors.textPrimary : PhiaColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 18, color: PhiaColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // HEIGHT & WEIGHT ROW
                      Row(
                        children: [
                          Expanded(
                            child: _buildCleanInput(
                              'HEIGHT (CM)',
                              heightController,
                              'e.g. 175',
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCleanInput(
                              'WEIGHT (KG)',
                              weightController,
                              'e.g. 70.5',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // PHONE & EMAIL
                      _buildCleanInput('PHONE NUMBER', phoneController, '+1 234 567 8900'),
                      const SizedBox(height: 14),
                      _buildCleanInput('EMAIL ADDRESS', emailController, 'name@example.com'),
                      const SizedBox(height: 14),

                      // ADDRESS FIELDS
                      _buildCleanInput('STREET ADDRESS', streetController, '123 Health Ave, Suite 400'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _buildCleanInput('CITY', cityController, 'City')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCleanInput('STATE / PROV', stateController, 'State')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _buildCleanInput('POSTAL CODE', zipController, 'Postal Code')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCleanInput('COUNTRY', countryController, 'Country')),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SAVE BUTTON
                      ElevatedButton(
                        onPressed: () async {
                          final gName = givenNameController.text.trim();
                          final fName = familyNameController.text.trim();
                          final pDob = dobController.text.trim();
                          final pHeight = heightController.text.trim();
                          final pWeight = weightController.text.trim();
                          final pPhone = phoneController.text.trim();
                          final pEmail = emailController.text.trim();
                          final pStreet = streetController.text.trim();
                          final pCity = cityController.text.trim();
                          final pState = stateController.text.trim();
                          final pZip = zipController.text.trim();
                          final pCountry = countryController.text.trim();

                          Navigator.pop(context);

                          try {
                            // 1. Save Height, Weight & Age to SQLite immediately
                            final hVal = double.tryParse(pHeight) ?? 0.0;
                            final wVal = double.tryParse(pWeight) ?? 0.0;
                            int calcAge = activityVM.userAge;
                            if (pDob.isNotEmpty) {
                              final birth = DateTime.tryParse(pDob);
                              if (birth != null) {
                                final now = DateTime.now();
                                calcAge = now.year - birth.year;
                                if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
                                  calcAge--;
                                }
                              }
                            }
                            if (hVal > 0 || wVal > 0 || calcAge > 0) {
                              await activityVM.saveBioData(
                                weight: wVal > 0 ? wVal : activityVM.userWeight,
                                height: hVal > 0 ? hVal : activityVM.userHeight,
                                age: calcAge > 0 ? calcAge.toDouble() : (activityVM.userAge > 0 ? activityVM.userAge.toDouble() : 25.0),
                              );
                            }

                            // 2. Save profile demographics (wrapped in inner try so remote failure doesn't block UI)
                            try {
                              await profileVM.saveProfileDetails(
                                givenName: gName,
                                familyName: fName,
                                gender: selectedGender,
                                birthDate: pDob,
                                email: pEmail,
                                phone: pPhone,
                                street: pStreet,
                                city: pCity,
                                state: pState,
                                zip: pZip,
                                country: pCountry,
                              );
                            } catch (remoteErr) {
                              debugPrint('Profile remote update exception: $remoteErr');
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: PhiaColors.activeGreen,
                                  content: Text(
                                    'Profile updated successfully!',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: PhiaColors.primary,
                                  content: Text(
                                    'Saved locally.',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
                                  ),
                                ),
                              );
                            }
                          }
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
                      const SizedBox(height: 24),
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

  Widget _buildInteractiveGenderChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      ),
    );
  }

  Widget _buildCleanInput(
    String label,
    TextEditingController controller,
    String placeholder, {
    TextInputType? keyboardType,
  }) {
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
            keyboardType: keyboardType,
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
    final authVM = context.watch<AuthViewModel>();
    final profileVM = context.watch<ProfileViewModel>();
    final bookingVM = context.watch<BookingViewModel>();
    final activityVM = context.watch<ActivityViewModel>();
    final profile = profileVM.currentProfile;

    String patientName = '--';
    if (profile?.name != null && profile!.name!.isNotEmpty && profile.name!.first.fullName.trim().isNotEmpty) {
      patientName = profile.name!.first.fullName.trim();
    } else if (authVM.user?.name != null && authVM.user!.name.trim().isNotEmpty) {
      patientName = authVM.user!.name.trim();
    }

    String patientId = '--';
    if (profile?.id != null && profile!.id > 0) {
      patientId = '#${profile.id}';
    } else if (authVM.userId != null && authVM.userId!.isNotEmpty) {
      final cleanId = authVM.userId!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      patientId = 'DG-${cleanId.length >= 6 ? cleanId.substring(0, 6) : cleanId}';
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
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
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded, color: Colors.white),
                if (bookingVM.appointmentsList.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: PhiaColors.pulseRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${bookingVM.appointmentsList.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
              child: InkWell(
                onTap: () => _showEditProfileBottomSheet(context, profile),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoGridRow(
                        leftLabel: 'Full Name',
                        leftValue: patientName,
                        rightLabel: 'Date of Birth',
                        rightValue: (profile?.birthDate != null && profile!.birthDate!.isNotEmpty)
                            ? profile.birthDate!
                            : '--',
                      ),
                      const Divider(color: PhiaColors.borderSubtle, height: 24),
                      _buildInfoGridRow(
                        leftLabel: 'Height',
                        leftValue: activityVM.userHeight > 0 ? '${activityVM.userHeight.toStringAsFixed(0)} cm' : '--',
                        rightLabel: 'Weight',
                        rightValue: activityVM.userWeight > 0 ? '${activityVM.userWeight.toStringAsFixed(1)} kg' : '--',
                      ),
                      const Divider(color: PhiaColors.borderSubtle, height: 24),
                      _buildGenderRow(selectedGender: profile?.gender?.toLowerCase() ?? ''),
                      const Divider(color: PhiaColors.borderSubtle, height: 24),
                      _buildFullWidthInfoRow(
                        label: 'Address',
                        value: (profile?.address != null && profile!.address!.isNotEmpty)
                            ? [...profile.address!.first.line, profile.address!.first.city, profile.address!.first.state, profile.address!.first.postalCode, profile.address!.first.country]
                                .where((s) => s != null && s.trim().isNotEmpty)
                                .join(', ')
                            : 'Not Set',
                      ),
                      const Divider(color: PhiaColors.borderSubtle, height: 24),
                      _buildInfoGridRow(
                        leftLabel: 'Phone Number',
                        leftValue: (profile?.primaryPhone.isNotEmpty == true) ? profile!.primaryPhone : '--',
                        rightLabel: 'Email Address',
                        rightValue: (profile?.primaryEmail.isNotEmpty == true)
                            ? profile!.primaryEmail
                            : (authVM.user?.email ?? '--'),
                      ),
                    ],
                  ),
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
                    const Divider(color: PhiaColors.borderSubtle, height: 1),
                    _buildNavActionRow(
                      title: 'Clinical Unit Registrations',
                      value: 'Configured',
                      onTap: () => Navigator.pushNamed(context, '/clinical_units'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out / Log Out Button
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  context.read<ActivityViewModel>().resetState();
                  context.read<ProfileViewModel>().resetState();
                  await context.read<AuthViewModel>().signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: PhiaColors.pulseRed, size: 18),
                label: Text(
                  'Sign Out',
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


}
