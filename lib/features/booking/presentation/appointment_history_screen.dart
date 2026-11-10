import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/core/widgets/state_views.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/appointment_card.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/stale_banner.dart';
import 'package:provider/provider.dart';

const _finishedStatuses = {'fulfilled', 'completed', 'noshow', 'no-show', 'cancelled', 'canceled'};

/// Splits appointments into upcoming (soonest first) and past (newest day
/// first, morning to evening within a day).
({List<Map<String, dynamic>> upcoming, List<Map<String, dynamic>> past}) splitAppointments(
  List<Map<String, dynamic>> all,
  DateTime now,
) {
  final upcoming = <Map<String, dynamic>>[];
  final past = <Map<String, dynamic>>[];
  for (final appt in all) {
    final status = (appt['status'] as String? ?? '').toLowerCase();
    final start = DateTime.tryParse(appt['start_time'] as String? ?? '')?.toLocal();
    if (start != null && start.isAfter(now) && !_finishedStatuses.contains(status)) {
      upcoming.add(appt);
    } else {
      past.add(appt);
    }
  }
  DateTime? at(Map<String, dynamic> a) => DateTime.tryParse(a['start_time'] as String? ?? '')?.toLocal();

  upcoming.sort((a, b) {
    final dtA = at(a), dtB = at(b);
    if (dtA == null || dtB == null) return '${a['start_time']}'.compareTo('${b['start_time']}');
    return dtA.compareTo(dtB);
  });
  past.sort((a, b) {
    final dtA = at(a), dtB = at(b);
    if (dtA == null || dtB == null) return '${b['start_time']}'.compareTo('${a['start_time']}');
    final byDay = DateTime(dtB.year, dtB.month, dtB.day).compareTo(DateTime(dtA.year, dtA.month, dtA.day));
    if (byDay != 0) return byDay;
    return (dtA.hour * 60 + dtA.minute).compareTo(dtB.hour * 60 + dtB.minute);
  });
  return (upcoming: upcoming, past: past);
}

/// "My appointments": Upcoming and Past tabs.
class AppointmentHistoryScreen extends StatefulWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  State<AppointmentHistoryScreen> createState() => _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> {
  final Set<String> _cancelling = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BookingViewModel>().fetchAppointments();
    });
  }

  Future<void> _cancel(Map<String, dynamic> appt) async {
    final id = appt['id']?.toString() ?? '';
    if (id.isEmpty || _cancelling.contains(id)) return;
    final name = honestName(appt['practitioner_name'] as String?);
    final (date, time) = formatAppointmentTime(appt['start_time'] as String?);
    final ok = await confirmAction(
      context,
      title: 'Cancel this visit?',
      message: 'Your visit with $name on $date${time.isEmpty ? '' : ' at $time'} will be cancelled.',
      confirmLabel: 'Cancel visit',
      cancelLabel: 'Keep visit',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final vm = context.read<BookingViewModel>();
    setState(() => _cancelling.add(id));
    var success = true;
    try {
      await vm.cancelAppointment(id);
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    setState(() => _cancelling.remove(id));
    showAppMessage(
      context,
      success ? 'Your visit was cancelled.' : "Couldn't cancel your visit. Check your connection and try again.",
      type: success ? FeedbackType.success : FeedbackType.error,
    );
  }

  Future<void> _reschedule(Map<String, dynamic> appt) async {
    final vm = context.read<BookingViewModel>();
    if (vm.specialists.isEmpty) await vm.fetchSpecialists();
    if (!mounted) return;
    final name = honestName(appt['practitioner_name'] as String?);
    final specialist = vm.findSpecialistForAppointment(appt);
    if (specialist == null) {
      showAppMessage(
        context,
        "$name isn't in the current doctor list, so this visit can't be moved in the app. "
        'Cancel it and book a new time instead.',
      );
      return;
    }
    await context.push(AppRoutes.bookingTime, extra: {
      'specialist': specialist,
      'name': name,
      'role': honestRole(appt['practitioner_role'] as String?),
      'imageUrl': appt['practitioner_image'] ?? '',
      'reschedule_appointment_id': appt['id'],
    });
    if (mounted) vm.fetchAppointments();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingViewModel>();
    final split = splitAppointments(vm.appointmentsList, DateTime.now());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My appointments'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Upcoming (${split.upcoming.length})'),
              Tab(text: 'Past (${split.past.length})'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _list(vm, split.upcoming, upcoming: true),
              _list(vm, split.past, upcoming: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BookingViewModel vm, List<Map<String, dynamic>> items, {required bool upcoming}) {
    final error = vm.appointmentsError;
    final Widget? emptyState = items.isNotEmpty
        ? null
        : vm.isAppointmentsLoading
            ? const LoadingView(message: 'Loading your appointments…')
            : error != null && vm.appointmentsList.isEmpty
                ? ErrorView(
                    title: "Couldn't load your appointments",
                    message: 'Check your connection and try again.',
                    onRetry: vm.fetchAppointments,
                  )
                : EmptyView(
                    icon: upcoming ? Icons.event_available_rounded : Icons.history_rounded,
                    title: upcoming ? 'No upcoming visits' : 'No past visits yet',
                    message: upcoming ? 'When you book a visit, it will show up here.' : null,
                    actionLabel: upcoming ? 'Book a doctor' : null,
                    onAction: upcoming ? () => context.push(AppRoutes.doctors) : null,
                  );
    final showBanner = error != null && vm.appointmentsList.isNotEmpty;

    return RefreshIndicator(
      onRefresh: vm.fetchAppointments,
      child: CustomScrollView(
        // Each tab keeps its own scroll position.
        key: PageStorageKey(upcoming ? 'upcoming' : 'past'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showBanner) SliverToBoxAdapter(child: StaleDataBanner(message: error, onRetry: vm.fetchAppointments)),
          if (emptyState != null)
            SliverFillRemaining(hasScrollBody: false, child: Center(child: emptyState))
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final appt = items[i];
                  final id = appt['id']?.toString() ?? '';
                  return FadeSlideIn(
                    key: ValueKey(id),
                    delay: Duration(milliseconds: 50 * (i < 6 ? i : 6)),
                    child: AppointmentCard(
                      appointment: appt,
                      isUpcoming: upcoming,
                      cancelling: _cancelling.contains(id),
                      onCancel: upcoming ? () => _cancel(appt) : null,
                      onReschedule: upcoming ? () => _reschedule(appt) : null,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
