/// A screen for creating or editing inventory items in the system.
///
/// This screen allows users to:
/// - Select or create a product
/// - Set quantity and pricing information
/// - Add purchase details (invoice, purchase order, supplier)
/// - Specify location and additional notes
///
/// The screen supports both creation of new inventory items and editing
/// of existing ones, with appropriate validation and error handling.
///
/// Features:
/// - Modern UI with animations and transitions
/// - Form validation
/// - Image preview for products
/// - Integration with purchase orders and invoices
/// - Supplier management
/// - Location tracking

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart' as theme;
import 'package:vendor_app/models/inventory.dart';
import 'package:vendor_app/models/business_inventory.dart';
import 'package:vendor_app/models/invoice.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/models/purchase_order.dart';
import 'package:vendor_app/models/supplier.dart';
import 'package:vendor_app/services/inventory_service.dart';
import 'package:vendor_app/services/business_inventory_service.dart';
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/services/store_service.dart' as store_service;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';
import 'package:vendor_app/utils/business_validation_helper.dart';

class CreateInventoryScreen extends ConsumerStatefulWidget {
  final Inventory? inventory;
  final Product? prefilledProduct;

  const CreateInventoryScreen({
    Key? key,
    this.inventory,
    this.prefilledProduct,
  }) : super(key: key);

  @override
  ConsumerState<CreateInventoryScreen> createState() =>
      _CreateInventoryScreenState();
}

