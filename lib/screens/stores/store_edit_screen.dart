import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/store.dart';
import 'package:vendor_app/providers/business_context_provider.dart' show businessContextProvider;
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:vendor_app/widgets/responsive_contact_form.dart';

class StoreEditScreen extends ConsumerStatefulWidget {
  final Store? store;
  const StoreEditScreen({super.key, this.store});

  @override
  ConsumerState<StoreEditScreen> createState() => _StoreEditScreenState();
}

class _StoreEditScreenState extends ConsumerState<StoreEditScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _logoUrlController;
  late TextEditingController _coverImageUrlController;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  File? _selectedLogoFile;
  File? _selectedCoverFile;
  
  // Store type and platform selection
  String _storeType = 'physical'; // Default to physical store
  String? _selectedPlatform; // For online stores
  List<Map<String, dynamic>> _availablePlatforms = []; // Platforms from database
  bool _isLoadingPlatforms = false;

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

    final s = widget.store;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descController = TextEditingController(text: s?.description ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _logoUrlController = TextEditingController(text: s?.imageUrl ?? '');
    _coverImageUrlController =
        TextEditingController(text: s?.coverImageUrl ?? '');

    // Initialize store type and platform from existing store
    if (s != null) {
      _storeType = s.type ?? 'physical';
      _selectedPlatform = s.platform;
    }

    _fadeController.forward();
    _loadAvailablePlatforms();
  }

  Future<void> _loadAvailablePlatforms() async {
    setState(() {
      _isLoadingPlatforms = true;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }
      final platforms = await integrationService.getSupportedPlatforms();
      
      setState(() {
        _availablePlatforms = platforms;
        _isLoadingPlatforms = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPlatforms = false;
      });
      // Handle error silently or show snackbar if needed
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _logoUrlController.dispose();
    _coverImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(
      TextEditingController controller, String storagePath) async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
      ),
    );
    if (assets != null && assets.isNotEmpty) {
      final asset = assets.first;
      final file = await asset.file;
      if (file != null) {
        final cropped = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: AppTheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Crop Image',
            ),
          ],
        );
        if (cropped != null) {
          setState(() {
            if (storagePath == 'store_logos') {
              _selectedLogoFile = File(cropped.path);
            } else {
              _selectedCoverFile = File(cropped.path);
            }
          });
        }
      }
    }
  }

  Future<String?> _uploadImage(File file, String storagePath) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('$storagePath/$fileName.jpg');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      if (snapshot.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check for integration keys if it's an online store
    if (_storeType == 'online' && _selectedPlatform != null) {
      final shouldProceed = await _checkIntegrationKeys(_selectedPlatform!);
      if (!shouldProceed) return; // User chose not to proceed
    }
    
    setState(() => _isLoading = true);

    try {
      // Upload images if selected
      String? logoUrl = _logoUrlController.text.trim();
      String? coverUrl = _coverImageUrlController.text.trim();

      if (_selectedLogoFile != null) {
        logoUrl = await _uploadImage(_selectedLogoFile!, 'store_logos');
        if (logoUrl == null) {
          throw Exception('Failed to upload logo image');
        }
      }

      if (_selectedCoverFile != null) {
        coverUrl = await _uploadImage(_selectedCoverFile!, 'store_covers');
        if (coverUrl == null) {
          throw Exception('Failed to upload cover image');
        }
      }

      final storeService = ref.read(storeServiceProvider);
      final authService = ref.read(authServiceProvider);
      final now = DateTime.now();
      final isEdit = widget.store != null;
      final store = Store(
        id: isEdit ? widget.store!.id : '',
        ownerId: authService.currentUser!.vendorId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        address: _addressController.text.trim(),
        contactPerson: '',
        contactPhone: '',
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        imageUrl: logoUrl,
        coverImageUrl: coverUrl,
        type: _storeType,
        platform: _storeType == 'online' ? _selectedPlatform : null,
        isDeleted: false,
        isVerified: true,
        notes: '',
        businessId: ref.read(businessContextProvider)!.id,
        createdAt: isEdit ? widget.store!.createdAt : now,
        updatedAt: now,
      );

      if (isEdit) {
        await storeService.updateStore(store);
      } else {
        await storeService.createStore(store: store);
      }

      if (mounted) {
        _showSnackBar(
          isEdit
              ? 'Store updated successfully!'
              : 'Store created successfully!',
          isError: false,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().contains('already exists')
            ? 'A store with this name already exists. Please choose a different name.'
            : 'Failed to save store: ${e.toString()}';
        _showSnackBar(errorMsg, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        backgroundColor: isError ? AppTheme.secondary : AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.95),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black,
                        child: const Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

   Widget _buildImagePicker({
    required String title,
    required TextEditingController controller,
    required String storagePath,
    required IconData icon,
    double? height,
  }) {
    // pick the right file field based on storagePath
    final File? file = storagePath == 'store_logos'
        ? _selectedLogoFile
        : _selectedCoverFile;

    final bool hasFile = file != null;
    final bool hasUrl = controller.text.isNotEmpty;
    final bool hasImage = hasFile || hasUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // … your title row …
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _pickAndUploadImage(controller, storagePath),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: height ?? 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasImage ? Colors.transparent : AppTheme.softGreen,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasImage ? AppTheme.primary : AppTheme.earthLight,
                width: hasImage ? 2 : 1,
              ),
              boxShadow: hasImage
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: hasImage
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: GestureDetector(
                          onTap: () {
                            final url = hasUrl ? controller.text : file!.path;
                            _showFullImage(url);
                          },
                          child: hasFile
                              ? Image.file(
                                  file,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  controller.text,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primary,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, size: 32, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to add $title',
                        style: TextStyle(
                          color: AppTheme.earth,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.glass,
        elevation: 0,
        title: Text(
          widget.store == null ? 'Create Store' : 'Edit Store',
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
          if (widget.store != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.preview_outlined, color: AppTheme.accent),
                onPressed: () {
                  // Preview store functionality
                },
                tooltip: 'Preview Store',
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              const SizedBox(height: 8),

              // Store Information Section
              _buildModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.store_outlined,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Store Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        labelText: 'Store Name',
                        hintText: 'Enter your store name',
                        prefixIcon:
                            Icon(Icons.storefront, color: AppTheme.primary),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter store name' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your store',
                        prefixIcon: Icon(Icons.description_outlined,
                            color: AppTheme.primary),
                      ),
                      maxLines: 3,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter description' : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Store Type Selection
                    _buildStoreTypeSection(),
                    const SizedBox(height: 20),
                    
                    TextFormField(
                      controller: _addressController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.streetAddress,
                      decoration: InputDecoration(
                        labelText: _storeType == 'physical' ? 'Store Address' : 'Business Address (Optional)',
                        hintText: 'Enter store address',
                        prefixIcon: Icon(Icons.location_on_outlined,
                            color: AppTheme.primary),
                      ),
                      validator: (v) {
                        // Address is required for physical stores, optional for online stores
                        if (_storeType == 'physical') {
                          return v == null || v.isEmpty ? 'Enter address' : null;
                        }
                        return null; // Optional for online stores
                      },
                    ),
                  ],
                ),
              ),

              // Contact Information Section
              _buildModernCard(
                child: ResponsiveContactForm(
                  title: 'Contact Information',
                  phoneController: _phoneController,
                  emailController: _emailController,
                  accentColor: AppTheme.accent,
                  phoneValidator: (v) => v == null || v.isEmpty ? 'Enter phone' : null,
                  emailValidator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
                  phoneHint: '+234 xxx xxx xxxx',
                  emailHint: 'store@example.com',
                  isPhoneRequired: true,
                  isEmailRequired: true,
                ),
              ),

              // Images Section
              _buildModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.earth.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.image_outlined,
                            color: AppTheme.earth,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Store Images',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildImagePicker(
                            title: 'Logo',
                            controller: _logoUrlController,
                            storagePath: 'store_logos',
                            icon: Icons.account_circle_outlined,
                            height: 120,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: _buildImagePicker(
                            title: 'Cover Photo',
                            controller: _coverImageUrlController,
                            storagePath: 'store_covers',
                            icon: Icons.landscape_outlined,
                            height: 120,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.glass,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
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
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
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
                          widget.store == null
                              ? Icons.add_business
                              : Icons.save_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.store == null
                              ? 'Create Store'
                              : 'Save Changes',
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

  Widget _buildStoreTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Physical Store Radio Button
        RadioListTile<String>(
          title: const Text('Physical Store'),
          subtitle: const Text('A brick-and-mortar store with physical location'),
          value: 'physical',
          groupValue: _storeType,
          onChanged: (value) {
            setState(() {
              _storeType = value!;
              _selectedPlatform = null; // Reset platform selection
            });
          },
          activeColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
        ),
        
        // Online Store Radio Button
        RadioListTile<String>(
          title: const Text('Online Store'),
          subtitle: const Text('An e-commerce store or marketplace integration'),
          value: 'online',
          groupValue: _storeType,
          onChanged: (value) {
            setState(() {
              _storeType = value!;
              _selectedPlatform = null; // Reset platform selection
            });
          },
          activeColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
        ),
        
        // Platform Selection (only for online stores)
        if (_storeType == 'online') ...[
          const SizedBox(height: 16),
          Text(
            'Select Platform',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          
          if (_isLoadingPlatforms)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_availablePlatforms.isEmpty)
            Text(
              'No platforms available',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedPlatform,
              hint: const Text('Choose a platform'),
              items: _availablePlatforms.map((platform) {
                return DropdownMenuItem<String>(
                  value: platform['id'] as String,
                  child: Row(
                    children: [
                      Text(platform['name'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPlatform = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (_storeType == 'online' && value == null) {
                  return 'Please select a platform for online store';
                }
                return null;
              },
            ),
        ],
      ],
    );
  }

  Future<bool> _checkIntegrationKeys(String platform) async {
    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        return false; // No business selected, cannot check integration
      }
      final hasIntegration = await integrationService.hasIntegrationForPlatform(platform);
      
      if (hasIntegration) {
        return true; // Integration exists, proceed with store creation
      }
      
      // Show dialog asking user if they want to proceed without integration
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Integration Required'),
          content: Text(
            'You haven\'t set up integration keys for $platform yet. '
            'You can create the store now and add integration keys later, '
            'or cancel and set up the integration first.\n\n'
            'Would you like to proceed without integration keys?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      
      return shouldProceed ?? false;
    } catch (e) {
      // If there's an error checking integrations, allow creation but show warning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to check integration status: $e'),
          backgroundColor: Colors.orange,
        ),
      );
      return true;
    }
  }
}
