import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/status_badge.dart';

class PatientListScreen extends StatefulWidget {
  final ValueChanged<String>? onPatientTapped;

  const PatientListScreen({super.key, this.onPatientTapped});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _patients = [
    {
      'id': 'p1',
      'name': 'Juan Dela Cruz',
      'dob': '15 May 1990',
      'phone': '+63 917 123 4567',
      'status': '1 Open Invoice · ₱2,400',
      'badge': 'open',
      'initials': 'JD',
      'avatarColor': AppColors.primary,
    },
    {
      'id': 'p2',
      'name': 'Maria Santos',
      'dob': '02 Nov 1985',
      'phone': '+63 928 987 6543',
      'status': 'All invoices settled',
      'badge': 'paid',
      'initials': 'MS',
      'avatarColor': AppColors.success,
    },
    {
      'id': 'p3',
      'name': 'Roberto Lim',
      'dob': '23 Aug 1974',
      'phone': '+63 905 456 7890',
      'status': '1 Open Invoice · ₱3,100',
      'badge': 'open',
      'initials': 'RL',
      'avatarColor': AppColors.primaryDark,
    },
    {
      'id': 'p4',
      'name': 'Elena Garcia',
      'dob': '11 Jan 1998',
      'phone': '+63 919 234 5678',
      'status': 'Vaccine due in 5 days',
      'badge': 'warning',
      'initials': 'EG',
      'avatarColor': AppColors.warning,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddPatientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dobCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dobCtrl,
              decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Contact Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _patients.insert(0, {
                    'id': 'p_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameCtrl.text,
                    'dob': dobCtrl.text.isNotEmpty ? dobCtrl.text : 'Unknown',
                    'phone': phoneCtrl.text.isNotEmpty ? phoneCtrl.text : 'N/A',
                    'status': 'Newly Registered',
                    'badge': 'open',
                    'initials': nameCtrl.text.substring(0, 1).toUpperCase(),
                    'avatarColor': AppColors.primary,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Patient'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Patients Directory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _showAddPatientDialog,
              icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
              label: const Text(
                'New Patient',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patient by name or phone...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                fillColor: AppColors.surface,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _patients.length,
              itemBuilder: (context, index) {
                final patient = _patients[index];
                if (_searchController.text.isNotEmpty &&
                    !patient['name']
                        .toString()
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase())) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    onTap: () => widget.onPatientTapped?.call(patient['id'] as String),
                    leading: CircleAvatar(
                      backgroundColor:
                          (patient['avatarColor'] as Color).withValues(alpha: 0.15),
                      child: Text(
                        patient['initials'] as String,
                        style: TextStyle(
                          color: patient['avatarColor'] as Color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      patient['name'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          'DOB: ${patient['dob']} · ${patient['phone']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (patient['badge'] == 'open')
                              StatusBadge.open()
                            else if (patient['badge'] == 'paid')
                              StatusBadge.paid()
                            else
                              StatusBadge.warning(text: 'Due soon'),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                patient['status'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                  ),
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
