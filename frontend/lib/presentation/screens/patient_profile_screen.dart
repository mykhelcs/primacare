import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/status_badge.dart';

class PatientProfileScreen extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String dob;
  final String phone;

  const PatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.dob,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Text(
            patientName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Invoices & Care'),
              Tab(text: 'Vaccine Schedule'),
              Tab(text: 'Reminders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Invoices & Dispensation History
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryBox(),
                const SizedBox(height: 16),
                const Text('Recent Invoices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                _buildInvoiceTile('INV-2026-0891', 'Hepatitis B Vaccine + Syringe', '₱2,400.00', 'Open', isPaid: false),
                _buildInvoiceTile('INV-2026-0412', 'Initial Consult + Paracetamol', '₱950.00', 'Paid', isPaid: true),
              ],
            ),

            // Tab 2: Vaccine Schedule
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildScheduleTile('Hepatitis B — Dose 1 (Birth)', '15 May 1990', 'Batch #HB-90-01', true),
                _buildScheduleTile('Hepatitis B — Dose 2 (1 Month)', '16 Jun 1990', 'Batch #HB-90-04', true),
                _buildScheduleTile('Hepatitis B — Dose 3 (Booster)', 'Scheduled for Oct 15, 2026', 'To be allocated (FIFO)', false),
                _buildScheduleTile('Tetanus Toxoid Booster', 'Recommended · Nov 2026', 'Pending visit', false),
              ],
            ),

            // Tab 3: Reminders History
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildReminderTile('Vaccine Booster Reminder', 'Sent Oct 10, 2026 · SMS delivered', true),
                _buildReminderTile('Invoice Statement Follow-up', 'Scheduled for Oct 18, 2026 · SMS pending', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            radius: 22,
            child: Text(
              patientName.substring(0, 1),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('DOB: $dob · $phone', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('Patient ID: $patientId', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTile(String id, String desc, String amount, String status, {required bool isPaid}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              isPaid ? StatusBadge.paid() : StatusBadge.open(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(String vaccine, String date, String batch, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle : Icons.schedule, color: isDone ? AppColors.success : AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vaccine, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$date · $batch', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          isDone ? StatusBadge.paid() : StatusBadge.open(),
        ],
      ),
    );
  }

  Widget _buildReminderTile(String title, String subtitle, bool isDelivered) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(isDelivered ? Icons.mark_email_read : Icons.hourglass_top, color: isDelivered ? AppColors.success : AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          isDelivered ? StatusBadge.paid() : StatusBadge.warning(text: 'Pending'),
        ],
      ),
    );
  }
}
