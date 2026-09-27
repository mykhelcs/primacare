import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/status_badge.dart';

class ExpiryAlertsScreen extends StatelessWidget {
  const ExpiryAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Expiry Alerts (FIFO Watch)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Critical — Expiring within 30 days',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          _buildAlertCard(
            itemName: 'Hepatitis B Vaccine',
            batch: 'Batch #HB-2026-04',
            qty: '12 vials remaining',
            expiry: 'Expires in 18 days (Oct 16, 2026)',
            isCritical: true,
          ),
          _buildAlertCard(
            itemName: 'Tetanus Toxoid 0.5ml',
            batch: 'Batch #TT-2026-02',
            qty: '8 vials remaining',
            expiry: 'Expires in 26 days (Oct 24, 2026)',
            isCritical: true,
          ),
          const SizedBox(height: 20),
          const Text(
            'Upcoming — 31–60 days',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          _buildAlertCard(
            itemName: 'MMR Pediatric',
            batch: 'Batch #MMR-2026-09',
            qty: '15 vials remaining',
            expiry: 'Expires in 42 days (Nov 09, 2026)',
            isCritical: false,
          ),
          _buildAlertCard(
            itemName: 'Amoxicillin Syrup 60ml',
            batch: 'Batch #AMX-2026-15',
            qty: '20 bottles remaining',
            expiry: 'Expires in 55 days (Nov 22, 2026)',
            isCritical: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required String itemName,
    required String batch,
    required String qty,
    required String expiry,
    required bool isCritical,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCritical ? AppColors.dangerLight : AppColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isCritical ? '⚠️' : '⏱️',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$batch · $qty',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  expiry,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCritical ? AppColors.danger : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge.critical(text: isCritical ? 'Urgent' : 'Watch'),
        ],
      ),
    );
  }
}
