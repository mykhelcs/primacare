import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/inventory_provider.dart';
import '../widgets/status_badge.dart';

class ExpiryAlertsScreen extends ConsumerWidget {
  const ExpiryAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(expiringBatchesProvider);
    final allBatches = batchesAsync.value ?? [];

    final criticalBatches = allBatches.where((b) => b.isCriticalExpiry).toList();
    final upcomingBatches = allBatches
        .where((b) => !b.isCriticalExpiry && b.daysUntilExpiry <= 60 && !b.isExpired)
        .toList();

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
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(expiringBatchesProvider),
        color: AppColors.primary,
        child: batchesAsync.isLoading && allBatches.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  if (criticalBatches.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'No critical batches expiring within 30 days! FIFO compliant.',
                        style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                      ),
                    )
                  else
                    ...criticalBatches.map(
                      (b) => _buildAlertCard(
                        itemName: 'Medication Batch (Item ${b.itemId.length >= 4 ? b.itemId.substring(0, 4) : b.itemId})',
                        batch: 'Batch #${b.batchNumber}',
                        qty: '${b.quantityRemaining} units remaining',
                        expiry: 'Expires in ${b.daysUntilExpiry} days (${b.expiryDate.toString().substring(0, 10)})',
                        isCritical: true,
                      ),
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
                  if (upcomingBatches.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'No upcoming batch expirations in 31–60 days.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...upcomingBatches.map(
                      (b) => _buildAlertCard(
                        itemName: 'Medication Batch (Item ${b.itemId.length >= 4 ? b.itemId.substring(0, 4) : b.itemId})',
                        batch: 'Batch #${b.batchNumber}',
                        qty: '${b.quantityRemaining} units remaining',
                        expiry: 'Expires in ${b.daysUntilExpiry} days (${b.expiryDate.toString().substring(0, 10)})',
                        isCritical: false,
                      ),
                    ),
                ],
              ),
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
