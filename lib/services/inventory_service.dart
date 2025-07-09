import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/inventory.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:flutter/foundation.dart';

class InventoryService extends ChangeNotifier {
  final FirebaseFirestore firestore;
  final String vendorId;
  final NotificationService notificationService;

  InventoryService({
    required this.firestore,
    required this.vendorId,
    required this.notificationService,
  }) {
    if (vendorId.isEmpty) {
      throw Exception('Vendor ID cannot be empty');
    }
    print('Vendor ID: $vendorId');
  }

  String get currentVendorId => vendorId;

  CollectionReference<Map<String, dynamic>> get _inventoryCollection =>
      firestore.collection('vendors').doc(vendorId).collection('inventory');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamInventory({
    String searchQuery = '',
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    String? storeId,
    int limit = 10,
  }) {
    Query<Map<String, dynamic>> query = _inventoryCollection;

    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    }

    if (searchQuery.isNotEmpty) {
      query = query
          .where('productName', isGreaterThanOrEqualTo: searchQuery)
          .where('productName', isLessThanOrEqualTo: searchQuery + '\uf8ff');
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.limit(limit).snapshots();
  }

  Future<Inventory?> getInventoryById(String id) async {
    final doc = await _inventoryCollection.doc(id).get();
    if (!doc.exists) return null;
    return Inventory.fromFirestore(doc);
  }

  Future<void> createInventory({
    String? storeId,
    required String productId,
    required String productName,
    required int quantity,
    required int minimumQuantity,
    required double unitPrice,
    String? location,
    String? notes,
    String? supplierId,
    String? purchaseOrderId,
    String? invoiceId,
    double? costPrice,
    double? sellingPrice, // Added
    int? maxDiscount, // Added
  }) async {
    final inventory = Inventory(
      id: '',
      storeId: storeId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      minimumQuantity: minimumQuantity,
      unitPrice: unitPrice,
      location: location,
      vendorId: vendorId,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      supplierId: supplierId,
      purchaseOrderId: purchaseOrderId,
      invoiceId: invoiceId,
      costPrice: costPrice,
      sellingPrice: sellingPrice, // Added
      maxDiscount: maxDiscount, // Added
    );

    await _inventoryCollection.add(inventory.toMap());
  }

  Future<Inventory> fetchInventory(String inventoryId) async {
    print('Fetching inventory item: $vendorId');
    final doc = await firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('inventory')
        .doc(inventoryId)
        .get();

    if (!doc.exists) {
      throw Exception('Inventory item not found');
    }

    return Inventory.fromFirestore(doc);
  }

  Future<void> updateInventory(
    String inventoryId, {
    String? productName,
    int? quantity,
    int? minimumQuantity,
    double? unitPrice,
    String? location,
    String? notes,
    String? supplierId,
    String? purchaseOrderId,
    String? invoiceId,
    double? costPrice,
    double? sellingPrice, // Added
    int? maxDiscount, // Added
  }) async {
    final inventoryRef = firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('inventory')
        .doc(inventoryId);

    final inventory = await fetchInventory(inventoryId);
    final updatedInventory = inventory.copyWith(
      productName: productName,
      quantity: quantity,
      minimumQuantity: minimumQuantity,
      unitPrice: unitPrice,
      location: location,
      notes: notes,
      supplierId: supplierId,
      purchaseOrderId: purchaseOrderId,
      invoiceId: invoiceId,
      costPrice: costPrice,
      sellingPrice: sellingPrice, // Added
      maxDiscount: maxDiscount, // Added
    );

    await inventoryRef.update(updatedInventory.toMap());

    // Send notification if quantity is below minimum
    if (updatedInventory.isLowStock) {
      await notificationService.sendNotification(
        title: 'Low Stock Alert',
        message: '${updatedInventory.productName} is running low on stock',
        data: {
          'type': 'inventory',
          'inventoryId': inventory.id,
          'productId': inventory.productId,
        },
      );
    }
  }

  Future<void> deleteInventory(String inventoryId) async {
    final inventory = await fetchInventory(inventoryId);

    await firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('inventory')
        .doc(inventoryId)
        .delete();

    // Send notification
    await notificationService.sendNotification(
      title: 'Inventory Item Deleted',
      message: '${inventory.productName} has been removed from inventory',
      data: {
        'type': 'inventory',
        'inventoryId': inventory.id,
        'productId': inventory.productId,
      },
    );
  }

  Future<Map<String, dynamic>> getInventoryAnalytics() async {
    final inventorySnapshot = await firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('inventory')
        .get();

    final inventory = inventorySnapshot.docs
        .map((doc) => Inventory.fromFirestore(doc))
        .toList();

    int totalItems = inventory.length;
    int lowStockItems = inventory.where((item) => item.isLowStock).length;
    double totalValue = inventory.fold(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );

    return {
      'totalItems': totalItems,
      'lowStockItems': lowStockItems,
      'totalValue': totalValue,
      'lowStockItemsList': inventory
          .where((item) => item.isLowStock)
          .map((item) => {
                'id': item.id,
                'productName': item.productName,
                'quantity': item.quantity,
                'minimumQuantity': item.minimumQuantity,
              })
          .toList(),
    };
  }

  Future<void> sellInventory(
    String inventoryId, {
    required int quantity,
    required double price,
    required String customerId,
  }) async {
    final inventory = await fetchInventory(inventoryId);
    if (inventory.quantity < quantity) {
      throw Exception('Insufficient stock');
    }

    final batch = firestore.batch();
    final inventoryRef = firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('inventory')
        .doc(inventoryId);

    // Update inventory quantity
    batch.update(inventoryRef, {
      'quantity': FieldValue.increment(-quantity),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Record the sale
    final saleRef = firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('inventory')
        .doc(inventoryId)
        .collection('sales')
        .doc();
    batch.set(saleRef, {
      'quantity': quantity,
      'price': price,
      'customerId': customerId,
      'date': FieldValue.serverTimestamp(),
      'type': 'sale',
    });

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getInventoryHistory(
      String inventoryId) async {
    final snapshot = await firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('inventory')
        .doc(inventoryId)
        .collection('history')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'type': data['type'],
        'quantity': data['quantity'],
        'description': data['description'],
        'date': (data['date'] as Timestamp).toDate(),
      };
    }).toList();
  }
}
