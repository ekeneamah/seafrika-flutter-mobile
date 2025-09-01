enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

class BookingItem {
  final String? inventoryId;
  final String productName;
  final int quantity;
  final double unitPrice;

  BookingItem({
    this.inventoryId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'inventoryId': inventoryId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory BookingItem.fromMap(Map<String, dynamic> map) {
    return BookingItem(
      inventoryId: map['inventoryId'] as String?,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      unitPrice: map['unitPrice'] as double,
    );
  }
}

class Booking {
  final String id;
  final String vendorId;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final DateTime bookingDate;
  final List<BookingItem> items;
  final BookingStatus status;
  final String? notes;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.vendorId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.bookingDate,
    required this.items,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  double get totalAmount {
    return items.fold(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'bookingDate': bookingDate.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'status': status.toString(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] as String,
      vendorId: map['vendorId'] as String,
      customerId: map['customerId'] as String,
      customerName: map['customerName'] as String,
      customerEmail: map['customerEmail'] as String,
      customerPhone: map['customerPhone'] as String,
      bookingDate: DateTime.parse(map['bookingDate'] as String),
      items: (map['items'] as List)
          .map((item) => BookingItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      status: BookingStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
      ),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Booking copyWith({
    String? id,
    String? vendorId,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    DateTime? bookingDate,
    List<BookingItem>? items,
    BookingStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      bookingDate: bookingDate ?? this.bookingDate,
      items: items ?? this.items,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
