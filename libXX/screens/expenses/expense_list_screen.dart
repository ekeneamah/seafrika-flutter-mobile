import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/expense.dart';
import 'package:vendor_app/services/expense_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ExpenseCategory? _selectedCategory;
  ExpenseStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    return expenses.where((expense) {
      final matchesSearch = expense.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (expense.notes != null &&
              expense.notes!
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()));
      final matchesCategory =
          _selectedCategory == null || expense.category == _selectedCategory;
      final matchesStatus =
          _selectedStatus == null || expense.status == _selectedStatus;
      final matchesDate =
          (_startDate == null || expense.date.isAfter(_startDate!)) &&
              (_endDate == null || expense.date.isBefore(_endDate!));
      return matchesSearch && matchesCategory && matchesStatus && matchesDate;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('All', null),
                      ...ExpenseCategory.values.map(
                        (category) => _buildCategoryChip(
                          category.toString().split('.').last,
                          category,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All', null),
                      ...ExpenseStatus.values.map(
                        (status) => _buildStatusChip(
                          status.toString().split('.').last,
                          status,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${_startDate.toString().split(' ')[0]} - ${_endDate.toString().split(' ')[0]}'
                        : 'Select Date Range',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Expense>>(
              stream: context.read<ExpenseService>().streamExpenses(
                    category: _selectedCategory,
                    status: _selectedStatus,
                    startDate: _startDate,
                    endDate: _endDate,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return error.ErrorView(
                    message: 'Failed to load expenses',
                    onRetry: () {
                      setState(() {});
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final expenses = _filterExpenses(snapshot.data!);

                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Expenses Found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Expenses will appear here',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          NavigationService.navigateToExpenseDetail(expense.id);
                        },
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(expense.status),
                          child: Icon(
                            _getStatusIcon(expense.status),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(expense.description),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.category.toString().split('.').last,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              expense.date.toString().split(' ')[0],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${expense.amount.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              expense.status.toString().split('.').last,
                              style: TextStyle(
                                color: _getStatusColor(expense.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          NavigationService.navigateToCreateExpense();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryChip(String label, ExpenseCategory? category) {
    final isSelected = category == _selectedCategory;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = selected ? category : null);
        },
      ),
    );
  }

  Widget _buildStatusChip(String label, ExpenseStatus? status) {
    final isSelected = status == _selectedStatus;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedStatus = selected ? status : null);
        },
      ),
    );
  }

  Color _getStatusColor(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return Colors.orange;
      case ExpenseStatus.approved:
        return Colors.green;
      case ExpenseStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return Icons.pending;
      case ExpenseStatus.approved:
        return Icons.check;
      case ExpenseStatus.rejected:
        return Icons.close;
    }
  }
}
