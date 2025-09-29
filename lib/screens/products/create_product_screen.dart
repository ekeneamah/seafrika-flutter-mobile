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
import 'package:vendor_app/services/media_service.dart';
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
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
  final _minQuantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _initialQuantityController = TextEditingController();
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

    // Set default minimum quantity for new products
    if (widget.productId == null) {
      _minQuantityController.text = '1'; // Default minimum quantity
    }

    // Validate user authentication and business context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateUserAndBusinessContext();
    });

    if (widget.productId != null) {
      _loadProduct();
    }
    _prefillThumbnail();
  }

  /// Validate that user is logged in and has selected a business
  Future<bool> _validateUserAndBusinessContext() async {
    try {
      // Check if user is logged in (vendorId/ownerId)
      final vendorId = ref.read(vendorIdSyncProvider);
      if (vendorId.isEmpty) {
        // User not logged in - redirect to login with clear stack
        if (mounted) {
          _showSnackBar('Please log in to continue.', isError: true);
          await NavigationService.navigateToAndClearStack(AppRoutes.login);
        }
        return false;
      }

      // Check if business is selected
      final businessId = ref.read(selectedBusinessIdProvider);
      if (businessId == null || businessId.isEmpty) {
        // No business selected - redirect to business selection
        if (mounted) {
          _showSnackBar('Please select a business to continue.', isError: true);
          await NavigationService.navigateTo(AppRoutes.selectBusiness);
          // Pop current screen after business selection navigation
          Navigator.of(context).pop();
        }
        return false;
      }

      // Both validations passed - user can create products
      print(
          'User validation passed - vendorId: $vendorId, businessId: $businessId');
      return true;
    } catch (e) {
      print('Error during user validation: $e');
      if (mounted) {
        _showSnackBar('Authentication error. Please login again.',
            isError: true);
        await NavigationService.navigateToAndClearStack(AppRoutes.login);
      }
      return false;
    }
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
    _minQuantityController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final productService = ref.read(productServiceProvider);
      final product = await productService.getProduct(widget.productId!);
      if (product != null) {
        // Load product details
        _product = product;
        _nameController.text = product.name;
        _descriptionController.text = product.description;
        _priceController.text = product.price.toString();
        _stockController.text = product.stock.toString();
        _minQuantityController.text = product.minQuantity.toString();
        _selectedCategory =
            product.category.isNotEmpty ? product.category : 'Electronics';

        // Load existing images into _selectedImages
        _selectedImages.clear();
        for (final imageUrl in product.images) {
          try {
            // Download image bytes for thumbnail (or use a placeholder if fails)
            final uri = Uri.parse(imageUrl);
            final bytes = await NetworkAssetBundle(uri)
                .load(imageUrl)
                .then((bd) => bd.buffer.asUint8List());
            _selectedImages
                .add(_SelectedImage(filePath: imageUrl, thumbnail: bytes));
          } catch (e) {
            // If download fails, use an empty/placeholder thumbnail
            _selectedImages.add(
                _SelectedImage(filePath: imageUrl, thumbnail: Uint8List(0)));
          }
        }
        setState(() {});
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
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
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
      // Validate authentication and business context
      final isValid = await _validateUserAndBusinessContext();
      if (!isValid) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final productService = ref.read(productServiceProvider);
      final vendorId = ref.read(vendorIdSyncProvider);
      final businessId = ref.read(selectedBusinessIdProvider);

      // Separate local images (need upload) and remote URLs (already uploaded)
      final List<_SelectedImage> localImages = [];
      final List<String> remoteImageUrls = [];
      for (final imgObj in _selectedImages) {
        if (imgObj.filePath.startsWith('http')) {
          remoteImageUrls.add(imgObj.filePath);
        } else {
          localImages.add(imgObj);
        }
      }

      // Upload only local images
      final List<String> uploadedImageUrls =
          await _uploadAllImages(localImages);
      final List<String> allImageUrls = [
        ...remoteImageUrls,
        ...uploadedImageUrls
      ];
      final displayImageUrl =
          allImageUrls.isNotEmpty && _displayImageIndex < allImageUrls.length
              ? allImageUrls[_displayImageIndex]
              : null;

      final product = Product(
        id: widget.productId ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        stock: int.parse(_stockController.text),
        minQuantity: _minQuantityController.text.isEmpty
            ? 1
            : int.parse(_minQuantityController.text),
        category: _selectedCategory,
        vendorId: vendorId,
        businessId: businessId!,
        images: allImageUrls,
        displayImageUrl: displayImageUrl,
        rating: 0.0,
        reviews: 0,
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.productId != null) {
        await productService.updateProduct(product);
      } else {
        // Pass businessId to createProduct method
        await productService.createProduct(product, businessId: businessId);
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

  Future<List<String>> _uploadAllImages(
      [List<_SelectedImage>? imagesToUpload]) async {
    final List<String> urls = [];
    final images = imagesToUpload ?? _selectedImages;
    if (images.isEmpty) return urls;
    _isImageUploading = List.filled(images.length, false);
    _uploadProgress = List.filled(images.length, 0.0);

    // Get MediaService from providers
    final mediaService = ref.read(mediaServiceProvider);
    final businessContext = ref.read(businessContextProvider);
    final tempProductId = const Uuid().v4();

    // Only upload images passed in (local images)
    for (int i = 0; i < images.length; i++) {
      final imgObj = images[i];
      if (imgObj.filePath.startsWith('http')) continue; // Skip remote URLs
      _isImageUploading[i] = true;
      setState(() {});
      try {
        final file = File(imgObj.filePath);
        final imageBytes = await file.readAsBytes();
        final fileName =
            'product_image_${DateTime.now().millisecondsSinceEpoch}_$i';
        final downloadUrl =
            await mediaService.uploadMediaFromBytesWithCompression(
          bytes: imageBytes,
          fileName: fileName,
          type: 'image',
          vendorId: businessContext?.ownerId,
          productId: tempProductId,
          maxSizeBytes: 1024 * 1024,
          maxWidth: 1920,
          maxHeight: 1080,
          quality: 85,
          forceCompression: true,
        );
        if (downloadUrl != null) {
          urls.add(downloadUrl);
          debugPrint(
              'Image $i uploaded successfully with WebP compression: $downloadUrl');
        } else {
          throw Exception('Failed to upload image $i');
        }
      } catch (e) {
        debugPrint('Error uploading image $i: $e');
        _showSnackBar('Failed to upload image ${i + 1}: $e', isError: true);
      } finally {
        _isImageUploading[i] = false;
        _uploadProgress[i] = 1.0;
        setState(() {});
      }
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
          LayoutBuilder(
            builder: (context, constraints) {
              // Use horizontal layout for screens wider than 600px, vertical for smaller
              final isWideScreen = constraints.maxWidth > 600;

              if (isWideScreen) {
                // Horizontal layout for larger screens
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                );
              } else {
                // Vertical layout for smaller screens
                return Column(
                  children: [
                    TextFormField(
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
                    const SizedBox(height: 16),
                    TextFormField(
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _minQuantityController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Minimum Stock Alert',
                        hintText: '5',
                        prefixIcon: Icon(Icons.warning_outlined,
                            color: AppTheme.secondary),
                        helperText: 'Alert when stock falls below this level',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter minimum quantity';
                        }
                        final minQty = int.tryParse(value);
                        if (minQty == null || minQty < 0) {
                          return 'Please enter a valid minimum quantity';
                        }
                        return null;
                      },
                    ),
                  ],
                );
              }
            },
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
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
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
                                    SizedBox(
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
        try {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: file.path,
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
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
            final savedFile = await File(croppedFile.path)
                .copy('${imagesDir.path}/$fileName');

            final bytes = await savedFile
                .readAsBytes(); // Define bytes **after** copying the file

            if (!mounted) return;
            setState(() {
              _croppedImages.add(
                _SelectedImage(filePath: savedFile.path, thumbnail: bytes),
              );
            });
          } else {
            // User cancelled cropping - navigate back to previous screen
            if (!mounted) return;
            Navigator.of(context).pop(); // Close the cropping dialog
            Navigator.of(context)
                .pop(); // Navigate back to previous screen (media detail)
            return;
          }
        } catch (e) {
          // Handle cropping error gracefully - navigate back to previous screen
          print('Error during image cropping: $e');
          if (!mounted) return;
          Navigator.of(context).pop(); // Close the cropping dialog
          Navigator.of(context)
              .pop(); // Navigate back to previous screen (media detail)
          return;
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
      actions: [
        TextButton(
          onPressed: () {
            // Cancel cropping and navigate back to previous screen
            Navigator.of(context).pop(); // Close the cropping dialog
            Navigator.of(context)
                .pop(); // Navigate back to previous screen (media detail)
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
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
