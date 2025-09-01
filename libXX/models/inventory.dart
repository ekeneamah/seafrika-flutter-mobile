import 'package:cloud_firestore/cloud_firestore.dart';

class Inventory {
  final String id;
  final String? storeId;
  final String productId;
  final String productName;
  final int quantity;
  final int minimumQuantity;
  final double unitPrice;
  final String? location;
  final String? notes;
  final String vendorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? supplierId;
  final String? purchaseOrderId;
  final String? invoiceId;
  final double? costPrice;
  final double? sellingPrice;
  final int? maxDiscount;
  final String? displayImageUrl;

  Inventory({
    required this.id,
    this.storeId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.minimumQuantity,
    required this.unitPrice,
    this.location,
    this.notes,
    required this.vendorId,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.purchaseOrderId,
    this.invoiceId,
    this.costPrice,
    this.sellingPrice,
    this.maxDiscount,
    this.displayImageUrl,
  });

  bool get isLowStock => quantity <= minimumQuantity;

  factory Inventory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Inventory(
      id: doc.id,
      storeId: data['storeId'] as String?,
      productId: data['productId'] as String,
      productName: data['productName'] as String,
      quantity: data['quantity'] as int,
      minimumQuantity: data['minimumQuantity'] as int,
      unitPrice: (data['unitPrice'] as num).toDouble(),
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      vendorId: data['vendorId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      supplierId: data['supplierId'] as String?,
      purchaseOrderId: data['purchaseOrderId'] as String?,
      invoiceId: data['invoiceId'] as String?,
      costPrice: (data['costPrice'] as num?)?.toDouble(),
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble(),
      maxDiscount: data['maxDiscount'] as int?,
      displayImageUrl: data['displayImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (storeId != null) 'storeId': storeId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'minimumQuantity': minimumQuantity,
      'unitPrice': unitPrice,
      'location': location,
      'notes': notes,
      'vendorId': vendorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (supplierId != null) 'supplierId': supplierId,
      if (purchaseOrderId != null) 'purchaseOrderId': purchaseOrderId,
      if (invoiceId != null) 'invoiceId': invoiceId,
      if (costPrice != null) 'costPrice': costPrice,
      if (sellingPrice != null) 'sellingPrice': sellingPrice,
      if (maxDiscount != null) 'maxDiscount': maxDiscount,
      'displayImageUrl': displayImageUrl,
    };
  }

  Inventory copyWith({
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
    double? sellingPrice,
    int? maxDiscount,
    String? displayImageUrl,
  }) {
    return Inventory(
      id: id,
      storeId: storeId,
      productId: productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      vendorId: vendorId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      supplierId: supplierId ?? this.supplierId,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      invoiceId: invoiceId ?? this.invoiceId,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      displayImageUrl: displayImageUrl ?? this.displayImageUrl,
    );
  }
}
