import 'package:cloud_firestore/cloud_firestore.dart';

class CostPriceHistory {
  final String id;
  final String businessInventoryId;
  final String businessId;
  final String productId;
  final String productName;
  final double previousCostPrice;
  final double newCostPrice;
  final double priceChange;
  final double percentageChange;
  final String changeReason;
  final String? supplierId;
  final String? invoiceId;
  final String? purchaseOrderId;
  final int quantityPurchased;
  final String changedBy; // User ID who made the change
  final Map<String, dynamic>? additionalData;
  final DateTime changedAt;
  final String status;

  CostPriceHistory({
    required this.id,
    required this.businessInventoryId,
    required this.businessId,
    required this.productId,
    required this.productName,
    required this.previousCostPrice,
    required this.newCostPrice,
    required this.priceChange,
    required this.percentageChange,
    required this.changeReason,
    this.supplierId,
    this.invoiceId,
    this.purchaseOrderId,
    required this.quantityPurchased,
    required this.changedBy,
    this.additionalData,
    required this.changedAt,
    required this.status,
  });

  factory CostPriceHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CostPriceHistory(
      id: doc.id,
      businessInventoryId: data['businessInventoryId'] ?? '',
      businessId: data['businessId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      previousCostPrice: (data['previousCostPrice'] ?? 0.0).toDouble(),
      newCostPrice: (data['newCostPrice'] ?? 0.0).toDouble(),
      priceChange: (data['priceChange'] ?? 0.0).toDouble(),
      percentageChange: (data['percentageChange'] ?? 0.0).toDouble(),
      changeReason: data['changeReason'] ?? '',
      supplierId: data['supplierId'],
      invoiceId: data['invoiceId'],
      purchaseOrderId: data['purchaseOrderId'],
      quantityPurchased: data['quantityPurchased'] ?? 0,
      changedBy: data['changedBy'] ?? '',
      additionalData: data['additionalData'],
      changedAt: (data['changedAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
    );
  }

  factory CostPriceHistory.fromMap(Map<String, dynamic> data) {
    return CostPriceHistory(
      id: data['id'] ?? '',
      businessInventoryId: data['businessInventoryId'] ?? '',
      businessId: data['businessId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      previousCostPrice: (data['previousCostPrice'] ?? 0.0).toDouble(),
      newCostPrice: (data['newCostPrice'] ?? 0.0).toDouble(),
      priceChange: (data['priceChange'] ?? 0.0).toDouble(),
      percentageChange: (data['percentageChange'] ?? 0.0).toDouble(),
      changeReason: data['changeReason'] ?? '',
      supplierId: data['supplierId'],
      invoiceId: data['invoiceId'],
      purchaseOrderId: data['purchaseOrderId'],
      quantityPurchased: data['quantityPurchased'] ?? 0,
      changedBy: data['changedBy'] ?? '',
      additionalData: data['additionalData'],
      changedAt: data['changedAt'] is Timestamp
          ? (data['changedAt'] as Timestamp).toDate()
          : DateTime.parse(data['changedAt']),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessInventoryId': businessInventoryId,
      'businessId': businessId,
      'productId': productId,
      'productName': productName,
      'previousCostPrice': previousCostPrice,
      'newCostPrice': newCostPrice,
      'priceChange': priceChange,
      'percentageChange': percentageChange,
      'changeReason': changeReason,
      'supplierId': supplierId,
      'invoiceId': invoiceId,
      'purchaseOrderId': purchaseOrderId,
      'quantityPurchased': quantityPurchased,
      'changedBy': changedBy,
      'additionalData': additionalData,
      'changedAt': Timestamp.fromDate(changedAt),
      'status': status,
    };
  }

  CostPriceHistory copyWith({
    String? id,
    String? businessInventoryId,
    String? businessId,
    String? productId,
    String? productName,
    double? previousCostPrice,
    double? newCostPrice,
    double? priceChange,
    double? percentageChange,
    String? changeReason,
    String? supplierId,
    String? invoiceId,
    String? purchaseOrderId,
    int? quantityPurchased,
    String? changedBy,
    Map<String, dynamic>? additionalData,
    DateTime? changedAt,
    String? status,
  }) {
    return CostPriceHistory(
      id: id ?? this.id,
      businessInventoryId: businessInventoryId ?? this.businessInventoryId,
      businessId: businessId ?? this.businessId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      previousCostPrice: previousCostPrice ?? this.previousCostPrice,
      newCostPrice: newCostPrice ?? this.newCostPrice,
      priceChange: priceChange ?? this.priceChange,
      percentageChange: percentageChange ?? this.percentageChange,
      changeReason: changeReason ?? this.changeReason,
      supplierId: supplierId ?? this.supplierId,
      invoiceId: invoiceId ?? this.invoiceId,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      quantityPurchased: quantityPurchased ?? this.quantityPurchased,
      changedBy: changedBy ?? this.changedBy,
      additionalData: additionalData ?? this.additionalData,
      changedAt: changedAt ?? this.changedAt,
      status: status ?? this.status,
    );
  }

  // Helper methods for analytics
  bool get isPriceIncrease => priceChange > 0;
  bool get isPriceDecrease => priceChange < 0;
  bool get isSignificantChange => percentageChange.abs() >= 10.0; // 10% or more

  String get changeType {
    if (isPriceIncrease) return 'increase';
    if (isPriceDecrease) return 'decrease';
    return 'no_change';
  }

  String get formattedPriceChange {
    final prefix = isPriceIncrease ? '+' : '';
    return '${prefix}NGN ${priceChange.toStringAsFixed(2)}';
  }

  String get formattedPercentageChange {
    final prefix = isPriceIncrease ? '+' : '';
    return '${prefix}${percentageChange.toStringAsFixed(1)}%';
  }
}
