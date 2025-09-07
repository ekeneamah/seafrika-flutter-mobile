import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/team_service.dart';
import 'package:vendor_app/services/user_service.dart';
import 'package:vendor_app/services/direct_sell_service.dart';
import '../services/inventory_service.dart';
import '../services/store_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/product_service.dart';
import '../services/invoice_service.dart';
import '../services/purchase_order_service.dart';
import '../services/order_service.dart';
import '../services/supplier_service.dart';
import '../services/store_inventory_service.dart';
import '../services/business_inventory_service.dart';
import '../services/media_service.dart';
import '../services/share_service.dart';
import '../services/booking_service.dart';
import '../services/permission_service.dart';
import '../services/business_service.dart';
import '../services/integration_service.dart';
import '../services/order_management_service.dart';
import '../services/customer_service.dart';
import '../services/inventory_allocation_service.dart';
import '../models/role.dart';
import '../models/user.dart';
import '../models/permission.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firestoreProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(firestore: ref.watch(firebaseFirestoreProvider));
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(
    firestore: ref.watch(firestoreProvider),
  );
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(
    firestore: ref.watch(firebaseFirestoreProvider),
    analytics: FirebaseAnalytics.instance,
    userId: 'temp_user_id',
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    analytics: ref.watch(analyticsServiceProvider),
  );
});

final vendorIdProvider = FutureProvider<String>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final user = await authService.getCurrentUser(); // async fetch if needed

  if (user == null) {
    print('Vendor ID: no user');
    return '';
  }

  final vendorId = user.vendorId;
  if (vendorId.isEmpty) {
    print('Vendor ID: empty');
    return '';
  }

  print('Vendor ID: $vendorId');
  return vendorId;
});

final vendorIdSyncProvider = Provider<String>((ref) {
  return ref.watch(vendorIdProvider).value ?? '';
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    firestore: ref.watch(firebaseFirestoreProvider),
    firestoreService: ref.watch(firestoreProvider),
    analytics: ref.watch(analyticsServiceProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
  );
});

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(
    firestore: ref.watch(firebaseFirestoreProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final storeServiceProvider = Provider<StoreService>((ref) {
  final businessId = ref.watch(selectedBusinessIdProvider);
  return StoreService(
    ref.watch(firebaseFirestoreProvider),
    ref.watch(vendorIdSyncProvider),
    ref.watch(notificationServiceProvider),
    businessId ?? '', // Pass empty string if no business selected
  );
});

final storeInventoryServiceProvider = Provider<StoreInventoryService>((ref) {
  return StoreInventoryService();
});

final businessInventoryServiceProvider = Provider<BusinessInventoryService>((ref) {
  return BusinessInventoryService();
});

final directSellServiceProvider = Provider<DirectSellService>((ref) {
  return DirectSellService(
    productService: ref.watch(productServiceProvider),
    businessInventoryService: ref.watch(businessInventoryServiceProvider),
    storeInventoryService: ref.watch(storeInventoryServiceProvider),
    mediaService: ref.watch(mediaServiceProvider),
  );
});

// Order Service Provider
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(
    firestore: ref.watch(firebaseFirestoreProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService(
    firestore: ref.watch(firestoreProvider),
  );
});

final invoiceServiceProvider = Provider<InvoiceService>((ref) {
  return InvoiceService(
    ref.watch(authServiceProvider),
    ref.watch(firebaseFirestoreProvider),
  );
});

final purchaseOrderServiceProvider = Provider<PurchaseOrderService>((ref) {
  return PurchaseOrderService(
    ref.watch(firebaseFirestoreProvider),
    ref.watch(vendorIdSyncProvider),
    ref.watch(notificationServiceProvider),
  );
});

final supplierServiceProvider = Provider<SupplierService>((ref) {
  return SupplierService(
    firestore: ref.watch(firebaseFirestoreProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService(analytics: ref.watch(analyticsServiceProvider));
});

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService(
    firestore: ref.watch(firebaseFirestoreProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(
    firestore: ref.watch(firebaseFirestoreProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final roleProvider = StreamProvider.autoDispose<List<Role>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('roles').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => Role.fromMap(doc.data())).toList();
  });
});

final userProvider = StreamProvider.autoDispose<List<User>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return userService.streamUsers();
});

final permissionProvider = StreamProvider.autoDispose<List<Permission>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('permissions').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => Permission.fromMap(doc.data())).toList();
  });
});

final storeRolesProvider =
    FutureProvider.family<Map<String, List<Role>>, String>((ref, userId) async {
  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final storeRolesData = userDoc.data()?['storeRoles'] as Map<String, dynamic>?;

  if (storeRolesData == null) {
    return {};
  }

  return storeRolesData.map(
    (storeId, roles) => MapEntry(
      storeId,
      (roles as List<dynamic>)
          .map((roleName) => Role(
              id: storeId + '_' + roleName, name: roleName, permissions: []))
          .toList(),
    ),
  );
});

final userServiceProvider = Provider<UserService>((ref) {
  final businessId = ref.watch(authServiceProvider).currentUser?.businessId ?? '';
  return UserService(
    firestore: ref.watch(firebaseFirestoreProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
    businessId: businessId,
  );
});

final teamServiceProvider = Provider<TeamService>((ref) {
  return TeamService(
    firestore: ref.watch(firebaseFirestoreProvider),
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final businessServiceProvider = Provider<BusinessService>((ref) {
  return BusinessService();
});

final integrationServiceProvider = Provider<IntegrationService?>((ref) {
  final businessId = ref.watch(selectedBusinessIdProvider);
  if (businessId == null) {
    return null; // Return null when no business is selected
  }
  return IntegrationService(
    firestore: ref.watch(firebaseFirestoreProvider),
    businessId: businessId,
  );
});

final orderManagementServiceProvider = Provider<OrderManagementService>((ref) {
  return OrderManagementService(
    vendorId: ref.watch(vendorIdSyncProvider),
  );
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(
    firestore: FirebaseFirestore.instance,
    vendorId: ref.watch(vendorIdSyncProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final inventoryAllocationServiceProvider = Provider<InventoryAllocationService>((ref) {
  return InventoryAllocationService();
});


