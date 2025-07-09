import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/purchase_order.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/purchase_order_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/widgets/supplier_selection_dialog.dart';
import 'package:vendor_app/services/product_service.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  final String? orderId;

  const CreatePurchaseOrderScreen({super.key, this.orderId});

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _expectedDeliveryDateController = TextEditingController();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();

  String? _selectedSupplierId;
  String? _selectedSupplierName;
  List<PurchaseOrderItem> _items = [];
  bool _isLoading = false;
  bool _isEditing = false;
  PurchaseOrder? _existingOrder;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.orderId != null;
    if (_isEditing) {
      _loadExistingOrder();
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _notesController.dispose();
    _expectedDeliveryDateController.dispose();
    _productNameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingOrder() async {
    setState(() => _isLoading = true);
    try {
      final purchaseOrderService = context.read<PurchaseOrderService>();
      _existingOrder =
          await purchaseOrderService.fetchPurchaseOrder(widget.orderId!);

      setState(() {
        _selectedSupplierId = _existingOrder!.supplierId;
        _selectedSupplierName = _existingOrder!.supplierName;
        _supplierController.text = _existingOrder!.supplierName;
        _items = List.from(_existingOrder!.items);
        _notesController.text = _existingOrder!.notes ?? '';
        if (_existingOrder!.expectedDeliveryDate != null) {
          _expectedDeliveryDateController.text = _existingOrder!
              .expectedDeliveryDate!
              .toLocal()
              .toString()
              .split(' ')[0];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load purchase order')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectSupplier() async {
    final supplier = await showDialog(
      context: context,
      builder: (context) => const SupplierSelectionDialog(),
    );

    if (supplier != null) {
      setState(() {
        _selectedSupplierId = supplier.id;
        _selectedSupplierName = supplier.name;
        _supplierController.text = supplier.name;
      });
    }
  }

  Future<void> _selectExpectedDeliveryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _expectedDeliveryDateController.text =
            picked.toLocal().toString().split(' ')[0];
      });
    }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) async {
                  if (value.isEmpty) return;
                  final products = await context
                      .read<ProductService>()
                      .searchProducts(value);
                  if (!mounted) return;
                  if (products.isNotEmpty) {
                    final currentContext = context;
                    final selectedProduct = await showDialog<dynamic>(
                      context: currentContext,
                      builder: (dialogContext) => SimpleDialog(
                        title: const Text('Select Product'),
                        children: products
                            .map((product) => SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, product),
                                  child: Text(product.name),
                                ))
                            .toList(),
                      ),
                    );
                    if (!mounted) return;
                    if (selectedProduct != null) {
                      setState(() {
                        _productNameController.text = selectedProduct.name;
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _unitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Unit Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
              final productName = _productNameController.text;
              final quantity = double.tryParse(_quantityController.text) ?? 0.0;
              final unitPrice =
                  double.tryParse(_unitPriceController.text) ?? 0.0;

              if (productName.isNotEmpty && quantity > 0 && unitPrice > 0) {
                setState(() {
                  _items.add(PurchaseOrderItem(
                    productId: DateTime.now().millisecondsSinceEpoch.toString(),
                    productName: productName,
                    quantity: quantity,
                    unitPrice: unitPrice,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double _calculateTotal() {
    return _items.fold(
        0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final purchaseOrderService = context.read<PurchaseOrderService>();
      final totalAmount = _calculateTotal();
      final expectedDeliveryDate =
          _expectedDeliveryDateController.text.isNotEmpty
              ? DateTime.parse(_expectedDeliveryDateController.text)
              : null;

      if (_isEditing) {
        await purchaseOrderService.updatePurchaseOrder(
          widget.orderId!,
          supplierId: _selectedSupplierId,
          supplierName: _selectedSupplierName,
          items: _items,
          totalAmount: totalAmount,
          expectedDeliveryDate: expectedDeliveryDate,
          notes: _notesController.text,
        );
      } else {
        await purchaseOrderService.createPurchaseOrder(
          supplierId: _selectedSupplierId!,
          supplierName: _selectedSupplierName!,
          items: _items,
          totalAmount: totalAmount,
          expectedDeliveryDate: expectedDeliveryDate,
          notes: _notesController.text,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to ${_isEditing ? 'update' : 'create'} purchase order')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: LoadingView(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditing ? 'Edit Purchase Order' : 'Create Purchase Order'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _supplierController,
              decoration: const InputDecoration(
                labelText: 'Supplier',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              readOnly: true,
              onTap: _selectSupplier,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a supplier';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _expectedDeliveryDateController,
              decoration: const InputDecoration(
                labelText: 'Expected Delivery Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _selectExpectedDeliveryDate,
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Items',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              const Center(
                child: Text('No items added yet'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    child: ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '\$${_calculateTotal().toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveOrder,
                  child: Text(_isEditing ? 'Update' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
