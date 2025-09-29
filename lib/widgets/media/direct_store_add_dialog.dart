import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/store.dart';
import '../../services/direct_sell_service.dart';
import '../../providers/service_providers.dart';
import '../../providers/business_context_provider.dart';

/// Dialog for adding media items directly to store inventory
/// Supports both single-store (auto-select) and multi-store (user selection) scenarios
class DirectStoreAddDialog extends ConsumerStatefulWidget {
  final AssetEntity media;
  final String?
      preselectedStoreId; // Optional: if provided, will be preselected
  final String? preselectedStoreName;

  const DirectStoreAddDialog({
    Key? key,
    required this.media,
    this.preselectedStoreId,
    this.preselectedStoreName,
  }) : super(key: key);

  @override
  ConsumerState<DirectStoreAddDialog> createState() =>
      _DirectStoreAddDialogState();
}

class _DirectStoreAddDialogState extends ConsumerState<DirectStoreAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _categoryController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingStores = true;
  List<Store> _availableStores = [];
  Store? _selectedStore;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  /// Load available stores for the current business
  Future<void> _loadStores() async {
    try {
      final businessContext = ref.read(businessContextProvider);
      if (businessContext == null) {
        throw Exception('No business context available');
      }

      final storeService = ref.read(storeServiceProvider);
      await storeService.fetchStores();
      _availableStores = storeService.stores;

      // Auto-select store logic
      if (_availableStores.isEmpty) {
        // No stores available - show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No stores found. Please create a store first.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // If preselected store is provided, try to find and select it
      if (widget.preselectedStoreId != null) {
        _selectedStore = _availableStores.firstWhere(
          (store) => store.id == widget.preselectedStoreId,
          orElse: () => _availableStores.first, // fallback to first store
        );
      } else if (_availableStores.length == 1) {
        // Only one store available - auto-select it
        _selectedStore = _availableStores.first;
      }
      // If multiple stores and no preselection, user will need to select
    } catch (e) {
      debugPrint('Error loading stores: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStores = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStores) {
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 200),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading stores...'),
            ],
          ),
        ),
      );
    }

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(
            maxWidth: 500,
            maxHeight: 700), // Increased height for store selection
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_business, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedStore != null
                        ? 'Add to ${_selectedStore!.name}'
                        : 'Add to Store',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Selection (if multiple stores)
                      if (_availableStores.length > 1) ...[
                        Text(
                          'Select Store *',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Store>(
                          value: _selectedStore,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Choose a store',
                          ),
                          items: _availableStores.map((store) {
                            return DropdownMenuItem<Store>(
                              value: store,
                              child: Row(
                                children: [
                                  Icon(Icons.store,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(store.name)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (Store? newStore) {
                            setState(() {
                              _selectedStore = newStore;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a store';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Store Info Display (if single store or selected)
                      if (_selectedStore != null &&
                          _availableStores.length == 1) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.store, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Adding to: ${_selectedStore!.name}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    if (_selectedStore!.address.isNotEmpty)
                                      Text(
                                        _selectedStore!.address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Product Name
                      TextFormField(
                        controller: _productNameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Product name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Selling Price and Cost Price
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sellingPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Selling Price *',
                                border: OutlineInputBorder(),
                                prefixText: '\$ ',
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Selling price is required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid price';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _costPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Cost Price *',
                                border: OutlineInputBorder(),
                                prefixText: '\$ ',
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Cost price is required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid price';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Quantity and Category
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: const InputDecoration(
                                labelText: 'Quantity *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Quantity is required';
                                }
                                if (int.tryParse(value) == null ||
                                    int.parse(value) < 1) {
                                  return 'Invalid quantity';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _categoryController,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Options
                      Text(
                        'Quick Options',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Auto-name'),
                            onPressed: () {
                              _productNameController.text =
                                  'Product ${DateTime.now().millisecondsSinceEpoch}';
                            },
                          ),
                          ActionChip(
                            label: const Text('Set 40% Margin'),
                            onPressed: () {
                              final costPrice =
                                  double.tryParse(_costPriceController.text);
                              if (costPrice != null) {
                                _sellingPriceController.text =
                                    (costPrice * 1.4).toStringAsFixed(2);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addToStore,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add to Store'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _quickAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Quick Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final directSellService = ref.read(directSellServiceProvider);
      final businessId = ref.read(selectedBusinessIdProvider);
      final businessName = ref.read(selectedBusinessNameProvider);
      final vendorId = ref.read(vendorIdSyncProvider);

      if (businessId == null || businessName == null || vendorId.isEmpty) {
        throw Exception('Business context not properly initialized');
      }

      final request = DirectStoreAddRequest(
        productName: _productNameController.text.trim(),
        productDescription: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        sellingPrice: double.parse(_sellingPriceController.text),
        costPrice: double.parse(_costPriceController.text),
        quantity: int.parse(_quantityController.text),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );

      final result = await directSellService.addMediaToStoreDirectly(
        media: widget.media,
        businessId: businessId,
        businessName: businessName,
        vendorId: vendorId,
        storeId: _selectedStore!.id,
        storeName: _selectedStore!.name,
        request: request,
      );

      if (mounted) {
        Navigator.of(context).pop(result);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Successfully added ${result.quantityAdded} items to ${_selectedStore!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(result.errorMessage ?? 'Failed to add item to store'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _quickAdd() async {
    setState(() => _isLoading = true);

    try {
      final directSellService = ref.read(directSellServiceProvider);
      final businessId = ref.read(selectedBusinessIdProvider);
      final businessName = ref.read(selectedBusinessNameProvider);
      final vendorId = ref.read(vendorIdSyncProvider);

      if (businessId == null || businessName == null || vendorId.isEmpty) {
        throw Exception('Business context not properly initialized');
      }

      // Use default values for quick add
      final result = await directSellService.quickAddMediaToStore(
        media: widget.media,
        businessId: businessId,
        businessName: businessName,
        vendorId: vendorId,
        storeId: _selectedStore!.id,
        storeName: _selectedStore!.name,
        price: 10.0, // Default price
        quantity: 1,
        category: 'Quick Add',
      );

      if (mounted) {
        Navigator.of(context).pop(result);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Quick added ${result.quantityAdded} items to ${_selectedStore!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to quick add item'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Helper function to show the dialog
Future<DirectStoreAddResult?> showDirectStoreAddDialog(
  BuildContext context, {
  required AssetEntity media,
}) {
  return showDialog<DirectStoreAddResult>(
    context: context,
    builder: (context) => DirectStoreAddDialog(
      media: media,
    ),
  );
}
