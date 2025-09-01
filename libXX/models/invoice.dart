class Invoice {
  final String id;
  final String customerName;
  final String customerEmail;
  final List<InvoiceItem> items;
  final String? notes;
  final String? bookingId;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy; // User ID who created the invoice
  final String? updatedBy; // User ID who last updated the invoice

  Invoice({
    required this.id,
    required this.customerName,
    required this.customerEmail,
    required this.items,
    this.notes,
    this.bookingId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.updatedBy,
  });

  double get total => items.fold(
        0,
        (sum, item) => sum + (item.unitPrice * item.quantity),
      );
}

class InvoiceItem {
  final String name;
  final String? description;
  final int quantity;
  final double unitPrice;
  final String type; // 'service' or 'product'
  final String? referenceId; // ID of the product or service

  InvoiceItem({
    required this.name,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.type,
    this.referenceId,
  });
}
