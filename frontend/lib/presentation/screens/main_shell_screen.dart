import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'patient_list_screen.dart';
import 'invoice_detail_screen.dart';
import 'barcode_scanner_screen.dart';
import 'inventory_list_screen.dart';
import 'expiry_alerts_screen.dart';
import 'receive_stock_screen.dart';
import 'notifications_screen.dart';
import 'vaccine_schedule_screen.dart';
import 'reports_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 1; // Default to Dashboard

  final List<String> _navLabels = [
    'Login',
    'Dashboard',
    'Patients',
    'Invoice Detail',
    'Barcode Scanner',
    'Inventory List',
    'Expiry Alerts',
    'Receive Stock',
    'Notifications',
    'Vaccine Schedule',
    'Reports',
  ];

  final List<String> _navIcons = [
    '🔐',
    '📊',
    '👥',
    '🧾',
    '📷',
    '📦',
    '⚠️',
    '📥',
    '🔔',
    '💉',
    '📈',
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final screens = <Widget>[
      LoginScreen(onLoginSuccess: () => setState(() => _selectedIndex = 1)),
      DashboardScreen(
        onScanTapped: () => setState(() => _selectedIndex = 4),
        onInvoiceTapped: (_) => setState(() => _selectedIndex = 3),
      ),
      PatientListScreen(
        onPatientTapped: (_) => setState(() => _selectedIndex = 3),
      ),
      InvoiceDetailScreen(
        onScanMore: () => setState(() => _selectedIndex = 4),
      ),
      BarcodeScannerScreen(
        onDispensed: () => setState(() => _selectedIndex = 3),
      ),
      const InventoryListScreen(),
      const ExpiryAlertsScreen(),
      const ReceiveStockScreen(),
      const NotificationsScreen(),
      const VaccineScheduleScreen(),
      const ReportsScreen(),
    ];

    if (!isDesktop) {
      return Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex > 4 ? 0 : _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          items: const [
            BottomNavigationBarItem(icon: Text('🔐', style: TextStyle(fontSize: 16)), label: 'Login'),
            BottomNavigationBarItem(icon: Text('📊', style: TextStyle(fontSize: 16)), label: 'Dash'),
            BottomNavigationBarItem(icon: Text('👥', style: TextStyle(fontSize: 16)), label: 'Patients'),
            BottomNavigationBarItem(icon: Text('🧾', style: TextStyle(fontSize: 16)), label: 'Bill'),
            BottomNavigationBarItem(icon: Text('📷', style: TextStyle(fontSize: 16)), label: 'Scan'),
          ],
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
                  children: const [
                    Text('🏥 PrimaCare', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Smart Clinic Operations', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              ...List.generate(_navLabels.length, (idx) {
                return ListTile(
                  leading: Text(_navIcons[idx], style: const TextStyle(fontSize: 18)),
                  title: Text(_navLabels[idx], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  selected: _selectedIndex == idx,
                  selectedTileColor: AppColors.primaryLight,
                  trailing: idx == 6
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                          child: const Text('5', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedIndex = idx);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      );
    }

    // Desktop / Web layout with Sidebar
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
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
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Text('🏥', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('PrimaCare', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                              Text('Smart Clinic System', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _navLabels.length,
                      itemBuilder: (context, idx) {
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
                            leading: Text(_navIcons[idx], style: const TextStyle(fontSize: 16)),
                            title: Text(
                              _navLabels[idx],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                            trailing: idx == 6
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      '5',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : null,
                            onTap: () => setState(() => _selectedIndex = idx),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content Area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}
