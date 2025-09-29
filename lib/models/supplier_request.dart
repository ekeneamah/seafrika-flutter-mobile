enum SupplierRequestStatus {
  pending,
  approved,
  rejected,
  completed,
  cancelled,
}

class SupplierRequest {
  final String id;
  final String supplierId;
  final String inventoryId;
  final String productName;
  final int quantity;
  final SupplierRequestStatus status;
  final String? notes;
  final DateTime requestedAt;
  final DateTime? updatedAt;

  SupplierRequest({
    required this.id,
    required this.supplierId,
    required this.inventoryId,
    required this.productName,
    required this.quantity,
    required this.status,
    this.notes,
    required this.requestedAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'inventoryId': inventoryId,
      'productName': productName,
      'quantity': quantity,
      'status': status.toString().split('.').last,
      'notes': notes,
      'requestedAt': requestedAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SupplierRequest.fromMap(Map<String, dynamic> map) {
    return SupplierRequest(
      id: map['id'] ?? '',
      supplierId: map['supplierId'] ?? '',
      inventoryId: map['inventoryId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      status: SupplierRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => SupplierRequestStatus.pending,
      ),
      notes: map['notes'],
      requestedAt: DateTime.parse(map['requestedAt']),
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  SupplierRequest copyWith({
    String? id,
    String? supplierId,
    String? inventoryId,
    String? productName,
    int? quantity,
    SupplierRequestStatus? status,
    String? notes,
    DateTime? requestedAt,
    DateTime? updatedAt,
  }) {
    return SupplierRequest(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      inventoryId: inventoryId ?? this.inventoryId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      requestedAt: requestedAt ?? this.requestedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
