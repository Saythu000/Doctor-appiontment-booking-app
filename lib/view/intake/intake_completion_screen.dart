import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/intake_viewmodel.dart';

class IntakeCompletionScreen extends StatelessWidget {
  const IntakeCompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final intakeVm = Provider.of<IntakeViewModel>(context);
    final report = intakeVm.clinicalReport;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intake Completed'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Success Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Clinical Intake Recorded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: PhiaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Intake #${intakeVm.savedIntakeRecordId ?? 'Saved'} is saved and attached to your profile.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: PhiaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Clinical Summary Card
              if (report != null && report.clinicalOverview != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PhiaColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.summarize_outlined,
                              size: 18, color: PhiaColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Doctor Clinical Note',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: PhiaColors.primary,
                            ),
                          ),
                          const Spacer(),
                          if (report.riskLevel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (report.riskLevel!.toLowerCase() == 'high')
                                    ? PhiaColors.pulseRed.withOpacity(0.12)
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Risk: ${report.riskLevel!.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: (report.riskLevel!.toLowerCase() == 'high')
                                      ? PhiaColors.pulseRed
                                      : Colors.green.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        report.clinicalOverview!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PhiaColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Conversation Turns Saved Confirmation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PhiaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PhiaColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 20, color: PhiaColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${intakeVm.messages.length} conversation turns saved to medical record.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PhiaColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action 1: Book Appointment
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhiaColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                  label: const Text(
                    'Book Doctor Appointment',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    // Navigate to specialist selection for booking
                    Navigator.of(context).pushNamed('/booking_specialist');
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Action 2: Return to Dashboard
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: PhiaColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PhiaColors.textPrimary,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/dashboard',
                      (route) => false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
