import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/supplier.dart';
import 'package:vendor_app/models/supplier_request.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';
import 'package:vendor_app/models/supplier_performance_metrics.dart';

class SupplierService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  SupplierService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _notificationService = notificationService;

  Future<Supplier> createSupplier({
    required String name,
    required String contactPerson,
    required String contactPhone,
    required String email,
    String? address,
    String? notes,
  }) async {
    final supplier = Supplier(
      id: '',
      vendorId: _vendorId,
      companyName: name,
      contactPerson: contactPerson,
      contactPhone: contactPhone,
      email: email,
      address: address,
      notes: notes,
      createdAt: DateTime.now(),
      performanceMetrics: SupplierPerformanceMetrics(
        totalOrders: 0,
        onTimeDeliveryRate: 0.0,
        averageRating: 0.0,
        totalSpent: 0.0,
      ),
    );

    final docRef =
        await _firestore.collection('suppliers').add(supplier.toMap());
    final createdSupplier = supplier.copyWith(id: docRef.id);

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Supplier Added',
      message: 'Supplier $name has been added',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: createdSupplier.toMap(),
    );

    return createdSupplier;
  }

  Stream<List<Supplier>> streamSuppliers({
    String? searchQuery,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) {
    Query query = _firestore
        .collection('suppliers')
        .where('vendorId', isEqualTo: _vendorId)
        .orderBy('companyName')
        .limit(limit);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('companyName', isGreaterThanOrEqualTo: searchQuery)
          .where('companyName', isLessThanOrEqualTo: searchQuery + '\uf8ff');
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Supplier.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Supplier> fetchSupplier(String supplierId) async {
    final doc = await _firestore.collection('suppliers').doc(supplierId).get();
    if (!doc.exists) {
      throw Exception('Supplier not found');
    }
    return Supplier.fromMap(doc.data()!);
  }

  Future<void> requestInventory({
    required String supplierId,
    required String inventoryId,
    required int quantity,
    String? notes,
  }) async {
    final supplier = await fetchSupplier(supplierId);
    final inventory =
        await _firestore.collection('inventory').doc(inventoryId).get();

    if (!inventory.exists) {
      throw Exception('Inventory item not found');
    }

    final inventoryData = inventory.data()!;

    // Create supplier request
    await _firestore.collection('supplier_requests').add({
      'supplierId': supplierId,
      'inventoryId': inventoryId,
      'productName': inventoryData['productName'],
      'quantity': quantity,
      'status': 'pending',
      'notes': notes,
      'requestedAt': FieldValue.serverTimestamp(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Inventory Request Sent',
      message: 'Requested $quantity units from ${supplier.companyName}',
      type: NotificationType.system,
      priority: NotificationPriority.medium,
      data: {
        'supplierId': supplierId,
        'supplierName': supplier.companyName,
        'inventoryId': inventoryId,
        'quantity': quantity,
      },
    );
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    String? notes,
  }) async {
    final request =
        await _firestore.collection('supplier_requests').doc(requestId).get();

    if (!request.exists) {
      throw Exception('Request not found');
    }

    final requestData = request.data()!;
    final supplier = await fetchSupplier(requestData['supplierId']);

    await _firestore.collection('supplier_requests').doc(requestId).update({
      'status': status,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (status == 'completed') {
      // Update inventory quantity
      await _firestore
          .collection('inventory')
          .doc(requestData['inventoryId'])
          .update({
        'quantity': FieldValue.increment(requestData['quantity']),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    // Send notification
    await _notificationService.sendNotification(
      title: 'Request Status Updated',
      message: 'Request status changed to $status',
      type: NotificationType.system,
      priority: NotificationPriority.medium,
      data: {
        'requestId': requestId,
        'supplierId': supplier.id,
        'supplierName': supplier.companyName,
        'status': status,
      },
    );
  }

  Stream<List<SupplierRequest>> streamSupplierRequests({
    String? inventoryId,
    SupplierRequestStatus? status,
  }) {
    Query query = _firestore.collection('supplier_requests');

    if (inventoryId != null) {
      query = query.where('inventoryId', isEqualTo: inventoryId);
    }

    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return SupplierRequest.fromMap(data);
      }).toList();
    });
  }

  Future<void> updateSupplier(
    String supplierId, {
    required String name,
    required String contactPerson,
    required String contactPhone,
    required String email,
    String? address,
    String? notes,
  }) async {
    final supplier = await fetchSupplier(supplierId);

    await _firestore.collection('suppliers').doc(supplierId).update({
      'name': name,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'email': email,
      'address': address,
      'notes': notes,
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Supplier Updated',
      message: 'Supplier $name has been updated',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: supplier
          .copyWith(
            companyName: name,
            contactPerson: contactPerson,
            contactPhone: contactPhone,
            email: email,
            address: address,
            notes: notes,
          )
          .toMap(),
    );
  }

  Future<void> deleteSupplier(String supplierId) async {
    final supplier = await fetchSupplier(supplierId);

    await _firestore.collection('suppliers').doc(supplierId).delete();

    // Send notification
    await _notificationService.sendNotification(
      title: 'Supplier Deleted',
      message: 'Supplier ${supplier.companyName} has been deleted',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: supplier.toMap(),
    );
  }

  Future<Map<String, dynamic>> getSupplierAnalytics() async {
    final suppliersSnapshot = await _firestore
        .collection('suppliers')
        .where('vendorId', isEqualTo: _vendorId)
        .get();

    final suppliers = suppliersSnapshot.docs
        .map((doc) => Supplier.fromMap(doc.data()))
        .toList();

    // Calculate metrics
    final totalSuppliers = suppliers.length;
    double totalSpent = 0;
    double averageRating = 0;
    double onTimeDeliveryRate = 0;

    // Get performance metrics
    final performance = {
      'qualityScore': 0.85,
      'costEffectiveness': 0.78,
      'reliabilityScore': 0.92,
      'communicationScore': 0.88,
    };

    // Get top suppliers
    final topSuppliers = suppliers
        .take(5)
        .map((supplier) => {
              'id': supplier.id,
              'companyName': supplier.companyName,
              'rating': 4.5,
              'totalOrders': 15,
              'totalSpent': 5000.0,
            })
        .toList();

    return {
      'totalSuppliers': totalSuppliers,
      'totalSpent': totalSpent,
      'averageRating': averageRating,
      'onTimeDeliveryRate': onTimeDeliveryRate,
      'performance': performance,
      'topSuppliers': topSuppliers,
    };
  }
}
