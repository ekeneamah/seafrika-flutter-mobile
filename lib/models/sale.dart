enum SaleStatus {
  pending,
  completed,
  cancelled,
  refunded,
}

class Sale {
  final String id;
  final String vendorId;
  final String inventoryId;
  final String customerId;
  final String customerName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String? bookingId;
  final SaleStatus status;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.vendorId,
    required this.inventoryId,
    required this.customerId,
    required this.customerName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.bookingId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'inventoryId': inventoryId,
      'customerId': customerId,
      'customerName': customerName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
      'bookingId': bookingId,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      vendorId: map['vendorId'] as String,
      inventoryId: map['inventoryId'] as String,
      customerId: map['customerId'] as String,
      customerName: map['customerName'] as String,
      quantity: map['quantity'] as int,
      unitPrice: map['unitPrice'] as double,
      totalAmount: map['totalAmount'] as double,
      bookingId: map['bookingId'] as String?,
      status: SaleStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Sale copyWith({
    String? id,
    String? vendorId,
    String? inventoryId,
    String? customerId,
    String? customerName,
    int? quantity,
    double? unitPrice,
    double? totalAmount,
    String? bookingId,
    SaleStatus? status,
    DateTime? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      inventoryId: inventoryId ?? this.inventoryId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      bookingId: bookingId ?? this.bookingId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 