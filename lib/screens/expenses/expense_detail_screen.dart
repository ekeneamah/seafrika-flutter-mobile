import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vendor_app/models/expense.dart';
import 'package:vendor_app/services/expense_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Expense? _expense;

  @override
  void initState() {
    super.initState();
    _loadExpense();
  }

  Future<void> _loadExpense() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final expenseService = context.read<ExpenseService>();
      final expense = await expenseService.fetchExpense(widget.expenseId);
      setState(() {
        _expense = expense;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load expense details';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(ExpenseStatus status) async {
    setState(() => _isLoading = true);

    try {
      final expenseService = context.read<ExpenseService>();
      final authService = context.read<AuthService>();
      await expenseService.updateExpenseStatus(
        widget.expenseId,
        status,
        approvedBy: authService.currentUser?.id ?? '',
      );
      await _loadExpense();
    } catch (e) {
      setState(() {
        _error = 'Failed to update status';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final expenseService = context.read<ExpenseService>();
        await expenseService.deleteExpense(widget.expenseId);
        if (mounted) {
          NavigationService.goBack();
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to delete expense';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (_expense != null && _expense!.status == ExpenseStatus.pending)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                NavigationService.navigateToEditExpense(widget.expenseId);
              },
            ),
          if (_expense != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteExpense,
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadExpense,
                )
              : _expense == null
                  ? const Center(child: Text('Expense not found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expense Details',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  'Amount',
                                  '\$${_expense!.amount.toStringAsFixed(2)}',
                                ),
                                _buildInfoRow(
                                  'Category',
                                  _expense!.category.toString().split('.').last,
                                ),
                                _buildInfoRow(
                                  'Date',
                                  _expense!.date.toString().split(' ')[0],
                                ),
                                _buildInfoRow(
                                  'Description',
                                  _expense!.description,
                                ),
                                if (_expense!.notes != null)
                                  _buildInfoRow('Notes', _expense!.notes!),
                                _buildInfoRow(
                                  'Status',
                                  _expense!.status.toString().split('.').last,
                                ),
                                if (_expense!.approvedBy != null)
                                  _buildInfoRow(
                                    'Approved By',
                                    _expense!.approvedBy!,
                                  ),
                                if (_expense!.approvedAt != null)
                                  _buildInfoRow(
                                    'Approved At',
                                    _expense!.approvedAt
                                        .toString()
                                        .split(' ')[0],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_expense!.receiptUrl != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Receipt',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          child: InteractiveViewer(
                                            child: CachedNetworkImage(
                                              imageUrl: _expense!.receiptUrl!,
                                              placeholder: (context, url) =>
                                                  const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: CachedNetworkImage(
                                      imageUrl: _expense!.receiptUrl!,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) =>
                                          const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_expense!.status == ExpenseStatus.pending)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _updateStatus(ExpenseStatus.rejected),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateStatus(ExpenseStatus.approved),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
