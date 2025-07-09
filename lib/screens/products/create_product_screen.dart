/// CreateProductScreen
///
/// This screen allows users to create or edit products in the system.
///
/// Features:
/// - Add/edit product details: name, description, price, stock, and category
/// - Upload, crop, and preview up to 5 product images with modern UI
/// - Uses glassmorphism cards, accent color highlights, and smooth animations
/// - Form validation and error handling
/// - Consistent with the Store tab and Inventory List screen theme
///
/// The screen supports both creation of new products and editing of existing ones, with appropriate validation and error handling.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/services/product_service.dart';
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

// Top-level helper class for selected images
class _SelectedImage {
  final String filePath;
  Uint8List thumbnail;
  _SelectedImage({required this.filePath, required this.thumbnail});
}

class CreateProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  final dynamic initialMedia;

  const CreateProductScreen({
    super.key,
    this.productId,
    this.initialMedia,
  });

  @override
  ConsumerState<CreateProductScreen> createState() =>
      _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  bool _isLoading = false;
  bool _isUploading = false;
  Product? _product;
  String _selectedCategory = 'Electronics';
  final List<String> _categories = [
    'Electronics',
    'Clothing',
    'Home',
    'Beauty',
    'Sports',
    'Books',
    'Toys',
    'Food',
  ];

  // Store selected images as objects with file path and thumbnail
  final List<_SelectedImage> _selectedImages = [];
  List<double> _uploadProgress = [];
  List<bool> _isImageUploading = [];

  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  int _displayImageIndex = 0; // Track which image is the display image

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.productId != null) {
      _loadProduct();
    }
    _prefillThumbnail();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));

    _fadeController!.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _slideController!.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final productService = ref.read(productServiceProvider);
      final product = await productService.getProduct(widget.productId!);
      if (product != null) {
        setState(() {
          _product = product;
          _nameController.text = product.name;
          _descriptionController.text = product.description;
          _priceController.text = product.price.toString();
          _stockController.text = product.stock.toString();
          _selectedCategory =
              product.category.isNotEmpty ? product.category : 'Electronics';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to load product', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _prefillThumbnail() async {
    if (widget.initialMedia != null) {
      try {
        final file = await widget.initialMedia.file;
        if (file != null) {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: file.path,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
            ],
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Edit & Crop Image',
                toolbarColor: AppTheme.primary,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: false,
              ),
              IOSUiSettings(title: 'Edit & Crop Image'),
            ],
          );

          if (croppedFile != null) {
            final bytes = await croppedFile.readAsBytes();

            // Save to permanent directory
            final appDir = await getApplicationDocumentsDirectory();
            final fileName =
                'product_${DateTime.now().millisecondsSinceEpoch}_initial.jpg';
            final savedPath = '${appDir.path}/$fileName';
            final savedFile = await File(savedPath).writeAsBytes(bytes);

            setState(() {
              _selectedImages.insert(
                0,
                _SelectedImage(
                  filePath: savedFile.path,
                  thumbnail: bytes,
                ),
              );
            });
          }
        }
      } catch (e) {
        _showSnackBar('Failed to prefill image: ${e.toString()}',
            isError: true);
      }
    }
  }

  Future<void> _pickImage() async {
    final localContext = context;
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      localContext,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 5,
        requestType: RequestType.image,
      ),
    );

    if (assets != null && assets.isNotEmpty) {
      _showCroppingDialog(assets);
    }
  }

  void _showCroppingDialog(List<AssetEntity> assets) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CroppingDialog(
        assets: assets,
        onComplete: (croppedImages) {
          setState(() {
            _selectedImages.addAll(croppedImages);
          });
        },
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final productService = ref.read(productServiceProvider);
      final vendorId = ref.read(vendorIdSyncProvider);

      if (vendorId.isEmpty) {
        throw Exception('Vendor ID is missing. Please log in again.');
      }

      // Upload images and get URLs (assuming you have this logic)
      final List<String> uploadedImageUrls = await _uploadAllImages();
      final displayImageUrl = uploadedImageUrls.isNotEmpty &&
              _displayImageIndex < uploadedImageUrls.length
          ? uploadedImageUrls[_displayImageIndex]
          : null;

      final product = Product(
        id: widget.productId ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        stock: int.parse(_stockController.text),
        category: _selectedCategory,
        vendorId: vendorId,
        images: uploadedImageUrls,
        displayImageUrl: displayImageUrl,
        rating: 0.0, // Default rating for new products
        reviews: 0, // Default review count for new products
        tags: [], // Empty tags list for new products
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.productId != null) {
        await productService.updateProduct(product);
      } else {
        await productService.createProduct(product);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving product: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<List<String>> _uploadAllImages() async {
    final List<String> urls = [];
    _isImageUploading = List.filled(_selectedImages.length, false);
    _uploadProgress = List.filled(_selectedImages.length, 0.0);

    for (int i = 0; i < _selectedImages.length; i++) {
      _isImageUploading[i] = true;
      setState(() {});

      final file = File(_selectedImages[i].filePath);
      final fileName =
          'products/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          _uploadProgress[i] = event.bytesTransferred / event.totalBytes;
          setState(() {});
        }
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      urls.add(url);

      _isImageUploading[i] = false;
      setState(() {});
    }
    return urls;
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
        backgroundColor: isError ? AppTheme.secondary : AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildModernCard(
      {required Widget child, EdgeInsets? padding, Color? backgroundColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.glass,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.06),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.07),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }

  Widget _buildImageSection() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: AppTheme.accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Product Images',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_selectedImages.length}/5',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_selectedImages.isEmpty)
            _buildEmptyImagePicker()
          else
            _buildImageGrid(),
        ],
      ),
    );
  }

  Widget _buildEmptyImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.accent.withOpacity(0.18),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.13),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 42,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Product Images',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                'Tap to select up to 5 images',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.earth,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Image.memory(
                  _selectedImages[0].thumbnail,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),

                // Edit overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.edit, color: Colors.white, size: 18),
                      onPressed: () => _editImage(0),
                    ),
                  ),
                ),

                // Delete overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                      onPressed: () => _removeImage(0),
                    ),
                  ),
                ),

                // Upload progress overlay
                if (_isUploading &&
                    _isImageUploading.isNotEmpty &&
                    _isImageUploading[0])
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _uploadProgress.isNotEmpty
                                  ? _uploadProgress[0]
                                  : 0,
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Uploading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Thumbnail row
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:
                _selectedImages.length + (_selectedImages.length < 5 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index < _selectedImages.length) {
                return _buildThumbnailItem(index);
              } else {
                return _buildAddImageButton();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailItem(int index) {
    return GestureDetector(
      onTap: () => _editImage(index),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accent.withOpacity(0.22),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _selectedImages[index].thumbnail,
                fit: BoxFit.cover,
                width: 80,
                height: 80,
              ),
            ),
            // Star icon for display image selection
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _displayImageIndex = index;
                  });
                },
                child: Icon(
                  _displayImageIndex == index ? Icons.star : Icons.star_border,
                  color:
                      _displayImageIndex == index ? Colors.amber : Colors.grey,
                  size: 24,
                ),
              ),
            ),
            // Upload progress overlay
            if (_isUploading &&
                index < _isImageUploading.length &&
                _isImageUploading[index])
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: index < _uploadProgress.length
                            ? _uploadProgress[index]
                            : 0,
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
            // Remove button (offset to not overlap with star)
            Positioned(
              top: 4,
              right: 36, // 4 + 24 (star size) + 8 spacing
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accent.withOpacity(0.18),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: AppTheme.accent,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildProductDetailsSection() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AppTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Product Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Product Name
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Product Name',
              hintText: 'Enter product name',
              prefixIcon: Icon(Icons.label_outline, color: AppTheme.accent),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a product name';
              }
              if (value.length < 2) {
                return 'Product name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Description
          TextFormField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe your product',
              prefixIcon:
                  Icon(Icons.description_outlined, color: AppTheme.accent),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              if (value.length < 10) {
                return 'Description must be at least 10 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Category Selection
          Container(
            decoration: BoxDecoration(
              color: AppTheme.whiteSmoke,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.earthLight,
                width: 1,
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon:
                    Icon(Icons.category_outlined, color: AppTheme.accent),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value ?? 'Electronics');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.earth.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.earth.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.attach_money_outlined,
                  color: AppTheme.earth,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Pricing & Stock',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Price',
                    hintText: '0.00',
                    prefixText: 'NGN ',
                    prefixIcon: Icon(Icons.currency_exchange_outlined,
                        color: AppTheme.secondary),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Stock Quantity',
                    hintText: '0',
                    prefixIcon: Icon(Icons.inventory_outlined,
                        color: AppTheme.secondary),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter stock quantity';
                    }
                    final stock = int.tryParse(value);
                    if (stock == null || stock < 0) {
                      return 'Please enter a valid quantity';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editImage(int index) async {
    final originalFilePath = _selectedImages[index].filePath;
    if (await File(originalFilePath).exists()) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: originalFilePath,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9
        ],
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit & Crop Image',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Edit & Crop Image',
          ),
        ],
      );
      if (croppedFile != null) {
        final bytes = await croppedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImages[index] = _SelectedImage(
            filePath: croppedFile.path,
            thumbnail: bytes,
          );
        });
      }
    } else {
      _showSnackBar('Original image file not found.', isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.glass,
        elevation: 0,
        title: Text(
          widget.productId != null ? 'Edit Product' : 'Create Product',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.productId != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppTheme.earth.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.earth.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.preview_outlined, color: AppTheme.earth),
                onPressed: () {
                  // Preview product functionality
                },
                tooltip: 'Preview Product',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : Stack(
              children: [
                if (_fadeAnimation != null && _slideAnimation != null)
                  FadeTransition(
                    opacity: _fadeAnimation!,
                    child: SlideTransition(
                      position: _slideAnimation!,
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 100),
                          children: [
                            const SizedBox(height: 8),
                            _buildImageSection(),
                            _buildProductDetailsSection(),
                            _buildPricingSection(),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        const SizedBox(height: 8),
                        _buildImageSection(),
                        _buildProductDetailsSection(),
                        _buildPricingSection(),
                      ],
                    ),
                  ),

                // Upload overlay
                if (_isUploading)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Uploading Images...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Please wait while we upload your product images',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.earth,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ...List.generate(
                              _selectedImages.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      child: _isImageUploading.length > index &&
                                              _isImageUploading[index]
                                          ? CircularProgressIndicator(
                                              strokeWidth: 2,
                                              value:
                                                  _uploadProgress.length > index
                                                      ? _uploadProgress[index]
                                                      : 0,
                                              color: AppTheme.primary,
                                            )
                                          : Icon(
                                              Icons.check_circle,
                                              color: AppTheme.accent,
                                              size: 16,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Image ${index + 1}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (_uploadProgress.length > index)
                                      Text(
                                        '${(_uploadProgress[index] * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.earth,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _isLoading || _isUploading ? null : _saveProduct,
          backgroundColor: AppTheme.accent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: _isLoading || _isUploading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_outlined, color: Colors.white),
          label: Text(
            _isLoading || _isUploading ? 'Saving...' : 'Save Product',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// Modern Cropping Dialog Widget
class _CroppingDialog extends StatefulWidget {
  final List<AssetEntity> assets;
  final Function(List<_SelectedImage>) onComplete;

  const _CroppingDialog({
    required this.assets,
    required this.onComplete,
  });

  @override
  State<_CroppingDialog> createState() => _CroppingDialogState();
}

class _CroppingDialogState extends State<_CroppingDialog> {
  int _currentIndex = 0;
  List<_SelectedImage> _croppedImages = [];
  Uint8List? _currentThumbnail;

  @override
  void initState() {
    super.initState();
    _processImages();
  }

  Future<void> _processImages() async {
    for (int i = 0; i < widget.assets.length; i++) {
      setState(() => _currentIndex = i);

      final asset = widget.assets[i];
      _currentThumbnail =
          await asset.thumbnailDataWithSize(const ThumbnailSize(60, 60));
      setState(() {});

      final file = await asset.file;
      if (file != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9
          ],
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Edit & Crop Image',
              toolbarColor: AppTheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Edit & Crop Image',
            ),
          ],
        );

        if (croppedFile != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory('${appDir.path}/cropped_images');
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }

          final fileName =
              'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedFile =
              await File(croppedFile.path).copy('${imagesDir.path}/$fileName');

          final bytes = await savedFile
              .readAsBytes(); // Define bytes **after** copying the file

          if (!mounted) return;
          setState(() {
            _croppedImages.add(
              _SelectedImage(filePath: savedFile.path, thumbnail: bytes),
            );
          });
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete(_croppedImages);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentThumbnail != null)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _currentThumbnail!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.whiteSmoke,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Processing Images',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cropping image ${_currentIndex + 1} of ${widget.assets.length}...',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.earth,
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.assets.length,
              backgroundColor: AppTheme.earthLight,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// Top-level function for compute
Uint8List compressImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  int quality = 90;
  List<int> compressed;
  do {
    compressed = img.encodeJpg(decoded, quality: quality);
    quality -= 10;
  } while (compressed.length > 1024 * 1024 && quality > 10);
  return Uint8List.fromList(compressed);
}
