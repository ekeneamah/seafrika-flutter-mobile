import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseOrderStatus {
  draft,
  pending,
  approved,
  processing,
  shipped,
  delivered,
  cancelled
}

class PurchaseOrderItem {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final String? unit;
  final String? notes;

  PurchaseOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unit,
    this.notes,
  });

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unitPrice'] as num).toDouble(),
      unit: map['unit'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'unit': unit,
      'notes': notes,
    };
  }

  PurchaseOrderItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    String? unit,
    String? notes,
  }) {
    return PurchaseOrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String vendorId;
  final String supplierId;
  final String supplierName;
  final String orderNumber;
  final List<PurchaseOrderItem> items;
  final double totalAmount;
  final PurchaseOrderStatus status;
  final DateTime? expectedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final String? notes;
  final String? createdBy;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  PurchaseOrder({
    required this.id,
    required this.vendorId,
    required this.supplierId,
    required this.supplierName,
    required this.orderNumber,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.expectedDeliveryDate,
    this.actualDeliveryDate,
    this.notes,
    this.createdBy,
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] as String,
      vendorId: map['vendorId'] as String,
      supplierId: map['supplierId'] as String,
      supplierName: map['supplierName'] as String,
      orderNumber: map['orderNumber'] as String,
      items: (map['items'] as List<dynamic>)
          .map(
              (item) => PurchaseOrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      status: PurchaseOrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
      ),
      expectedDeliveryDate:
          (map['expectedDeliveryDate'] as Timestamp?)?.toDate(),
      actualDeliveryDate: (map['actualDeliveryDate'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
      createdBy: map['createdBy'] as String?,
      approvedBy: map['approvedBy'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'expectedDeliveryDate': expectedDeliveryDate != null
          ? Timestamp.fromDate(expectedDeliveryDate!)
          : null,
      'actualDeliveryDate': actualDeliveryDate != null
          ? Timestamp.fromDate(actualDeliveryDate!)
          : null,
      'notes': notes,
      'createdBy': createdBy,
      'approvedBy': approvedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }

  PurchaseOrder copyWith({
    String? id,
    String? vendorId,
    String? supplierId,
    String? supplierName,
    String? orderNumber,
    List<PurchaseOrderItem>? items,
    double? totalAmount,
    PurchaseOrderStatus? status,
    DateTime? expectedDeliveryDate,
    DateTime? actualDeliveryDate,
    String? notes,
    String? createdBy,
    String? approvedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      orderNumber: orderNumber ?? this.orderNumber,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