class _CreateInventoryScreenState extends ConsumerState<CreateInventoryScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minimumQuantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _purchaseOrderNumberController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final Set<String> _selectedProductIds = {};

  bool _isLoading = false;
  bool _isEditing = false;
  Inventory? _inventory;
  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedProductImage;
  String? _selectedCategory;
  String? _selectedUnit;
  String? _selectedLocation;
  String? _selectedNotes;
  String? _selectedInvoiceId;
  String? _selectedPurchaseOrderId;
  String? _selectedSupplierId;
  int _quantity = 0;
  int _minimumQuantity = 0;
  double _unitPrice = 0.0;
  double _costPrice = 0.0;
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _isEditing = widget.inventory != null;
    _initializeAnimations();
    _validateBusinessSelection();

    if (_isEditing) {
      _loadInventory();
    } else {
      _prefillProductDetails();
      _startAnimations();
    }
  }

  /// Validates that business is selected, redirects if not
  Future<void> _validateBusinessSelection() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await BusinessValidationHelper.validateBusinessSelection(context);
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimations() {
    _fadeController?.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController?.forward();
      setState(() {
        _isInitialized = true;
      });
    });
  }

  void _prefillProductDetails() {
    if (widget.prefilledProduct != null) {
      final product = widget.prefilledProduct!;
      setState(() {
        _selectedProductId = product.id;
        _selectedProductName = product.name;
        _selectedProductImage = product.displayImageUrl ?? (product.images.isNotEmpty ? product.images.first : null);
        _selectedCategory = product.category;
        _unitPrice = product.price;
        _costPrice = product.price; // Default cost price to selling price
        _minimumQuantity = product.minQuantity;
        _quantity = product.stock; // Set current stock as quantity
        
        // Populate form controllers
        _productNameController.text = product.name;
        _quantityController.text = product.stock.toString(); // Add current quantity
        _unitPriceController.text = product.price.toString();
        _costPriceController.text = product.price.toString();
        _minimumQuantityController.text = product.minQuantity.toString();
      });
    }
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _productNameController.dispose();
    _quantityController.dispose();
    _minimumQuantityController.dispose();
    _unitPriceController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _invoiceNumberController.dispose();
    _purchaseOrderNumberController.dispose();
    _costPriceController.dispose();
    _supplierController.dispose();
    _sellingPriceController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final inventory = await ref
          .read(inventoryServiceProvider)
          .fetchInventory(widget.inventory!.id!);

      setState(() {
        _inventory = inventory;
        _selectedProductId = inventory.productId;
        _selectedProductName = inventory.productName;
        _quantity = inventory.quantity;
        _minimumQuantity = inventory.minimumQuantity;
        _unitPrice = inventory.unitPrice;
        _selectedLocation = inventory.location;
        _selectedNotes = inventory.notes;
        _productNameController.text = inventory.productName;
        _quantityController.text = inventory.quantity.toString();
        _minimumQuantityController.text = inventory.minimumQuantity.toString();
        _unitPriceController.text = inventory.unitPrice.toString();
        _locationController.text = inventory.location ?? '';
        _notesController.text = inventory.notes ?? '';
      });

      _startAnimations();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to load inventory item', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? theme.AppTheme.secondary : theme.AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildModernCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.AppTheme.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.AppTheme.earthLight.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.AppTheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: theme.AppTheme.earth.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _showProductSelectionDialog() async {
    final Product? selectedProduct = await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.AppTheme.glass,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: theme.AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Product',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.AppTheme.earth),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Product List
              Expanded(
                child: StreamBuilder<List<Product>>(
                  stream: ref.watch(productServiceProvider).streamProducts(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final products = snapshot.data!;
                    if (products.isEmpty) {
                      return Center(
                        child: Text(
                          'No products found',
                          style: TextStyle(
                            color: theme.AppTheme.earth,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final isSelected =
                            _selectedProductIds.contains(product.id);
                        return ListTile(
                          leading: product.images.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: product.images[0],
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.AppTheme.earthLight
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: theme.AppTheme.earth,
                                    size: 24,
                                  ),
                                ),
                          title: Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'NGN ${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.AppTheme.earth,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, product);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ));

    if (selectedProduct != null) {
      setState(() {
        _selectedProductIds.clear();
        _selectedProductIds.add(selectedProduct.id);
        _selectedProductId = selectedProduct.id;
        _selectedProductName = selectedProduct.name;
        _selectedProductImage = selectedProduct.displayImageUrl ?? 
            (selectedProduct.images.isNotEmpty ? selectedProduct.images[0] : null);
        _selectedCategory = selectedProduct.category;
        _selectedUnit = selectedProduct.unit;

        // Update quantity and unit price - always use the product's actual stock quantity
        _quantityController.text = selectedProduct.stock.toString();
        _unitPriceController.text = selectedProduct.price.toStringAsFixed(2);
      });
    }
  }

  Future<void> _saveInventory() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please correct the errors in the form', isError: true);
      return;
    }

    if (_selectedProductId == null || _selectedProductName == null) {
      _showSnackBar('Please select a product first', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Get business context for business inventory creation
      final businessContext = ref.read(businessContextProvider);
      if (businessContext == null) {
        _showSnackBar('No business selected. Please select a business first.', isError: true);
        return;
      }

      final businessInventoryService = BusinessInventoryService();

      if (_isEditing && widget.inventory != null) {
        // For editing, still use the old inventory service for now
        // TODO: Update this when business inventory editing is implemented
        final inventoryService = ref.read(inventoryServiceProvider);
        await inventoryService.updateInventory(
          widget.inventory!.id!,
          quantity: int.parse(_quantityController.text),
          minimumQuantity: int.parse(_minimumQuantityController.text),
          unitPrice: double.parse(_unitPriceController.text),
          location: _locationController.text,
          notes: _notesController.text,
          supplierId: _selectedSupplierId,
          purchaseOrderId: _selectedPurchaseOrderId,
          invoiceId: _selectedInvoiceId,
          costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
          sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
          maxDiscount: int.tryParse(_maxDiscountController.text) ?? 0,
        );
        _showSnackBar('Inventory updated successfully', isError: false);
      } else {
        // Create business inventory (warehouse level)
        // First check if this product already exists
        final existingInventory = await businessInventoryService.getBusinessInventoryByProductId(
          businessId: businessContext.id,
          productId: _selectedProductId!,
        );

        await businessInventoryService.createBusinessInventory(
          businessId: businessContext.id,
          productId: _selectedProductId!,
          productName: _selectedProductName!,
          category: _selectedCategory ?? 'Uncategorized',
          totalQuantity: int.parse(_quantityController.text),
          costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
          sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
          supplierId: _selectedSupplierId,
          purchaseOrderId: _selectedPurchaseOrderId,
          invoiceId: _selectedInvoiceId,
          displayImageUrl: _selectedProductImage, // Add product image URL
        );
        
        // Provide appropriate feedback
        if (existingInventory != null) {
          _showSnackBar(
            'Product inventory updated! Added ${_quantityController.text} units to existing stock.',
            isError: false,
          );
        } else {
          _showSnackBar('Business inventory created successfully', isError: false);
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to save inventory item: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProductSelectionCard() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showProductSelectionDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.AppTheme.softGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.AppTheme.earthLight.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedProductName ?? 'Select a product',
                      style: TextStyle(
                        color: _selectedProductName != null
                            ? theme.AppTheme.textPrimary
                            : theme.AppTheme.earth,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: theme.AppTheme.earth,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context); // Pop current screen
                NavigationService.navigateToCreateProduct();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: theme.AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create New Product',
                      style: TextStyle(
                        color: theme.AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityCard() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.numbers_outlined,
                  color: theme.AppTheme.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quantity & Pricing',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quantity Fields
          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Current Quantity',
              hintText: '0',
              prefixIcon:
                  Icon(Icons.inventory_outlined, color: theme.AppTheme.accent),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter quantity';
              }
              final qty = int.tryParse(value);
              if (qty == null || qty < 0) {
                return 'Invalid quantity';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          TextFormField(
            controller: _minimumQuantityController,
            decoration: InputDecoration(
              labelText: 'Minimum Stock',
              hintText: '0',
              prefixIcon:
                  Icon(Icons.warning_outlined, color: theme.AppTheme.secondary),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter minimum';
              }
              final qty = int.tryParse(value);
              if (qty == null || qty < 0) {
                return 'Invalid minimum';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Unit Price
          TextFormField(
            controller: _unitPriceController,
            decoration: InputDecoration(
              labelText: 'Unit Price',
              hintText: '0.00',
              prefixIcon: Icon(Icons.attach_money_outlined,
                  color: theme.AppTheme.primary),
              prefixText: 'NGN ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter unit price';
              }
              final price = double.tryParse(value);
              if (price == null || price <= 0) {
                return 'Invalid price';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: theme.AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Purchase Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Invoice Number
          GestureDetector(
            onTap: _showInvoiceSelectionDialog,
            child: TextFormField(
              controller: _invoiceNumberController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Invoice Number',
                hintText: 'Select invoice',
                prefixIcon:
                    Icon(Icons.receipt_outlined, color: theme.AppTheme.primary),
                suffixIcon: Icon(Icons.search, color: theme.AppTheme.primary),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Purchase Order Number
          GestureDetector(
            onTap: _showPurchaseOrderSelectionDialog,
            child: TextFormField(
              controller: _purchaseOrderNumberController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Purchase Order Number',
                hintText: 'Select purchase order',
                prefixIcon: Icon(Icons.shopping_bag_outlined,
                    color: theme.AppTheme.primary),
                suffixIcon: Icon(Icons.search, color: theme.AppTheme.primary),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Cost Price
          TextFormField(
            controller: _costPriceController,
            decoration: InputDecoration(
              labelText: 'Cost Price',
              hintText: '0.00',
              prefixText: 'NGN ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter cost price';
              }
              final cost = double.tryParse(value);
              final unit = double.tryParse(_unitPriceController.text);
              if (cost == null || cost < 0) {
                return 'Invalid cost price';
              }
              if (unit != null && cost > unit) {
                return 'Cost price cannot be more than unit price';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Selling Price
          TextFormField(
            controller: _sellingPriceController,
            decoration: InputDecoration(
              labelText: 'Selling Price',
              prefixIcon: Icon(Icons.monetization_on_outlined,
                  color: theme.AppTheme.primary),
              hintText: '0.00',
              //prefixIcon: Icon(Icons.sell_outlined, color: theme.AppTheme.primary),
              prefixText: 'NGN ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter selling price';
              }
              final selling = double.tryParse(value);
              if (selling == null || selling < 0) {
                return 'Invalid selling price';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Maximum Discount
          TextFormField(
            controller: _maxDiscountController,
            decoration: InputDecoration(
              labelText: 'Maximum Discount (%)',
              hintText: '0',
              prefixIcon: Icon(Icons.percent, color: theme.AppTheme.primary),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter maximum discount';
              }
              final discount = int.tryParse(value);
              if (discount == null || discount < 0 || discount > 100) {
                return 'Discount must be between 0 and 100';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Supplier
          GestureDetector(
            onTap: _showSupplierSelectionDialog,
            child: TextFormField(
              controller: _supplierController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Supplier',
                hintText: 'Select supplier',
                prefixIcon: Icon(Icons.business_outlined,
                    color: theme.AppTheme.primary),
                suffixIcon: Icon(Icons.search, color: theme.AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.AppTheme.earth.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: theme.AppTheme.earth,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Location
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Storage Location (Optional)',
              hintText: 'e.g., Warehouse A, Shelf 3',
              prefixIcon:
                  Icon(Icons.location_on_outlined, color: theme.AppTheme.earth),
            ),
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 20),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Additional information about this item',
              prefixIcon:
                  Icon(Icons.note_outlined, color: theme.AppTheme.earth),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.AppTheme.glass,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Inventory' : 'Create Inventory',
          style: TextStyle(
            color: theme.AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const LoadingView()
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: _isInitialized
                    ? FadeTransition(
                        opacity: _fadeAnimation!,
                        child: SlideTransition(
                          position: _slideAnimation!,
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              if (!_isEditing) _buildProductSelectionCard(),
                              _buildQuantityCard(),
                              _buildPurchaseCard(),
                              _buildDetailsCard(),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          const SizedBox(height: 8),
                          if (!_isEditing) _buildProductSelectionCard(),
                          _buildQuantityCard(),
                          _buildPurchaseCard(),
                          _buildDetailsCard(),
                        ],
                      ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.AppTheme.glass,
          boxShadow: [
            BoxShadow(
              color: theme.AppTheme.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveInventory,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditing
                              ? Icons.save_outlined
                              : Icons.add_circle_outline,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditing ? 'Update Inventory' : 'Create Inventory',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showInvoiceSelectionDialog() async {
    final Invoice? selectedInvoice = await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.AppTheme.glass,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_outlined,
                        color: theme.AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Invoice',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.AppTheme.earth),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Invoice>>(
                  stream: ref.watch(invoiceServiceProvider).streamInvoices(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final invoices = snapshot.data ?? [];
                    if (invoices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 48,
                              color: theme.AppTheme.earth,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No invoices found',
                              style: TextStyle(
                                color: theme.AppTheme.earth,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = invoices[index];
                        return ListTile(
                          title: Text(
                            'Invoice #${invoice.id}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Customer: ${invoice.customerName}',
                            style: TextStyle(
                              color: theme.AppTheme.earth,
                            ),
                          ),
                          trailing: Text(
                            'NGN ${invoice.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.AppTheme.primary,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, invoice);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ));

    if (selectedInvoice != null) {
      setState(() {
        _selectedInvoiceId = selectedInvoice.id;
        _invoiceNumberController.text = 'Invoice #${selectedInvoice.id}';
        // Update cost price if available in invoice
        if (selectedInvoice.items.isNotEmpty) {
          final item = selectedInvoice.items.first;
          _costPriceController.text = item.unitPrice.toStringAsFixed(2);
          _costPrice = item.unitPrice;
        }
      });
    }
  }

  Future<void> _showPurchaseOrderSelectionDialog() async {
    final PurchaseOrder? selectedOrder = await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.AppTheme.glass,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: theme.AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Purchase Order',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.AppTheme.earth),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<PurchaseOrder>>(
                  stream: ref
                      .watch(purchaseOrderServiceProvider)
                      .streamPurchaseOrders(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 48,
                              color: theme.AppTheme.earth,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No purchase orders found',
                              style: TextStyle(
                                color: theme.AppTheme.earth,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return ListTile(
                          title: Text(
                            order.orderNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Supplier: ${order.supplierName}',
                            style: TextStyle(
                              color: theme.AppTheme.earth,
                            ),
                          ),
                          trailing: Text(
                            'NGN ${order.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.AppTheme.primary,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, order);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ));

    if (selectedOrder != null) {
      setState(() {
        _selectedPurchaseOrderId = selectedOrder.id;
        _purchaseOrderNumberController.text = selectedOrder.orderNumber;
        _supplierController.text = selectedOrder.supplierName;
        _selectedSupplierId = selectedOrder.supplierId;
        // Update cost price if available in purchase order
        if (selectedOrder.items.isNotEmpty) {
          final item = selectedOrder.items.first;
          _costPriceController.text = item.unitPrice.toStringAsFixed(2);
          _costPrice = item.unitPrice;
        }
      });
    }
  }

  Future<void> _showSupplierSelectionDialog() async {
    final Supplier? selectedSupplier = await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.AppTheme.glass,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.business_outlined,
                        color: theme.AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Supplier',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.AppTheme.earth),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Supplier>>(
                  stream: ref.watch(supplierServiceProvider).streamSuppliers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final suppliers = snapshot.data ?? [];
                    if (suppliers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 48,
                              color: theme.AppTheme.earth,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No suppliers found',
                              style: TextStyle(
                                color: theme.AppTheme.earth,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: suppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = suppliers[index];
                        return ListTile(
                          title: Text(
                            supplier.companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            supplier.email,
                            style: TextStyle(
                              color: theme.AppTheme.earth,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, supplier);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
    ));

    if (selectedSupplier != null) {
      setState(() {
        _selectedSupplierId = selectedSupplier.id;
        _supplierController.text = selectedSupplier.companyName;
      });
    }
  }
}

// Warehouse Product Selection Screen with Modern Design
class WarehouseProductSelectionScreen extends ConsumerStatefulWidget {
  const WarehouseProductSelectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WarehouseProductSelectionScreen> createState() =>
      _WarehouseProductSelectionScreenState();
}

class _WarehouseProductSelectionScreenState
    extends ConsumerState<WarehouseProductSelectionScreen>
    with TickerProviderStateMixin {
  List<Product> _products = [];
  List<Inventory> _warehouseInventory = [];
  Set<String> _selectedProductIds = {};
  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadProductsAndInventory();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsAndInventory() async {
    setState(() => _isLoading = true);
    final productService = ref.read(productServiceProvider);
    final inventoryService = ref.read(inventoryServiceProvider);
    await productService.fetchProducts();
    final products = productService.products;
    final inventoryStream = inventoryService.streamInventory();
    inventoryStream.listen((items) {
      setState(() {
        _products = products;
        _warehouseInventory =
            items.docs.map((doc) => Inventory.fromFirestore(doc)).toList();
        _isLoading = false;
      });
      _fadeController.forward();
    });
  }

  int _getWarehouseQuantity(String productId) {
    debugPrint('Fetching quantity for product: $productId');
    if (_selectedProductIds.isEmpty) {
      debugPrint('No products selected');
      return 0;
    }
    final inv =
        _warehouseInventory.where((i) => i.productId == productId).toList();
    return inv.isNotEmpty ? inv.first.quantity : 0;
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: theme.AppTheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildModernCard(
      {required Widget child, EdgeInsets? padding, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.AppTheme.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.AppTheme.earthLight.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.AppTheme.primary.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: theme.AppTheme.earth.withOpacity(0.03),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildProductItem(Product product) {
    final warehouseQty = _getWarehouseQuantity(product.id);
    final isSelected = _selectedProductIds.contains(product.id);

    return _buildModernCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedProductIds.remove(product.id);
              } else {
                _selectedProductIds.add(product.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                // Selection Checkbox
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.AppTheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? theme.AppTheme.primary
                            : theme.AppTheme.earthLight,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ),

                // Product Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.AppTheme.whiteSmoke,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: theme.AppTheme.whiteSmoke,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: theme.AppTheme.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: theme.AppTheme.whiteSmoke,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: theme.AppTheme.earth,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: theme.AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: theme.AppTheme.primary,
                              size: 28,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 16),

                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.AppTheme.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: warehouseQty > 0
                                  ? theme.AppTheme.accent.withOpacity(0.1)
                                  : theme.AppTheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Warehouse: $warehouseQty',
                              style: TextStyle(
                                color: warehouseQty > 0
                                    ? theme.AppTheme.accent
                                    : theme.AppTheme.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.category,
                              style: TextStyle(
                                color: theme.AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'NGN ${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
  }

  void _onAddToStoreInventory() async {
    final storeService = ref.read(store_service.storeServiceProvider);
    await storeService.fetchStores();
    final stores = storeService.stores;
    if (stores.isEmpty) {
      _showSnackBar('No stores available', isError: true);
      return;
    }
    String? selectedStoreId = stores.first.id;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store_outlined,
                  color: theme.AppTheme.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add to Store Inventory',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.AppTheme.whiteSmoke,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.AppTheme.earthLight,
                    width: 1,
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedStoreId,
                  decoration: const InputDecoration(
                    labelText: 'Select Store',
                    border: InputBorder.none,
                  ),
                  items: stores
                      .map((store) => DropdownMenuItem(
                            value: store.id,
                            child: Text(store.name),
                          ))
                      .toList(),
                  onChanged: (val) => selectedStoreId = val,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.AppTheme.earth,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {'storeId': selectedStoreId});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add to Store',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result['storeId'] != null) {
      final inventoryService = ref.read(inventoryServiceProvider);
      final storeInventoryService = ref.read(storeInventoryServiceProvider);
      for (final productId in _selectedProductIds) {
        final product = _products.firstWhere((p) => p.id == productId);
        // For demo, add all available warehouse quantity to store
        final warehouseQty = _getWarehouseQuantity(productId);
        if (warehouseQty > 0) {
          // First create the inventory item in the master inventory collection
          await inventoryService.createInventory(
            storeId: result['storeId'],
            productId: product.id,
            productName: product.name,
            quantity: warehouseQty,
            minimumQuantity: 1,
            unitPrice: product.price,
            displayImageUrl: product.displayImageUrl, // Add product image URL
          );

          // Get the latest inventory item for this product
          final inventorySnapshot = await inventoryService
              .streamInventory(
                searchQuery: product.name,
                storeId: result['storeId'],
              )
              .first;

          final inventoryDoc = inventorySnapshot.docs.first;
          final inventory = Inventory.fromFirestore(inventoryDoc);

          // Get business details from SharedPreferences
          final businessId = await BusinessPreferencesHelper.getSelectedBusinessId();
          final businessName = await BusinessPreferencesHelper.getSelectedBusinessName();

          // Then create the store inventory item using the business inventory ID
          await storeInventoryService.createStoreInventory(
            businessId: businessId!,
            businessName: businessName!,
            vendorId: inventoryService.currentVendorId,
            storeId: result['storeId'],
            businessInventoryId: inventory.id, // Updated to use businessInventoryId
            productId: product.id,
            productName: product.name,
            quantity: warehouseQty,
            minimumQuantity: 1,
            unitPrice: product.price,
            displayImageUrl: product.displayImageUrl, // Add product image URL
          );
        }
      }
      _showSnackBar('Added to store inventory successfully!', isError: false);
      setState(() => _selectedProductIds.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.AppTheme.glass,
        elevation: 0,
        title: Text(
          'Warehouse Products',
          style: TextStyle(
            color: theme.AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: theme.AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: theme.AppTheme.primary),
              onPressed: () {
                Navigator.pushNamed(context, '/create-product');
              },
              tooltip: 'Add Product',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: _products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: theme.AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.inventory_outlined,
                                size: 64,
                                color: theme.AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No products in warehouse',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Add products to your warehouse to manage inventory',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.AppTheme.earth,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 100),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return _buildProductItem(product);
                      },
                    ),
            ),
      bottomNavigationBar: _selectedProductIds.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.AppTheme.glass,
                boxShadow: [
                  BoxShadow(
                    color: theme.AppTheme.primary.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.AppTheme.accent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.store_outlined, color: Colors.white),
                    label: Text(
                      'Add ${_selectedProductIds.length} to Store',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: _onAddToStoreInventory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.AppTheme.accent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
