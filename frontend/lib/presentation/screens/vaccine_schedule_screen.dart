import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/status_badge.dart';

class VaccineScheduleScreen extends StatelessWidget {
  const VaccineScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Vaccine Schedule & Doses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPatientHeader(),
          const SizedBox(height: 16),
          const Text(
            'Vaccination Timeline',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          _buildDoseCard(
            vaccine: 'Hepatitis B — Dose 1 (Birth)',
            date: 'Completed · 15 May 1990',
            batch: 'Batch #HB-90-01',
            isDone: true,
          ),
          _buildDoseCard(
            vaccine: 'Hepatitis B — Dose 2 (1 Month)',
            date: 'Completed · 16 June 1990',
            batch: 'Batch #HB-90-04',
            isDone: true,
          ),
          _buildDoseCard(
            vaccine: 'Hepatitis B — Dose 3 (Booster)',
            date: 'Scheduled · Oct 15, 2026',
            batch: 'To be allocated via FIFO at clinic',
            isDone: false,
          ),
          _buildDoseCard(
            vaccine: 'Influenza (Annual Seasonal)',
            date: 'Recommended · Nov 2026',
            batch: 'Awaiting stock arrival',
            isDone: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
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
            radius: 24,
            child: const Text('EG', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Elena Garcia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              SizedBox(height: 2),
              Text('DOB: 11 Jan 1998 · Female · Primary Care ID: #PC-9801', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard({
    required String vaccine,
    required String date,
    required String batch,
    required bool isDone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.verified : Icons.schedule,
            color: isDone ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vaccine, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(batch, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          isDone ? StatusBadge.paid() : StatusBadge.open(),
        ],
      ),
    );
  }
}
