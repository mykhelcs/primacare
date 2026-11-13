import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/data/repositories/auth_repository.dart';
import 'package:primacare/data/repositories/inventory_repository.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';
import 'package:primacare/data/repositories/notification_repository.dart';
import 'package:primacare/data/repositories/patient_repository.dart';
import 'package:primacare/domain/models/inventory_item.dart';
import 'package:primacare/domain/models/invoice.dart';
import 'package:primacare/domain/models/notification_item.dart';
import 'package:primacare/domain/models/patient.dart';
import 'package:primacare/domain/models/staff_profile.dart';
import 'package:primacare/domain/models/user_role.dart';
import 'package:primacare/presentation/providers/auth_provider.dart';
import 'package:primacare/presentation/providers/inventory_provider.dart';
import 'package:primacare/presentation/providers/invoice_provider.dart';
import 'package:primacare/presentation/providers/notification_provider.dart';
import 'package:primacare/presentation/providers/patient_provider.dart';
import 'package:primacare/presentation/screens/barcode_catalog_screen.dart';
import 'package:primacare/presentation/screens/dashboard_screen.dart';
import 'package:primacare/presentation/screens/expiry_alerts_screen.dart';
import 'package:primacare/presentation/screens/inventory_list_screen.dart';
import 'package:primacare/presentation/screens/invoice_detail_screen.dart';
import 'package:primacare/presentation/screens/notifications_screen.dart';
import 'package:primacare/presentation/screens/receive_stock_screen.dart';
import 'package:primacare/presentation/screens/reports_screen.dart';
import 'package:primacare/presentation/screens/vaccine_schedule_screen.dart';

class _FixedAuthRepository extends AuthRepository {
  final StaffProfile _profile;
  _FixedAuthRepository(this._profile);

  @override
  bool get isAuthenticated => true;

  @override
  StaffProfile? get activeProfile => _profile;
}

StaffProfile _staffFor(UserRole role) {
  return StaffProfile(
    id: 'user-${role.name}',
    email: '${role.name}@primacare.ph',
    fullName: '${role.name.toUpperCase()} User',
    role: role,
    clinic: ClinicTenant.centralBranch(),
  );
}

Widget _wrapWithRole({
  required UserRole role,
  required Widget child,
  List<InventoryItem>? items,
  List<InventoryBatch>? batches,
  List<Invoice>? invoices,
  List<Patient>? patients,
  List<NotificationItem>? notifications,
}) {
  final invRepo = InventoryRepository(client: null);
  final invoiceRepo = InvoiceRepository(client: null);
  final patRepo = PatientRepository(client: null);
  final notifRepo = NotificationRepository(client: null);

  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      authRepositoryProvider.overrideWithValue(_FixedAuthRepository(_staffFor(role))),
      inventoryRepositoryProvider.overrideWithValue(invRepo),
      invoiceRepositoryProvider.overrideWithValue(invoiceRepo),
      patientRepositoryProvider.overrideWithValue(patRepo),
      notificationRepositoryProvider.overrideWithValue(notifRepo),
      if (batches != null)
        expiringBatchesProvider.overrideWith((ref) async => batches),
      if (items != null)
        inventoryListProvider.overrideWith(() => _FixedInventoryNotifier(items)),
      if (invoices != null)
        openInvoicesProvider.overrideWith(() => _FixedInvoicesNotifier(invoices)),
      if (patients != null)
        patientListProvider.overrideWith(() => _FixedPatientsNotifier(patients)),
      if (notifications != null)
        notificationListProvider.overrideWith(() => _FixedNotificationsNotifier(notifications)),
    ],
    child: MaterialApp(home: child),
  );
}

class _FixedInventoryNotifier extends InventoryListNotifier {
  final List<InventoryItem> _items;
  _FixedInventoryNotifier(this._items);
  @override
  Future<List<InventoryItem>> build() async => _items;
}

