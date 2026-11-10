import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/core/widgets/state_views.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/booking_option_sheets.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_card.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/stale_banner.dart';
import 'package:provider/provider.dart';

/// "Book a visit": the list of doctors. Shown as a tab in the main shell
/// ([isTab] true) and as a pushed page (for example after an intake).
class SelectSpecialistScreen extends StatefulWidget {
  final bool isTab;
  const SelectSpecialistScreen({super.key, this.isTab = false});

  @override
  State<SelectSpecialistScreen> createState() => _SelectSpecialistScreenState();
}

class _SelectSpecialistScreenState extends State<SelectSpecialistScreen> {
  final _search = TextEditingController();
  String? _specialty; // null = all
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BookingViewModel>().fetchSpecialists();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _navArgs(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    return extra is Map<String, dynamic> ? extra : null;
  }

  void _book(BuildContext context, PractitionerRoleBooking doctor, Map<String, dynamic>? navArgs) {
    final doctorArgs = <String, dynamic>{
      'specialist': doctor,
      'name': doctorDisplayName(doctor),
      'role': doctorSpecialty(doctor),
      'imageUrl': doctor.practitionerDetail?.photoUrl ?? '',
    };
    if (navArgs?['intakeCompleted'] == true) {
      // The patient already described their symptoms: go straight to times.
      context.push(AppRoutes.bookingTime, extra: {
        ...doctorArgs,
        'intakeCompleted': true,
        'intakeId': navArgs?['intakeId'],
        'clinicalReport': navArgs?['clinicalReport'],
      });
    } else {
      showBookingOptionsSheet(context, doctorArgs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingViewModel>();
    final navArgs = _navArgs(context);
    final intakeDone = navArgs?['intakeCompleted'] == true;

    final specialties = <String>{
      for (final d in vm.specialists) ...doctorSpecialties(d),
    }.toList()
      ..sort();
    final active = specialties.contains(_specialty) ? _specialty : null;

    final q = _query.trim().toLowerCase();
    final filtered = vm.specialists.where((d) {
      final specs = doctorSpecialties(d).toList();
      if (active != null && !specs.contains(active)) return false;
      if (q.isEmpty) return true;
      return doctorDisplayName(d).toLowerCase().contains(q) || specs.any((s) => s.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTab,
        title: const Text('Book a visit'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: vm.fetchSpecialists,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (intakeDone) const _IntakeReadyBanner(),
                      TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search by name or specialty',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _query = '';
                                  }),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (specialties.isNotEmpty)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                    child: Row(
                      children: [
                        for (final s in [null, ...specialties])
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: ChoiceChip(
                              label: Text(s ?? 'All'),
                              selected: active == s,
                              onSelected: (_) => setState(() => _specialty = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (vm.specialistsError != null && vm.specialists.isNotEmpty)
                SliverToBoxAdapter(
                  child: StaleDataBanner(
                    message: "Couldn't refresh. Showing the last saved list.",
                    onRetry: vm.fetchSpecialists,
                  ),
                ),
              ..._body(context, vm, filtered, navArgs),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    BookingViewModel vm,
    List<PractitionerRoleBooking> filtered,
    Map<String, dynamic>? navArgs,
  ) {
    if (vm.specialists.isEmpty) {
      final Widget view;
      if (vm.isSpecialistsLoading) {
        view = const LoadingView(message: 'Finding doctors…');
      } else if (vm.specialistsError != null) {
        view = ErrorView(
          title: "Couldn't load doctors",
          message: vm.specialistsError,
          onRetry: vm.fetchSpecialists,
        );
      } else {
        view = EmptyView(
          icon: Icons.medical_services_outlined,
          title: 'No doctors available yet',
          message: 'Pull down to check again later.',
          actionLabel: 'Check again',
          onAction: vm.fetchSpecialists,
        );
      }
      return [SliverFillRemaining(hasScrollBody: false, child: view)];
    }
    if (filtered.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.search_off_rounded,
            title: 'No doctors match',
            message: 'Try another name or specialty.',
            actionLabel: 'Clear filters',
            onAction: () => setState(() {
              _search.clear();
              _query = '';
              _specialty = null;
            }),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        sliver: SliverList.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) => FadeSlideIn(
            delay: Duration(milliseconds: 50 * (i < 6 ? i : 6)),
            child: DoctorCard(doctor: filtered[i], onBook: () => _book(context, filtered[i], navArgs)),
          ),
        ),
      ),
    ];
  }
}

class _IntakeReadyBanner extends StatelessWidget {
  const _IntakeReadyBanner();

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: tone.background, borderRadius: AppRadius.mdAll),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: tone.foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Your symptom summary is ready. Choose a doctor to share it with.',
              style: context.text.bodyMedium!.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
