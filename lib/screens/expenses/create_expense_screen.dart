import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/expense.dart';
import 'package:vendor_app/services/expense_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class CreateExpenseScreen extends StatefulWidget {
  final String? expenseId;

  const CreateExpenseScreen({
    super.key,
    this.expenseId,
  });

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  Expense? _expense;
  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  DateTime _selectedDate = DateTime.now();
  String? _receiptUrl;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _loadExpense();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExpense() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final expenseService = context.read<ExpenseService>();
      final expense = await expenseService.fetchExpense(widget.expenseId!);
      setState(() {
        _expense = expense;
        _amountController.text = expense.amount.toString();
        _descriptionController.text = expense.description;
        _notesController.text = expense.notes ?? '';
        _selectedCategory = expense.category;
        _selectedDate = expense.date;
        _receiptUrl = expense.receiptUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load expense details';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _uploadReceipt() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() => _isLoading = true);

        final storage = FirebaseStorage.instance;
        final ref = storage
            .ref()
            .child('receipts/${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putData(await image.readAsBytes());
        final url = await ref.getDownloadURL();

        setState(() {
          _receiptUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to upload receipt';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final expenseService = context.read<ExpenseService>();
      final amount = double.parse(_amountController.text);

      if (widget.expenseId != null) {
        await expenseService.updateExpense(
          widget.expenseId!,
          amount: amount,
          category: _selectedCategory,
          date: _selectedDate,
          description: _descriptionController.text,
          receiptUrl: _receiptUrl,
          notes: _notesController.text,
        );
      } else {
        await expenseService.createExpense(
          amount: amount,
          category: _selectedCategory,
          date: _selectedDate,
          description: _descriptionController.text,
          receiptUrl: _receiptUrl,
          notes: _notesController.text,
        );
      }

      if (mounted) {
        NavigationService.goBack();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save expense';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseId != null ? 'Edit Expense' : 'Add Expense'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadExpense,
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ExpenseCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: ExpenseCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDate.toString().split(' ')[0],
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _uploadReceipt,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _receiptUrl != null
                              ? 'Receipt Uploaded'
                              : 'Upload Receipt',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                NavigationService.goBack();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveExpense,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
