import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/security_service.dart';
import '../../data/services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/patient_provider.dart';
import '../../data/services/offline_sync_service.dart';
import '../../domain/models/staff_profile.dart';
import '../../domain/models/user_role.dart';
import '../widgets/biometric_unlock_dialog.dart';
import 'dashboard_screen.dart';
import 'patient_list_screen.dart';
import 'invoice_detail_screen.dart';
import 'barcode_scanner_screen.dart';
import 'barcode_catalog_screen.dart';
import 'inventory_list_screen.dart';
import 'expiry_alerts_screen.dart';
import 'receive_stock_screen.dart';
import 'notifications_screen.dart';
import 'vaccine_schedule_screen.dart';
import 'reports_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _selectedIndex = 0; // 0 = Dashboard
  String? _selectedInvoiceId;
  bool _isSessionLocked = false;

  @override
  void initState() {
    super.initState();
    SecurityService().startSessionWatcher(
      onTimeout: () {
        if (mounted && !_isSessionLocked) {
          setState(() => _isSessionLocked = true);
          _showBiometricLockDialog();
        }
      },
    );

    final syncService = OfflineSyncService();
    syncService.registerDefaultHandler((action) async {
      switch (action.type) {
        case SyncActionType.dispenseItem:
          final result = await ref
              .read(openInvoicesProvider.notifier)
              .dispenseBarcode(
                barcode: action.payload['barcode'] as String? ?? '',
                invoiceId: action.payload['invoiceId'] as String? ?? '',
                quantity: (action.payload['quantity'] as num?)?.toInt() ?? 1,
              );
          return result.success;
        case SyncActionType.receiveStock:
          final expiryStr = action.payload['expiryDate'] as String? ?? '';
          final expiryDate = DateTime.tryParse(expiryStr);
          if (expiryDate == null) return false;
          await ref.read(inventoryListProvider.notifier).receiveStock(
                itemId: action.payload['itemId'] as String? ?? '',
                batchNumber: action.payload['batchNumber'] as String? ?? '',
                quantity: (action.payload['quantity'] as num?)?.toInt() ?? 0,
                expiryDate: expiryDate,
              );
          return true;
        case SyncActionType.createPatient:
          await ref.read(patientListProvider.notifier).addPatient(
                fullName: action.payload['fullName'] as String? ?? '',
                dateOfBirth: action.payload['dateOfBirth'] as String?,
                contactNumber: action.payload['contactNumber'] as String?,
                email: action.payload['email'] as String?,
                sex: action.payload['sex'] as String?,
                allergies: action.payload['allergies'] as String?,
                address: action.payload['address'] as String?,
                emergencyContact: action.payload['emergencyContact'] as String?,
              );
          return true;
        case SyncActionType.markPaid:
          return ref.read(openInvoicesProvider.notifier).markInvoicePaid(
                action.payload['invoiceId'] as String? ?? '',
                paymentMethod:
                    action.payload['paymentMethod'] as String? ?? 'Cash',
              );
      }
    });
    unawaited(syncService.restoreQueue());
  }

  void _showBiometricLockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BiometricUnlockDialog(
        onUnlocked: () {
          Navigator.pop(ctx);
          setState(() => _isSessionLocked = false);
          SecurityService().recordUserInteraction();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clinical session securely unlocked via Biometrics!'),
              backgroundColor: AppColors.success,
            ),
          );
        },
        onSignOut: () {
          Navigator.pop(ctx);
          setState(() => _isSessionLocked = false);
          ref.read(authControllerProvider.notifier).signOut();
        },
      ),
    );
  }

  @override
  void dispose() {
    SecurityService().dispose();
    super.dispose();
  }

  final List<String> _navLabels = [
    'Dashboard',
    'Patients',
    'Invoice Detail',
    'Barcode Scanner',
    'Inventory List',
    'QR & Barcodes',
    'Expiry Alerts',
    'Receive Stock',
    'Notifications',
    'Vaccine Schedule',
    'Reports',
  ];

  final List<IconData> _navIcons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.receipt_long_outlined,
    Icons.qr_code_scanner,
    Icons.inventory_2_outlined,
    Icons.qr_code_2,
    Icons.warning_amber_rounded,
    Icons.move_to_inbox_outlined,
    Icons.notifications_none,
    Icons.vaccines_outlined,
    Icons.bar_chart,
  ];

  void _navigateToTab(int idx, UserRole role) {
    if (!role.isTabAccessible(idx)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access Denied: The "${_navLabels[idx]}" screen requires elevated permissions.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _selectedIndex = idx);
  }

  void _openInvoice(String invoiceId) {
    setState(() {
      _selectedInvoiceId = invoiceId;
      _selectedIndex = 2; // Invoice Detail
    });
  }

  void _openScanner({String? forInvoiceId}) {
    setState(() {
      if (forInvoiceId != null) _selectedInvoiceId = forInvoiceId;
      _selectedIndex = 3; // Barcode Scanner
    });
  }

  void _showSwitchBranchModal(StaffProfile? staff) {
    final branches = [
      ClinicTenant.centralBranch(),
      ClinicTenant.northBranch(),
    ];
    final currentCode = staff?.clinic.code ?? 'PC-CENTRAL';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Select Clinic Branch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: branches.map((branch) {
            final isSelected = branch.code == currentCode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected ? AppColors.primaryLight : AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  title: Text(branch.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text('${branch.code} · ${branch.address}', style: const TextStyle(fontSize: 11)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                      : const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    ref.read(authControllerProvider.notifier).switchClinic(branch);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched active branch to ${branch.name}'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showOfflineSyncModal() {
    final syncService = OfflineSyncService();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Offline Sync Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: ListenableBuilder(
          listenable: syncService,
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection: ${syncService.isOnline ? 'Online' : 'Offline'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: syncService.isOnline ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pending queued actions: ${syncService.pendingCount}',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: syncService.isSyncing
                ? null
                : () {
                    syncService.flushPendingQueue();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Checking & flushing offline action queue...')),
                    );
                  },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Flush Queue'),
          ),
        ],
      ),
    );
  }

  void _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to end your clinical session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(currentStaffProfileProvider);
    final userRole = staff?.role ?? UserRole.nurse;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Defense-in-depth: If current role cannot access currently selected tab, revert to Dashboard
    if (!userRole.isTabAccessible(_selectedIndex)) {
      _selectedIndex = 0;
    }

    final openInvoices = ref.watch(openInvoicesProvider).value ?? [];
    final openList = openInvoices.where((inv) => inv.isOpen).toList();
    final activeInvoiceId = _selectedInvoiceId ??
        (openList.isNotEmpty
            ? openList.first.id
            : (openInvoices.isNotEmpty
                ? openInvoices.first.id
                : (!SupabaseService.isInitialized ? 'inv-1' : '')));

    final screens = <Widget>[
      DashboardScreen(
        onScanTapped: () => _openScanner(forInvoiceId: activeInvoiceId),
        onInvoiceTapped: (id) => _openInvoice(id),
        onNavigateTab: (tabIdx) => _navigateToTab(tabIdx, userRole),
        onNewEncounterStarted: (invId) => _openInvoice(invId),
      ),
      PatientListScreen(
        onStartEncounter: (invId) => _openInvoice(invId),
      ),
      InvoiceDetailScreen(
        invoiceId: activeInvoiceId,
        onScanMore: () => _openScanner(forInvoiceId: activeInvoiceId),
      ),
      BarcodeScannerScreen(
        invoiceId: activeInvoiceId,
        onDispensed: () => setState(() => _selectedIndex = 2),
      ),
      const InventoryListScreen(),
      const BarcodeCatalogScreen(),
      const ExpiryAlertsScreen(),
      const ReceiveStockScreen(),
      const NotificationsScreen(),
      const VaccineScheduleScreen(),
      const ReportsScreen(),
    ];

    if (!isDesktop) {
      // Mobile-First Scaffold with Bottom Navigation Bar and More Drawer
      return Listener(
        onPointerDown: (_) => SecurityService().recordUserInteraction(),
        child: Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
          bottomNavigationBar: Builder(
            builder: (scaffoldContext) {
              return BottomNavigationBar(
                currentIndex: _selectedIndex <= 3 ? _selectedIndex : 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textSecondary,
                onTap: (idx) {
                  if (idx == 3) {
                    _openScanner(forInvoiceId: _selectedInvoiceId);
                  } else if (idx == 4) {
                    Scaffold.of(scaffoldContext).openDrawer();
                  } else {
                    _navigateToTab(idx, userRole);
                  }
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_outlined),
                    activeIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_outline),
                    activeIcon: Icon(Icons.people),
                    label: 'Patients',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    activeIcon: Icon(Icons.receipt_long),
                    label: 'Bill',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.qr_code_scanner),
                    activeIcon: Icon(Icons.qr_code_scanner),
                    label: 'Scan',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.menu),
                    activeIcon: Icon(Icons.menu_open),
                    label: 'More',
                  ),
                ],
              );
            },
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: AppColors.primaryDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/primacare_logo.png',
                          height: 36,
                          fit: BoxFit.contain,
                          semanticLabel: 'PrimaCare',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.accent,
                            radius: 18,
                            child: Icon(
                              staff?.role == UserRole.doctor
                                  ? Icons.medical_services_outlined
                                  : staff?.role == UserRole.admin
                                      ? Icons.admin_panel_settings_outlined
                                      : Icons.local_hospital_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff?.fullName ?? 'Clinical Staff',
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  staff?.email ?? 'nurse@primacare.ph',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ROLE: ${staff?.role.name.toUpperCase() ?? 'NURSE'}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              staff?.clinic.name ?? 'Central Clinic',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Multi-Tenant Clinic Switcher (Admin only)
                if (userRole.canSwitchBranch)
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 20),
                    title: const Text('Switch Branch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(staff?.clinic.code ?? 'PC-CENTRAL', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.swap_horiz, size: 20),
                    onTap: () {
                      Navigator.pop(context);
                      _showSwitchBranchModal(staff);
                    },
                  ),
                // Offline Sync Queue Pill
                ListenableBuilder(
                  listenable: OfflineSyncService(),
                  builder: (context, _) {
                    final syncService = OfflineSyncService();
                    final pending = syncService.pendingCount;
                    final syncing = syncService.isSyncing;
                    final isOnline = syncService.isOnline;

                    final statusText = syncing
                        ? 'Syncing $pending action(s)...'
                        : (isOnline
                            ? 'Online ($pending pending action${pending == 1 ? '' : 's'})'
                            : 'Offline ($pending queued)');
                    final statusColor = syncing
                        ? AppColors.primary
                        : (isOnline && pending == 0
                            ? AppColors.success
                            : AppColors.warning);

                    return ListTile(
                      leading: const Icon(Icons.sync, color: AppColors.primary, size: 20),
                      title: const Text(
                        'Offline Sync Status',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        statusText,
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showOfflineSyncModal();
                      },
                      trailing: IconButton(
                        icon: syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        onPressed: syncing
                            ? null
                            : () {
                                syncService.flushPendingQueue();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Checking & flushing offline action queue...'),
                                  ),
                                );
                              },
                      ),
                    );
                  },
                ),
                const Divider(),
                ...List.generate(_navLabels.length, (idx) {
                  if (!userRole.isTabAccessible(idx)) return const SizedBox.shrink();
                  final isSelected = _selectedIndex == idx;
                  return ListTile(
                    leading: Icon(
                      _navIcons[idx],
                      size: 20,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    title: Text(
                      _navLabels[idx],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.primaryLight,
                    onTap: () {
                      _navigateToTab(idx, userRole);
                      Navigator.pop(context);
                    },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger, size: 20),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleSignOut();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Tablet & Desktop Layout
    return Listener(
      onPointerDown: (_) => SecurityService().recordUserInteraction(),
      child: Scaffold(
        body: Row(
          children: [
            Material(
              color: AppColors.surface,
              child: Container(
                width: 240,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: AppColors.primaryDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/images/primacare_logo.png',
                              height: 38,
                              fit: BoxFit.contain,
                              semanticLabel: 'PrimaCare',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            staff?.fullName ?? 'Clinical Staff',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            staff?.role.name.toUpperCase() ?? 'NURSE',
                            style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _navLabels.length,
                        itemBuilder: (context, idx) {
                          if (!userRole.isTabAccessible(idx)) {
                            return const SizedBox.shrink();
                          }
                          final isActive = _selectedIndex == idx;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isActive ? AppColors.primary : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              selected: isActive,
                              selectedTileColor: AppColors.primaryLight,
                              leading: Icon(
                                _navIcons[idx],
                                size: 18,
                                color: isActive ? AppColors.primary : AppColors.textSecondary,
                              ),
                              title: Text(
                                _navLabels[idx],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                              onTap: () => _navigateToTab(idx, userRole),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    if (userRole.canSwitchBranch)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 18),
                        title: const Text('Switch Branch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: Text(staff?.clinic.code ?? 'PC-CENTRAL', style: const TextStyle(fontSize: 10)),
                        onTap: () => _showSwitchBranchModal(staff),
                      ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.sync, color: AppColors.primary, size: 18),
                      title: const Text('Offline Sync Queue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onTap: _showOfflineSyncModal,
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                      title: const Text('Sign Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                      onTap: _handleSignOut,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: screens,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
