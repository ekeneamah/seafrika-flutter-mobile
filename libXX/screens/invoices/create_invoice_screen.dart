import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/invoice.dart';
import 'package:vendor_app/services/invoice_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/common/loading_indicator.dart';
import 'package:vendor_app/services/booking_service.dart';
import 'package:vendor_app/services/customer_service.dart';
import 'package:share_plus/share_plus.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final String? bookingId;
  final String? productId;
  final String? customerId;

  const CreateInvoiceScreen({
    Key? key,
    this.bookingId,
    this.productId,
    this.customerId,
  }) : super(key: key);

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _notesController = TextEditingController();
  List<InvoiceItem> _items = [];
  bool _isLoading = false;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Prioritize loading order: booking > product > customer
      if (widget.bookingId != null) {
        await _loadBookingDetails();
      } else if (widget.productId != null) {
        await _loadProductDetails();
      } else if (widget.customerId != null) {
        await _loadCustomerDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load initial data')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBookingDetails() async {
    final booking =
        await context.read<BookingService>().fetchBooking(widget.bookingId!);
    _customerNameController.text = booking.customerName;
    _customerEmailController.text = booking.customerEmail;
    for (final item in booking.items) {
      _items.add(InvoiceItem(
        name: item.productName,
        description: null,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        type: 'service',
        referenceId: widget.bookingId,
      ));
    }
  }

  Future<void> _loadProductDetails() async {
    final product =
        await context.read<InvoiceService>().getProduct(widget.productId!);
    _items.add(InvoiceItem(
      name: product['name'],
      description: product['description'],
      quantity: 1,
      unitPrice: product['price'],
      type: 'product',
      referenceId: product['id'],
    ));
  }

  Future<void> _loadCustomerDetails() async {
    final customer =
        await context.read<CustomerService>().fetchCustomer(widget.customerId!);
    _customerNameController.text = customer.name;
    _customerEmailController.text = customer.email;
  }

  Future<void> _addItem() async {
    final result = await showDialog<InvoiceItem>(
      context: context,
      builder: (context) => const AddInvoiceItemDialog(),
    );
    if (result != null) {
      setState(() => _items.add(result));
    }
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final invoice = await context.read<InvoiceService>().createInvoice(
            customerName: _customerNameController.text,
            customerEmail: _customerEmailController.text,
            items: _items,
            notes: _notesController.text,
            bookingId: widget.bookingId,
            status: _selectedStatus ?? 'draft',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully')),
        );
        NavigationService.navigateToInvoiceDetail(invoice.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create invoice')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _items.isEmpty
                ? null
                : () {
                    final invoiceText = '''
Invoice Details:
Customer: ${_customerNameController.text}
Email: ${_customerEmailController.text}

Items:
${_items.map((item) => '- ${item.name} (${item.quantity}x) - \$${item.unitPrice * item.quantity}').join('\n')}

Total: \$${_items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity))}
''';
                    Share.share(invoiceText, subject: 'Invoice Details');
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      hintText: 'Enter customer name',
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customerEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Email',
                      hintText: 'Enter customer email',
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  const Text('Items', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  ..._items.map((item) => InvoiceItemCard(
                        item: item,
                        onDelete: () {
                          setState(() => _items.remove(item));
                        },
                      )),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                    ),
                    items: ['draft', 'sent', 'paid', 'overdue']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Add any additional notes',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createInvoice,
                    child: const Text('Create Invoice'),
                  ),
                ],
              ),
            ),
    );
  }
}

class InvoiceItemCard extends StatelessWidget {
  final InvoiceItem item;
  final VoidCallback onDelete;

  const InvoiceItemCard({
    Key? key,
    required this.item,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.name),
        subtitle: Text(item.description ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\$${item.unitPrice * item.quantity}'),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class AddInvoiceItemDialog extends StatefulWidget {
  const AddInvoiceItemDialog({Key? key}) : super(key: key);

  @override
  State<AddInvoiceItemDialog> createState() => _AddInvoiceItemDialogState();
}

class _AddInvoiceItemDialogState extends State<AddInvoiceItemDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  String _selectedType = 'service';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: ['service', 'product']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Unit Price'),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _quantityController.text.isNotEmpty &&
                _priceController.text.isNotEmpty) {
              Navigator.pop(
                context,
                InvoiceItem(
                  name: _nameController.text,
                  description: _descriptionController.text,
                  quantity: int.parse(_quantityController.text),
                  unitPrice: double.parse(_priceController.text),
                  type: _selectedType,
                ),
              );
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
