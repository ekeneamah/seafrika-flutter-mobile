import 'package:vendor_app/models/invoice.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceService {
  final AuthService _authService;
  final FirebaseFirestore _firestore;

  InvoiceService(this._authService, this._firestore);

  Future<Invoice> createInvoice({
    required String customerName,
    required String customerEmail,
    required List<InvoiceItem> items,
    String? notes,
    String? bookingId,
    required String status,
  }) async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser == null) {
      throw Exception('User must be logged in to create an invoice');
    }

    final docRef = _firestore.collection('invoices').doc();
    final invoice = Invoice(
      id: docRef.id,
      customerName: customerName,
      customerEmail: customerEmail,
      items: items,
      notes: notes,
      bookingId: bookingId,
      status: status,
      createdAt: DateTime.now(),
      createdBy: currentUser.id,
    );

    await docRef.set({
      'id': invoice.id,
      'customerName': invoice.customerName,
      'customerEmail': invoice.customerEmail,
      'items': items
          .map((item) => {
                'name': item.name,
                'description': item.description,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'type': item.type,
                'referenceId': item.referenceId,
              })
          .toList(),
      'notes': invoice.notes,
      'bookingId': invoice.bookingId,
      'status': invoice.status,
      'createdAt': invoice.createdAt,
      'createdBy': invoice.createdBy,
    });

    return invoice;
  }

  Future<Map<String, dynamic>> getProduct(String productId) async {
    final doc = await _firestore.collection('products').doc(productId).get();

    if (!doc.exists) {
      throw Exception('Product not found');
    }

    final data = doc.data()!;
    return {
      'id': doc.id,
      'name': data['name'],
      'description': data['description'],
      'price': data['price'],
    };
  }

  Future<List<Invoice>> getInvoices() async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser == null) {
      return [];
    }

    final snapshot = await _firestore
        .collection('invoices')
        .where('createdBy', isEqualTo: currentUser.id)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Invoice(
        id: doc.id,
        customerName: data['customerName'],
        customerEmail: data['customerEmail'],
        items: (data['items'] as List)
            .map((item) => InvoiceItem(
                  name: item['name'],
                  description: item['description'],
                  quantity: item['quantity'],
                  unitPrice: item['unitPrice'],
                  type: item['type'],
                  referenceId: item['referenceId'],
                ))
            .toList(),
        notes: data['notes'],
        bookingId: data['bookingId'],
        status: data['status'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: data['updatedAt'] != null
            ? (data['updatedAt'] as Timestamp).toDate()
            : null,
        createdBy: data['createdBy'],
        updatedBy: data['updatedBy'],
      );
    }).toList();
  }

  Future<Invoice> getInvoice(String invoiceId) async {
    final doc = await _firestore.collection('invoices').doc(invoiceId).get();

    if (!doc.exists) {
      throw Exception('Invoice not found');
    }

    final data = doc.data()!;
    return Invoice(
      id: doc.id,
      customerName: data['customerName'],
      customerEmail: data['customerEmail'],
      items: (data['items'] as List)
          .map((item) => InvoiceItem(
                name: item['name'],
                description: item['description'],
                quantity: item['quantity'],
                unitPrice: item['unitPrice'],
                type: item['type'],
                referenceId: item['referenceId'],
              ))
          .toList(),
      notes: data['notes'],
      bookingId: data['bookingId'],
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  Future<void> updateInvoiceStatus(String invoiceId, String status) async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser == null) {
      throw Exception('User must be logged in to update an invoice');
    }

    await _firestore.collection('invoices').doc(invoiceId).update({
      'status': status,
      'updatedBy': currentUser.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> generateShareLink(String invoiceId) async {
    final doc = await _firestore.collection('invoices').doc(invoiceId).get();

    if (!doc.exists) {
      throw Exception('Invoice not found');
    }

    final shareToken = await _firestore.collection('share_tokens').add({
      'invoiceId': invoiceId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(days: 7)),
    });

    return 'https://vendor-app.com/invoices/$invoiceId?token=${shareToken.id}';
  }

  Stream<List<Invoice>> streamInvoices() async* {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser == null) {
      yield [];
      return;
    }

    yield* _firestore
        .collection('invoices')
        .where('createdBy', isEqualTo: currentUser.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Invoice(
                id: doc.id,
                customerName: data['customerName'],
                customerEmail: data['customerEmail'],
                items: (data['items'] as List)
                    .map((item) => InvoiceItem(
                          name: item['name'],
                          description: item['description'],
                          quantity: item['quantity'],
                          unitPrice: item['unitPrice'],
                          type: item['type'],
                          referenceId: item['referenceId'],
                        ))
                    .toList(),
                notes: data['notes'],
                bookingId: data['bookingId'],
                status: data['status'],
                createdAt: (data['createdAt'] as Timestamp).toDate(),
                updatedAt: data['updatedAt'] != null
                    ? (data['updatedAt'] as Timestamp).toDate()
                    : null,
                createdBy: data['createdBy'],
                updatedBy: data['updatedBy'],
              );
            }).toList());
  }
}
