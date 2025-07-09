import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/sale.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';

class SalesService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  SalesService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _notificationService = notificationService;

  Future<Sale> createSale({
    required String inventoryId,
    required String customerId,
    required String customerName,
    required int quantity,
    required double unitPrice,
    String? bookingId,
  }) async {
    final sale = Sale(
      id: '',
      vendorId: _vendorId,
      inventoryId: inventoryId,
      customerId: customerId,
      customerName: customerName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalAmount: quantity * unitPrice,
      bookingId: bookingId,
      status: SaleStatus.completed,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('sales').add(sale.toMap());
    final createdSale = sale.copyWith(id: docRef.id);

    // Update inventory quantity
    await _firestore.collection('inventory').doc(inventoryId).update({
      'quantity': FieldValue.increment(-quantity),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Sale',
      message: 'Sold $quantity units of inventory item',
      type: NotificationType.system,
      priority: NotificationPriority.medium,
      data: createdSale.toMap(),
    );

    return createdSale;
  }

  Stream<List<Sale>> streamSales({
    String? customerId,
    String? inventoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query =
        _firestore.collection('sales').where('vendorId', isEqualTo: _vendorId);

    if (customerId != null) {
      query = query.where('customerId', isEqualTo: customerId);
    }

    if (inventoryId != null) {
      query = query.where('inventoryId', isEqualTo: inventoryId);
    }

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: endDate);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Sale.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Sale> fetchSale(String saleId) async {
    final doc = await _firestore.collection('sales').doc(saleId).get();
    if (!doc.exists) {
      throw Exception('Sale not found');
    }
    return Sale.fromMap(doc.data()!);
  }

  Future<void> cancelSale(String saleId) async {
    final sale = await fetchSale(saleId);
    if (sale.status != SaleStatus.completed) {
      throw Exception('Only completed sales can be cancelled');
    }

    await _firestore.collection('sales').doc(saleId).update({
      'status': SaleStatus.cancelled.toString(),
    });

    // Restore inventory quantity
    await _firestore.collection('inventory').doc(sale.inventoryId).update({
      'quantity': FieldValue.increment(sale.quantity),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Sale Cancelled',
      message: 'Sale of ${sale.quantity} units has been cancelled',
      type: NotificationType.system,
      priority: NotificationPriority.high,
      data: sale.toMap(),
    );
  }
}
