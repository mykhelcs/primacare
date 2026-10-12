import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/security_service.dart';
import '../providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
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
    final activeInvoiceId = _selectedInvoiceId ??
        (openInvoices.isNotEmpty ? openInvoices.first.id : 'inv-1');

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
                    setState(() => _selectedIndex = idx);
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
                // Multi-Tenant Clinic Switcher
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 20),
                  title: const Text('Switch Branch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(staff?.clinic.code ?? 'PC-CENTRAL', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.swap_horiz, size: 20),
                  onTap: () {
                    final current = staff?.clinic.code ?? 'PC-CENTRAL';
                    final target = current == 'PC-CENTRAL'
                        ? ClinicTenant.northBranch()
                        : ClinicTenant.centralBranch();
                    ref.read(authControllerProvider.notifier).switchClinic(target);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched active branch to ${target.name}'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
                // Offline Sync Queue Pill
                ListTile(
                  leading: const Icon(Icons.sync, color: AppColors.primary, size: 20),
                  title: const Text('Offline Sync Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    OfflineSyncService().isOnline
                        ? 'Online (0 pending actions)'
                        : 'Offline (${OfflineSyncService().pendingCount} queued)',
                    style: TextStyle(
                      fontSize: 11,
                      color: OfflineSyncService().isOnline ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () {
                      OfflineSyncService().flushPendingQueue();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Checking & flushing offline action queue...')),
                      );
                    },
                  ),
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
