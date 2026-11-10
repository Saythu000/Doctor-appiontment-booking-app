import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/success_check.dart';

/// Shown only after the server confirmed the booking.
class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final args = extra is Map<String, dynamic> ? extra : const <String, dynamic>{};
    final name = honestName(args['practitionerName'] as String?);
    final role = honestRole(args['practitionerRole'] as String?);
    final date = (args['date'] as String?)?.trim() ?? '';
    final time = (args['time'] as String?)?.trim() ?? '';
    final isVirtual = args['isVirtual'] as bool? ?? true;
    final intakeShared = args['intakeShared'] == true;

    // This screen replaces the whole stack, so Android back would close the
    // app. Send the user home instead.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SuccessCheck()),
                      const SizedBox(height: AppSpacing.xl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 250),
                        child: Column(
                          children: [
                            Semantics(
                              header: true,
                              liveRegion: true,
                              child: Text(
                                'Your visit is booked',
                                textAlign: TextAlign.center,
                                style: context.text.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'You can see, move or cancel it in My appointments.',
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 350),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DoctorHeader(name: name, role: role, avatarSize: 48),
                              const Divider(height: AppSpacing.xl),
                              SummaryRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Date',
                                value: date.isEmpty ? '--' : date,
                              ),
                              SummaryRow(
                                icon: Icons.schedule_rounded,
                                label: 'Time',
                                value: time.isEmpty ? '--' : time,
                              ),
                              SummaryRow(
                                icon: isVirtual ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                                label: 'Visit type',
                                value: isVirtual ? 'Video visit' : 'In-person visit',
                              ),
                              if (intakeShared)
                                const SummaryRow(
                                  icon: Icons.assignment_turned_in_rounded,
                                  label: 'Symptom summary',
                                  value: 'Shared with your doctor',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: 'View my appointments',
                      icon: Icons.event_note_rounded,
                      onPressed: () {
                        context.go(AppRoutes.home);
                        context.push(AppRoutes.appointments);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.secondary(label: 'Go to Home', onPressed: () => context.go(AppRoutes.home)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
