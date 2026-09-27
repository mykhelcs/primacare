import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  factory StatusBadge.open() {
    return const StatusBadge(
      label: 'Open',
      backgroundColor: AppColors.primaryLight,
      textColor: AppColors.primary,
    );
  }

  factory StatusBadge.paid() {
    return const StatusBadge(
      label: 'Paid',
      backgroundColor: AppColors.successLight,
      textColor: AppColors.success,
    );
  }

  factory StatusBadge.critical({String text = 'Critical'}) {
    return StatusBadge(
      label: text,
      backgroundColor: AppColors.dangerLight,
      textColor: AppColors.danger,
    );
  }

  factory StatusBadge.warning({String text = 'Warning'}) {
    return StatusBadge(
      label: text,
      backgroundColor: AppColors.warningLight,
      textColor: AppColors.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
