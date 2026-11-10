import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/state_views.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/date_strip.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/slot_picker.dart';
import 'package:provider/provider.dart';

/// "Choose a time": day strip, free times and visit type. Also used to
/// reschedule an existing appointment (`reschedule_appointment_id` in args).
class SelectDateTimeScreen extends StatefulWidget {
  const SelectDateTimeScreen({super.key});

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  late DateTime _selectedDate;
  late final List<DateTime> _days;
  BookingSlot? _slot;
  bool _isVirtual = true;
  PractitionerRoleBooking? _specialist;
  bool _initialized = false;
  bool _rescheduling = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(30, (i) => today.add(Duration(days: i)));
    _selectedDate = today;
  }

  Map<String, dynamic> get _args {
    final extra = GoRouterState.of(context).extra;
    return extra is Map<String, dynamic> ? extra : const {};
  }

  bool _available(DateTime d) => isDoctorAvailableOn(_specialist, d);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _specialist = _args['specialist'] as PractitionerRoleBooking?;
    // Start on the first day the doctor works.
    if (!_available(_selectedDate)) {
      _selectedDate = _days.firstWhere(_available, orElse: () => _selectedDate);
    }
    _fetchSlots();
  }

  void _fetchSlots() {
    final specialist = _specialist;
    if (specialist == null) return;
    final date = _selectedDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BookingViewModel>().fetchBookedSlots(specialist.id, date);
    });
  }

  void _pickDay(DateTime d) {
    setState(() {
      _selectedDate = d;
      _slot = null;
    });
    _fetchSlots();
  }

  Future<void> _reschedule() async {
    final slotId = _slot?.id;
    // Never send slot 0 or a missing slot to the server.
    if (slotId == null || slotId <= 0) {
      showAppMessage(context, 'Please pick an available time.', type: FeedbackType.error);
      return;
    }
    final vm = context.read<BookingViewModel>();
    final router = GoRouter.of(context);
    setState(() => _rescheduling = true);
    final ok = await vm.rescheduleAppointment(_args['reschedule_appointment_id'].toString(), slotId);
    if (!mounted) return;
    if (ok) {
      showAppMessage(context, 'Your visit was moved.', type: FeedbackType.success);
      router.pop();
    } else {
      setState(() => _rescheduling = false);
      showAppMessage(context, "Couldn't move your visit. Please try another time.", type: FeedbackType.error);
    }
  }

  Future<void> _review() async {
    final slot = _slot;
    if (slot == null) return;
    final args = _args;
    final outcome = await context.push(AppRoutes.bookingReview, extra: {
      'specialist': _specialist,
      'name': args['name'],
      'role': args['role'],
      'imageUrl': args['imageUrl'],
      'date': DateFormat('MMMM d, yyyy').format(_selectedDate),
      'date_raw': _selectedDate,
      'time': slot.displayTime,
      'slot_id': slot.id,
      'isVirtual': _isVirtual,
      if (args['intakeCompleted'] == true) 'intakeCompleted': true,
      if (args['intakeId'] != null) 'intakeId': args['intakeId'],
      if (args['clinicalReport'] != null) 'clinicalReport': args['clinicalReport'],
    });
    if (outcome == 'slot_taken' && mounted) {
      // Someone else booked it first (409): reload the free times.
      setState(() => _slot = null);
      _fetchSlots();
      showAppMessage(
        context,
        'That time was just booked by someone else. Please pick another time.',
        type: FeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    final name = honestName(args['name'] as String?);
    final role = honestRole(args['role'] as String?);
    final isRescheduling = args['reschedule_appointment_id'] != null;

    return Scaffold(
      appBar: AppBar(title: Text(isRescheduling ? 'Move your visit' : 'Choose a time')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: [
                  Padding(
                    padding: AppSpacing.screen,
                    child: AppCard(
                      child: DoctorHeader(
                        name: name,
                        role: role,
                        photoUrl: args['imageUrl'] as String?,
                        avatarSize: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Padding(padding: AppSpacing.screen, child: SectionHeader(title: 'Day')),
                  DateStrip(days: _days, selected: _selectedDate, isAvailable: _available, onSelected: _pickDay),
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: AppSpacing.screen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: 'Free times on ${DateFormat('EEE, MMM d').format(_selectedDate)}'),
                        _Slots(
                          doctorName: name,
                          selectedSlotId: _slot?.id,
                          onSelected: (s) => setState(() => _slot = s),
                          onRetry: _fetchSlots,
                        ),
                        if (!isRescheduling) ...[
                          const SizedBox(height: AppSpacing.xl),
                          const SectionHeader(title: 'Visit type'),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, icon: Icon(Icons.videocam_rounded), label: Text('Video')),
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.local_hospital_rounded),
                                label: Text('In person'),
                              ),
                            ],
                            selected: {_isVirtual},
                            onSelectionChanged: (v) => setState(() => _isVirtual = v.first),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomBar(
              summary: _slot == null
                  ? 'Pick a time to continue'
                  : '${DateFormat('EEE, MMM d').format(_selectedDate)} at ${_slot!.displayTime}',
              detail: isRescheduling ? null : (_isVirtual ? 'Video visit' : 'In-person visit'),
              button: AppButton(
                label: isRescheduling ? 'Move visit' : 'Continue',
                icon: isRescheduling ? null : Icons.arrow_forward_rounded,
                isLoading: _rescheduling,
                onPressed: _slot == null ? null : (isRescheduling ? _reschedule : _review),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading, error (with retry), empty and list states for the free times.
class _Slots extends StatelessWidget {
  final String doctorName;
  final int? selectedSlotId;
  final ValueChanged<BookingSlot> onSelected;
  final VoidCallback onRetry;

  const _Slots({
    required this.doctorName,
    required this.selectedSlotId,
    required this.onSelected,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingViewModel>();
    if (vm.isSlotsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: LoadingView(message: 'Checking free times…'),
      );
    }
    if (vm.slotsError != null) {
      return ErrorView(title: "Couldn't load times", message: vm.slotsError, onRetry: onRetry);
    }
    if (vm.availableSlots.isEmpty) {
      return EmptyView(
        icon: Icons.event_busy_rounded,
        title: 'No free times this day',
        message: '$doctorName has no free times on this day. Try another day above.',
      );
    }
    return SlotPicker(slots: vm.availableSlots, selectedSlotId: selectedSlotId, onSelected: onSelected);
  }
}

/// Sticky summary of the choice plus the primary button.
class _BottomBar extends StatelessWidget {
  final String summary;
  final String? detail;
  final Widget button;

  const _BottomBar({required this.summary, required this.detail, required this.button});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(summary, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (detail != null) Text(detail!, style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          button,
        ],
      ),
    );
  }
}