class _FixedInvoicesNotifier extends OpenInvoicesNotifier {
  final List<Invoice> _invoices;
  _FixedInvoicesNotifier(this._invoices);
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _FixedPatientsNotifier extends PatientListNotifier {
  final List<Patient> _patients;
  _FixedPatientsNotifier(this._patients);
  @override
  Future<List<Patient>> build() async => _patients;
}

class _FixedNotificationsNotifier extends NotificationListNotifier {
  final List<NotificationItem> _items;
  _FixedNotificationsNotifier(this._items);
  @override
  Future<List<NotificationItem>> build() async => _items;
}

void main() {
  group('Dashboard Cleanup & Modals Tests', () {
    testWidgets('Dashboard removes unnecessary roadmap section and opens StatCard modal', (tester) async {
      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.admin,
        invoices: [
          Invoice(
            id: 'inv-100',
            patientId: 'p-1',
            patientName: 'Juan Dela Cruz',
            status: 'open',
            totalAmount: 500,
            createdAt: DateTime(2026, 11, 13, 10, 30),
          ),
        ],
        patients: [
          const Patient(id: 'p-1', fullName: 'Juan Dela Cruz'),
        ],
        batches: const [],
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      // Unnecessary roadmap section removed
      expect(find.text('Clinic Operational Roadmap & Assurance'), findsNothing);
      expect(find.text('SYSTEM ACTIVE'), findsNothing);

      // Tapping a StatCard opens a summary modal
      await tester.tap(find.text('Unpaid Receivables'));
      await tester.pumpAndSettle();
      expect(find.text('Unpaid Receivables Breakdown'), findsOneWidget);
    });

    testWidgets('ExpiryAlertsScreen opens detail modal when tapping an expiring batch', (tester) async {
      final batch = InventoryBatch(
        id: 'b-1',
        itemId: 'item-1',
        itemName: 'Hepatitis B Pediatric Vaccine',
        batchNumber: 'HB-LOT-01',
        quantityRemaining: 12,
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        receivedDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.nurse,
        items: const [
          InventoryItem(
            id: 'item-1',
            name: 'Hepatitis B Pediatric Vaccine',
            unit: 'vial',
            unitCost: 450,
            category: 'Vaccines',
            totalStock: 12,
          ),
        ],
        batches: [batch],
        child: const ExpiryAlertsScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hepatitis B Pediatric Vaccine'));
      await tester.pumpAndSettle();

      expect(find.text('Batch Expiry Details'), findsOneWidget);
      expect(find.textContaining('HB-LOT-01'), findsWidgets);
    });

    testWidgets('NotificationsScreen opens detail modal when tapping a reminder item', (tester) async {
      final notif = NotificationItem(
        id: 'n-1',
        patientId: 'p-1',
        patientName: 'Maria Santos',
        type: 'vaccine_reminder',
        message: 'Upcoming MMR Booster due next week.',
        scheduledFor: DateTime(2026, 11, 20, 8, 0),
        status: 'pending',
      );

      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.nurse,
        notifications: [notif],
        child: const NotificationsScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maria Santos'));
      await tester.pumpAndSettle();

      expect(find.text('Reminder Details'), findsOneWidget);
      expect(find.text('Upcoming MMR Booster due next week.'), findsOneWidget);
    });

    testWidgets('BarcodeCatalogScreen opens QR preview modal when tapping a catalog item', (tester) async {
      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.nurse,
        items: const [
          InventoryItem(
            id: 'item-1',
            name: 'Paracetamol 500mg Tablets',
            barcode: '4800016552033',
            unit: 'tabs',
            unitCost: 5.5,
            category: 'Pharmaceuticals',
            totalStock: 100,
          ),
        ],
        child: const BarcodeCatalogScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paracetamol 500mg Tablets'));
      await tester.pumpAndSettle();

      expect(find.text('Barcode & QR Label Preview'), findsOneWidget);
    });
  });

  group('RBAC Enforcement Tests', () {
    testWidgets('Dashboard hides Stock In and Cloud Sync for Doctor, shows Cloud Sync only for Admin', (tester) async {
      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.doctor,
        invoices: const [],
        patients: const [],
        batches: const [],
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Stock In'), findsNothing);
      expect(find.byIcon(Icons.cloud_sync), findsNothing);

      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.admin,
        invoices: const [],
        patients: const [],
        batches: const [],
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Stock In'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync), findsOneWidget);
    });

    testWidgets('ReceiveStockScreen and ReportsScreen block unauthorized roles', (tester) async {
      // Doctor blocked from ReceiveStockScreen
      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.doctor,
        items: const [],
        child: const ReceiveStockScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Access Restricted'), findsOneWidget);

      // Nurse blocked from ReportsScreen
      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.nurse,
        invoices: const [],
        items: const [],
        patients: const [],
        batches: const [],
        child: const ReportsScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Access Restricted'), findsOneWidget);
    });

    testWidgets('InvoiceDetailScreen and InventoryListScreen enforce Doctor vs Nurse permissions', (tester) async {
      final openInv = Invoice(
        id: 'inv-rbac-1',
        patientId: 'p-1',
        patientName: 'Juan Dela Cruz',
        status: 'open',
        totalAmount: 500,
        createdAt: DateTime(2026, 11, 13),
      );

      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.doctor,
        invoices: [openInv],
        items: const [],
        child: const InvoiceDetailScreen(invoiceId: 'inv-rbac-1'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Add Service Fee'), findsOneWidget);
      expect(find.text('Dispense Med/Item'), findsNothing);
      expect(find.text('Collect Payment / Settle Invoice'), findsNothing);

      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.doctor,
        items: const [],
        child: const InventoryListScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_box), findsNothing);
    });

    testWidgets('VaccineScheduleScreen hides Record Dose for Doctor', (tester) async {
      await tester.pumpWidget(_wrapWithRole(
        role: UserRole.doctor,
        patients: const [Patient(id: 'p-1', fullName: 'Juan Dela Cruz')],
        invoices: const [],
        items: const [],
        child: const VaccineScheduleScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Record Dose'), findsNothing);
    });
  });
}
