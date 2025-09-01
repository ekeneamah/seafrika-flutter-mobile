import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/customer.dart';
import 'package:vendor_app/services/notification_service.dart';

class CustomerService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  CustomerService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _notificationService = notificationService;

  Stream<List<Customer>> streamCustomers({
    String? searchQuery,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) {
    Query query = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .orderBy('name')
        .limit(limit);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThanOrEqualTo: searchQuery + '\uf8ff');
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Customer.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<Customer> fetchCustomer(String customerId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .doc(customerId)
        .get();

    if (!doc.exists) {
      throw Exception('Customer not found');
    }

    return Customer.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Future<Customer> createCustomer({
    required String name,
    required String email,
    required String phone,
    String? address,
    String? notes,
  }) async {
    final customerRef = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .doc();

    final now = DateTime.now();
    final customer = Customer(
      id: customerRef.id,
      vendorId: _vendorId,
      name: name,
      email: email,
      phone: phone,
      address: address,
      notes: notes,
      analytics: {
        'totalPurchases': 0,
        'totalSpent': 0.0,
        'lastPurchaseDate': null,
        'averageOrderValue': 0.0,
        'purchaseFrequency': 0.0,
        'customerLifetime': 0.0,
        'engagementScore': 0.0,
      },
      createdAt: now,
      updatedAt: now,
    );

    await customerRef.set(customer.toMap());

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Customer Added',
      message: 'Customer $name has been added to your list',
      data: {'customerId': customer.id},
    );

    return customer;
  }

  Future<void> updateCustomer(
    String customerId, {
    String? name,
    String? email,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final customerRef = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .doc(customerId);

    final customer = await fetchCustomer(customerId);
    final updatedCustomer = customer.copyWith(
      name: name,
      email: email,
      phone: phone,
      address: address,
      notes: notes,
    );

    await customerRef.update(updatedCustomer.toMap());

    // Send notification
    await _notificationService.sendNotification(
      title: 'Customer Updated',
      message: 'Customer ${updatedCustomer.name} has been updated',
      data: {'customerId': customer.id},
    );
  }

  Future<void> deleteCustomer(String customerId) async {
    final customer = await fetchCustomer(customerId);

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .doc(customerId)
        .delete();

    // Send notification
    await _notificationService.sendNotification(
      title: 'Customer Deleted',
      message: 'Customer ${customer.name} has been removed',
      data: {'customerId': customer.id},
    );
  }

  Future<Map<String, dynamic>> getCustomerAnalytics() async {
    final customersSnapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .get();

    final customers = customersSnapshot.docs
        .map((doc) => Customer.fromMap(doc.id, doc.data()))
        .toList();

    double totalSpent = 0;
    int totalCustomers = customers.length;
    int totalPurchases = 0;
    double averageOrderValue = 0;
    double averagePurchaseFrequency = 0;
    double averageCustomerLifetime = 0;
    double averageEngagementScore = 0;

    for (final customer in customers) {
      final analytics = customer.analytics;
      totalSpent += analytics['totalSpent'] as double;
      totalPurchases += analytics['totalPurchases'] as int;
      averageOrderValue += analytics['averageOrderValue'] as double;
      averagePurchaseFrequency += analytics['purchaseFrequency'] as double;
      averageCustomerLifetime += analytics['customerLifetime'] as double;
      averageEngagementScore += analytics['engagementScore'] as double;
    }

    if (totalCustomers > 0) {
      averageOrderValue /= totalCustomers;
      averagePurchaseFrequency /= totalCustomers;
      averageCustomerLifetime /= totalCustomers;
      averageEngagementScore /= totalCustomers;
    }

    return {
      'totalCustomers': totalCustomers,
      'totalSpent': totalSpent,
      'totalPurchases': totalPurchases,
      'averageOrderValue': averageOrderValue,
      'averagePurchaseFrequency': averagePurchaseFrequency,
      'averageCustomerLifetime': averageCustomerLifetime,
      'averageEngagementScore': averageEngagementScore,
      'topCustomers': (() {
        final sortedCustomers = customers.toList();
        sortedCustomers.sort((a, b) => (b.analytics['totalSpent'] as double)
            .compareTo(a.analytics['totalSpent'] as double));
        return sortedCustomers
            .take(5)
            .map((c) => {
                  'id': c.id,
                  'name': c.name,
                  'totalSpent': c.analytics['totalSpent'],
                  'totalPurchases': c.analytics['totalPurchases'],
                  'engagementScore': c.analytics['engagementScore'],
                })
            .toList();
      })(),
    };
  }

  Future<void> updateCustomerAnalytics(
    String customerId, {
    required double purchaseAmount,
    required DateTime purchaseDate,
  }) async {
    final customerRef = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .doc(customerId);

    final customer = await fetchCustomer(customerId);
    final analytics = customer.analytics;

    final totalPurchases = (analytics['totalPurchases'] as int) + 1;
    final totalSpent = (analytics['totalSpent'] as double) + purchaseAmount;
    final averageOrderValue = totalSpent / totalPurchases;
    final customerLifetime =
        DateTime.now().difference(customer.createdAt).inDays / 365;
    final purchaseFrequency =
        totalPurchases / (customerLifetime > 0 ? customerLifetime : 1);
    final engagementScore =
        (totalSpent * 0.4 + totalPurchases * 0.3 + purchaseFrequency * 0.3) /
            100;

    final newAnalytics = {
      'totalPurchases': totalPurchases,
      'totalSpent': totalSpent,
      'lastPurchaseDate': purchaseDate,
      'averageOrderValue': averageOrderValue,
      'purchaseFrequency': purchaseFrequency,
      'customerLifetime': customerLifetime,
      'engagementScore': engagementScore,
    };

    await customerRef.update({
      'analytics': newAnalytics,
      'updatedAt': DateTime.now(),
    });
  }
}
