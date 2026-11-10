import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/form_feedback.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/profile/presentation/widgets/profile_details_card.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// Opens the full-screen "Edit profile" form.
Future<void> openEditProfile(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const EditProfilePage()),
  );
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phonePattern = RegExp(r'^\+?[0-9 ()-]{7,20}$');

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _given = TextEditingController();
  final _family = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _country = TextEditingController();
  late final List<TextEditingController> _all = [
    _given,
    _family,
    _email,
    _phone,
    _street,
    _city,
    _state,
    _zip,
    _country,
  ];

  DateTime? _dob;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileViewModel>().currentProfile;
    final user = context.read<AuthViewModel>().user;
    _prefill(profile, userName: user?.name ?? '', userEmail: user?.email ?? '');
  }

  void _prefill(PlainPatient? profile, {required String userName, required String userEmail}) {
    final name = (profile?.name?.isNotEmpty ?? false) ? profile!.name!.first : null;
    if (name != null && name.givenName.isNotEmpty) {
      _given.text = name.givenName;
      _family.text = name.familyName ?? '';
    } else {
      // Fall back to the name the user signed up with.
      final parts = userName.trim().split(RegExp(r'\s+'));
      _given.text = parts.isNotEmpty ? parts.first : '';
      _family.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    _email.text = (profile?.primaryEmail.isNotEmpty ?? false) ? profile!.primaryEmail : userEmail;
    _phone.text = profile?.primaryPhone ?? '';
    _dob = DateTime.tryParse(profile?.birthDate ?? '');
    final g = profile?.gender?.trim().toUpperCase();
    _gender = profileGenders.any((e) => e.$1 == g) ? g : null;

    final addr = (profile?.address?.isNotEmpty ?? false) ? profile!.address!.first : null;
    if (addr != null) {
      _street.text = addr.line.join(', ');
      _city.text = addr.city ?? '';
      _state.text = addr.state ?? '';
      _zip.text = addr.postalCode ?? '';
      _country.text = addr.country ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
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
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  int _ageOn(DateTime dob, DateTime now) {
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  Future<void> _save() async {
    if (_saving || !validateForm(context, _formKey)) return;
    FocusScope.of(context).unfocus();
    final profileVM = context.read<ProfileViewModel>();
    final activityVM = context.read<ActivityViewModel>();
    // Captured now so messages still show after this page closes.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      // Age follows the date of birth. Unknown age stays 0 ("not set").
      if (_dob != null) {
        final age = _ageOn(_dob!, DateTime.now());
        if (age > 0 && age != activityVM.userAge) {
          await activityVM.saveBioData(
            weight: activityVM.userWeight,
            height: activityVM.userHeight,
            age: age.toDouble(),
          );
        }
      }

      var savedRemotely = true;
      try {
        await profileVM.saveProfileDetails(
          givenName: _given.text.trim(),
          familyName: _family.text.trim(),
          gender: _gender ?? '',
          birthDate: _dob == null ? '' : DateFormat('yyyy-MM-dd').format(_dob!),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          street: _street.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          zip: _zip.text.trim(),
          country: _country.text.trim(),
        );
      } catch (remoteErr) {
        debugPrint('Profile remote update exception: $remoteErr');
        savedRemotely = false;
      }

      if (savedRemotely) {
        navigator.pop();
        _show(messenger, 'Profile updated.', FeedbackType.success);
      } else {
        // Stay on the form so the user can try again.
        if (mounted) setState(() => _saving = false);
        _show(
          messenger,
          "Saved on this phone, but your profile couldn't be updated on the server. Please try again.",
          FeedbackType.error,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _show(messenger, "Couldn't save your changes. Please try again.", FeedbackType.error);
    }
  }

  void _show(ScaffoldMessengerState messenger, String message, FeedbackType type) {
    if (!messenger.mounted) return;
    showAppMessage(messenger.context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close without saving',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Not a lazy ListView: every field must stay built so the Form
          // validates fields that are scrolled out of view.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _GroupTitle('Name'),
                _field(_given, 'First name', required: true, capital: TextCapitalization.words),
                _field(_family, 'Last name', required: true, capital: TextCapitalization.words),
                const SizedBox(height: AppSpacing.sm),
                const _GroupTitle('About you'),
                Semantics(
                  button: true,
                  label: 'Date of birth, ${_dob == null ? 'not set' : DateFormat('d MMMM y').format(_dob!)}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: AppRadius.mdAll,
                    onTap: _pickDob,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of birth',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      isEmpty: _dob == null,
                      child: Text(
                        _dob == null ? '' : DateFormat('d MMM y').format(_dob!),
                        style: context.text.bodyLarge,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Gender', style: context.text.labelLarge!.copyWith(color: colors.textSecondary)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final (value, label) in profileGenders)
                      ChoiceChip(
                        label: Text(label),
                        selected: _gender == value,
                        onSelected: (_) => setState(() => _gender = value),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _GroupTitle('Contact'),
                _field(
                  _phone,
                  'Phone',
                  keyboard: TextInputType.phone,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    return _phonePattern.hasMatch(t) ? null : 'Enter a valid phone number';
                  },
                ),
                _field(
                  _email,
                  'Email',
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    return _emailPattern.hasMatch(t) ? null : 'Enter a valid email address';
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                const _GroupTitle('Address (optional)'),
                _field(_street, 'Street', keyboard: TextInputType.streetAddress, capital: TextCapitalization.words),
                _field(_city, 'City', capital: TextCapitalization.words),
                _field(_state, 'State', capital: TextCapitalization.words),
                _field(_zip, 'Postal code'),
                _field(_country, 'Country', capital: TextCapitalization.words, last: true),
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization capital = TextCapitalization.none,
    String? Function(String?)? validator,
    bool last = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TextFormField(
          controller: controller,
          keyboardType: keyboard,
          textCapitalization: capital,
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear $label',
                    onPressed: controller.clear,
                  ),
          ),
          validator: validator ??
              (required ? (v) => (v ?? '').trim().isEmpty ? 'Please enter your ${label.toLowerCase()}' : null : null),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(header: true, child: Text(text, style: context.text.titleMedium)),
    );
  }
}
