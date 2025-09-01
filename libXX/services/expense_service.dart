import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/expense.dart';
import 'package:vendor_app/services/notification_service.dart';

class ExpenseService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  ExpenseService(this._firestore, this._vendorId, this._notificationService);

  // Expense Management
  Stream<List<Expense>> streamExpenses({
    ExpenseCategory? category,
    ExpenseStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query =
        _firestore.collection('vendors').doc(_vendorId).collection('expenses');

    if (category != null) {
      query = query.where('category',
          isEqualTo: category.toString().split('.').last);
    }
    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }
    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: endDate);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Expense.fromMap(
              {...(doc.data() as Map<String, dynamic>? ?? {}), 'id': doc.id}))
          .toList();
    });
  }

  Future<Expense> fetchExpense(String expenseId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('expenses')
        .doc(expenseId)
        .get();

    if (!doc.exists) {
      throw Exception('Expense not found');
    }

    return Expense.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<Expense> createExpense({
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    required String description,
    String? receiptUrl,
    String? notes,
  }) async {
    final docRef = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('expenses')
        .doc();

    final expense = Expense(
      id: docRef.id,
      vendorId: _vendorId,
      amount: amount,
      category: category,
      date: date,
      description: description,
      receiptUrl: receiptUrl,
      status: ExpenseStatus.pending,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await docRef.set(expense.toMap());

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Expense Created',
      message:
          '${expense.description} - \$${expense.amount.toStringAsFixed(2)}',
      data: {
        'type': 'expense',
        'expenseId': expense.id,
      },
    );

    return expense;
  }

  Future<void> updateExpense(
    String expenseId, {
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? description,
    String? receiptUrl,
    String? notes,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };

    if (amount != null) {
      updates['amount'] = amount;
    }
    if (category != null) {
      updates['category'] = category.toString().split('.').last;
    }
    if (date != null) {
      updates['date'] = date;
    }
    if (description != null) {
      updates['description'] = description;
    }
    if (receiptUrl != null) {
      updates['receiptUrl'] = receiptUrl;
    }
    if (notes != null) {
      updates['notes'] = notes;
    }

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('expenses')
        .doc(expenseId)
        .update(updates);
  }

  Future<void> updateExpenseStatus(
    String expenseId,
    ExpenseStatus status, {
    String? approvedBy,
  }) async {
    final updates = {
      'status': status.toString().split('.').last,
      'updatedAt': DateTime.now(),
    };

    if (status == ExpenseStatus.approved) {
      updates['approvedBy'] = approvedBy as Object;
      updates['approvedAt'] = DateTime.now();
    }

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('expenses')
        .doc(expenseId)
        .update(updates);

    // Send notification for status change
    final expense = await fetchExpense(expenseId);
    await _notificationService.sendNotification(
      title: 'Expense Status Updated',
      message: '${expense.description} - ${status.toString().split('.').last}',
      data: {
        'type': 'expense_status',
        'expenseId': expense.id,
      },
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  // Analytics
  Future<Map<String, dynamic>> getExpenseSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query =
        _firestore.collection('vendors').doc(_vendorId).collection('expenses');

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: endDate);
    }

    final snapshot = await query.get();
    final expenses = snapshot.docs
        .map((doc) => Expense.fromMap(
            {...(doc.data() as Map<String, dynamic>? ?? {}), 'id': doc.id}))
        .toList();

    double totalAmount = 0;
    Map<ExpenseCategory, double> categoryTotals = {};
    Map<ExpenseStatus, int> statusCounts = {};

    for (var expense in expenses) {
      totalAmount += expense.amount;
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
      statusCounts[expense.status] = (statusCounts[expense.status] ?? 0) + 1;
    }

    return {
      'totalAmount': totalAmount,
      'categoryTotals': categoryTotals,
      'statusCounts': statusCounts,
      'totalCount': expenses.length,
    };
  }
}
