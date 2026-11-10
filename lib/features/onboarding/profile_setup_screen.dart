import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/onboarding/widgets/choice_chip_group.dart';
import 'package:phia_flutter/features/onboarding/widgets/onboarding_scaffold.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// Onboarding step 1: the patient's basic details, saved to their DrGodly
/// patient record (patient guide: PATCH /patients/{id}/full).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _dobText = TextEditingController();

  /// Values the patient record expects (FHIR administrative gender).
  static const _genders = [('MALE', 'Male'), ('FEMALE', 'Female'), ('OTHER', 'Other')];

  DateTime? _dob;
  String? _gender; // nothing preselected
  bool _showGenderError = false;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    _prefill();
  }

  /// Fills in what we already know: the existing profile first, then the
  /// name on the signed-in account. Never invents values.
  void _prefill() {
    final profile = context.read<ProfileViewModel>().currentProfile;
    final activity = context.read<ActivityViewModel>();

    final name = profile?.name?.firstOrNull;
    if (name != null && name.givenName.isNotEmpty) {
      _firstName.text = name.givenName;
      _lastName.text = name.familyName ?? '';
    } else {
      final accountName = context.read<AuthViewModel>().user?.name.trim() ?? '';
      if (accountName.isNotEmpty && accountName != 'User') {
        final parts = accountName.split(RegExp(r'\s+'));
        _firstName.text = parts.first;
        _lastName.text = parts.skip(1).join(' ');
      }
    }

    final g = profile?.gender?.toUpperCase();
    if (_genders.any((o) => o.$1 == g)) _gender = g;

    final dob = DateTime.tryParse(profile?.birthDate ?? '');
    if (dob != null) _setDob(dob);

    final phone = profile?.primaryPhone ?? '';
    if (phone.isNotEmpty) _phone.text = phone;

    if (activity.userHeight > 0) _height.text = activity.userHeight.toStringAsFixed(0);
    if (activity.userWeight > 0) _weight.text = activity.userWeight.toStringAsFixed(1);
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _phone, _height, _weight, _dobText]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setDob(DateTime d) {
    _dob = DateTime(d.year, d.month, d.day);
    _dobText.text = DateFormat('d MMMM yyyy').format(_dob!);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _setDob(picked));
  }

  static int _ageOn(DateTime dob, DateTime today) {
    var age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
    return age;
  }

  // ---- validation ----
  static String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? 'Please enter your $what' : null;

  static String? _phoneRule(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null; // optional
    final digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(digits)) return 'Enter a valid phone number';
    return null;
  }

  String? _rangeRule(String? v, {required double min, required double max, required String unit}) {
    final value = v?.trim() ?? '';
    final other = unit == 'cm' ? _weight.text.trim() : _height.text.trim();
    if (value.isEmpty) {
      // Optional, but height and weight only make sense together.
      return other.isEmpty ? null : 'Add this too, or clear both';
    }
    final n = double.tryParse(value);
    if (n == null || n < min || n > max) return 'Use ${min.toInt()}–${max.toInt()} $unit';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState!.validate();
    setState(() => _showGenderError = _gender == null);
    if (!formOk || _gender == null) {
      showAppMessage(context, 'Please check the highlighted fields.', type: FeedbackType.error);
      return;
    }

    final profileVM = context.read<ProfileViewModel>();
    final activityVM = context.read<ActivityViewModel>();
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    final birthDate = DateFormat('yyyy-MM-dd').format(_dob!);

    setState(() => _saving = true);
    try {
      if (height != null && weight != null) {
        await activityVM.saveBioData(
          weight: weight,
          height: height,
          age: _ageOn(_dob!, DateTime.now()).toDouble(),
        );
      }
      // Blank email/address mean "keep what is on the record".
      await profileVM.saveProfileDetails(
        givenName: _firstName.text.trim(),
        familyName: _lastName.text.trim(),
        gender: _gender!,
        birthDate: birthDate,
        email: '',
        phone: _phone.text.trim(),
        street: '',
        city: '',
        state: '',
        zip: '',
        country: '',
      );
      if (!mounted) return;
      context.push(AppRoutes.goals);
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfileSetupScreen] save failed: $e');
      // Booking needs this record on the server, so don't move on as if it
      // worked: say so and let the patient retry.
      if (mounted) {
        showAppMessage(
          context,
          "We couldn't save your profile. Check your connection and try again.",
          type: FeedbackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      title: 'Tell us about you',
      subtitle: 'Your doctor sees these details on your record. You can change them later in Profile.',
      bottom: AppButton(label: 'Continue', isLoading: _saving, onPressed: _save),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: 'Your name',
              children: [
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First name'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  validator: (v) => _required(v, 'first name'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  validator: (v) => _required(v, 'last name'),
                ),
              ],
            ),
            _Section(
              title: 'About you',
              children: [
                TextFormField(
                  controller: _dobText,
                  readOnly: true,
                  onTap: _pickDob,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  validator: (_) => _dob == null ? 'Please choose your date of birth' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Gender', style: context.text.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                SegmentedChoice<String>(
                  options: _genders,
                  selected: _gender,
                  errorText: _showGenderError ? 'Please choose one' : null,
                  onChanged: (g) => setState(() {
                    _gender = g;
                    _showGenderError = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]'))],
                  decoration: const InputDecoration(labelText: 'Phone number (optional)'),
                  validator: _phoneRule,
                ),
              ],
            ),
            _Section(
              title: 'Body measurements (optional)',
              note: 'Used for BMI on your Home screen.',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm'),
                        validator: (v) => _rangeRule(v, min: 50, max: 250, unit: 'cm'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
                        validator: (v) => _rangeRule(v, min: 2, max: 400, unit: 'kg'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? note;
  final List<Widget> children;

  const _Section({required this.title, required this.children, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: title),
            if (note != null) ...[
              Text(note!, style: context.text.bodySmall),
              const SizedBox(height: AppSpacing.md),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
