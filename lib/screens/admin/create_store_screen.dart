import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/widgets/custom_text_field.dart';
import 'package:vendor_app/providers/service_providers.dart';

class CreateStoreScreen extends ConsumerStatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  ConsumerState<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends ConsumerState<CreateStoreScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _storeDescriptionController = TextEditingController();

  // Focus nodes for better navigation
  final _storeNameFocusNode = FocusNode();
  final _storeAddressFocusNode = FocusNode();
  final _storePhoneFocusNode = FocusNode();
  final _storeDescriptionFocusNode = FocusNode();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _validationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _validationAnimation;

  bool _isLoading = false;
  bool _isFormValid = false;
  String _storeType = 'physical'; // Default to physical store
  String? _selectedPlatform; // For online stores
  List<Map<String, dynamic>> _availablePlatforms = []; // Platforms from database
  bool _isLoadingPlatforms = false;
  
  // Real-time validation states
  bool _isStoreNameValid = false;
  bool _isStoreAddressValid = false;
  bool _isStorePhoneValid = true; // Optional field
  bool _isStoreDescriptionValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _addValidationListeners();
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
      // Handle error - show snackbar or error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load available platforms: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
    _validationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _validationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _validationController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  void _addValidationListeners() {
    _storeNameController.addListener(_validateStoreNameRealTime);
    _storeAddressController.addListener(_validateStoreAddressRealTime);
    _storePhoneController.addListener(_validateStorePhoneRealTime);
    _storeDescriptionController.addListener(_validateStoreDescriptionRealTime);
  }

  void _validateStoreNameRealTime() {
    final value = _storeNameController.text.trim();
    final isValid = value.isNotEmpty && value.length >= 2;
    
    if (_isStoreNameValid != isValid) {
      setState(() => _isStoreNameValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateStoreAddressRealTime() {
    final value = _storeAddressController.text.trim();
    bool isValid;
    
    if (_storeType == 'physical') {
      // Address is required for physical stores
      isValid = value.isNotEmpty && value.length >= 5;
    } else {
      // Address is optional for online stores - valid if empty or if >= 5 chars
      isValid = value.isEmpty || value.length >= 5;
    }
    
    if (_isStoreAddressValid != isValid) {
      setState(() => _isStoreAddressValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateStorePhoneRealTime() {
    final value = _storePhoneController.text.trim();
    final isValid = value.isEmpty || RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value);
    
    if (_isStorePhoneValid != isValid) {
      setState(() => _isStorePhoneValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateStoreDescriptionRealTime() {
    final value = _storeDescriptionController.text.trim();
    final isValid = value.isNotEmpty && value.length >= 10;
    
    if (_isStoreDescriptionValid != isValid) {
      setState(() => _isStoreDescriptionValid = isValid);
      _checkFormValidity();
    }
  }

  void _checkFormValidity() {
    // For physical stores, address is required
    // For online stores, platform selection is required but address is optional
    bool addressValid = _storeType == 'physical' ? _isStoreAddressValid : true;
    bool platformValid = _storeType == 'online' ? (_selectedPlatform != null) : true;
    
    final isValid = _isStoreNameValid && 
                   addressValid && 
                   _isStorePhoneValid &&
                   _isStoreDescriptionValid &&
                   platformValid;
    
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
      if (isValid) {
        _validationController.forward();
      } else {
        _validationController.reverse();
      }
    }
  }

  // Responsive helper methods
  double _getHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 32.0; // Desktop
    if (screenWidth > 800) return 24.0;  // Tablet
    return 16.0; // Mobile
  }

  double _getCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return 24.0;  // Tablet/Desktop
    return 16.0; // Mobile
  }

  double _getIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 16.0; // Mobile
    return 20.0; // Tablet/Desktop
  }

  double _getFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize - 2; // Mobile
    return baseSize; // Tablet/Desktop
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Prepare store data
      final storeData = {
        'name': _storeNameController.text.trim(),
        'address': _storeAddressController.text.trim(),
        'phone': _storePhoneController.text.trim(),
        'description': _storeDescriptionController.text.trim(),
        'type': _storeType,
        if (_storeType == 'online' && _selectedPlatform != null)
          'platform': _selectedPlatform,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // TODO: Replace with actual store service call
      // await ref.read(storeServiceProvider).createStore(storeData);
      
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '${_storeType == 'physical' ? 'Physical' : 'Online'} store created successfully!',
              ),
            ],
          ),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Navigate back or to store list
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Error: $e',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardPadding = _getCardPadding(context);
        
        return Container(
          width: double.infinity,
          margin: margin ?? EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.earthLight.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.earth.withOpacity(0.03),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.all(cardPadding),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildValidationTick(bool isValid) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.elasticOut,
                ),
              ),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: isValid
              ? Container(
                  key: const ValueKey('valid_tick'),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: AppTheme.accent,
                    size: iconSize,
                  ),
                )
              : const SizedBox.shrink(
                  key: ValueKey('no_tick'),
                ),
        );
      },
    );
  }

  Widget _buildSuffixIcon({required bool isValid}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildValidationTick(isValid),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFormProgressIndicator() {
    final completedFields = [
      _isStoreNameValid,
      _isStoreAddressValid,
      _isStorePhoneValid,
      _isStoreDescriptionValid,
    ].where((field) => field).length;

    final totalFields = 4;
    final progress = completedFields / totalFields;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: AppTheme.primary,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$completedFields/$totalFields',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Store',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: _getFontSize(context, 18),
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = _getHorizontalPadding(context);
          
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero Section
                        _buildHeroSection(),
                        const SizedBox(height: 24),
                        
                        // Store Information Card
                        _buildStoreInformationCard(constraints, horizontalPadding),
                        const SizedBox(height: 32),
                        
                        // Submit Button
                        _buildSubmitButton(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        // Store Icon with animated background
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withOpacity(0.1),
                AppTheme.accent.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.store_outlined,
            size: 48,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          'New Store',
          style: TextStyle(
            fontSize: _getFontSize(context, 24),
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          'Create a new store location for your business',
          style: TextStyle(
            fontSize: _getFontSize(context, 14),
            color: AppTheme.earth,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStoreInformationCard(BoxConstraints constraints, double horizontalPadding) {
    final iconSize = _getIconSize(context);
    final fontSize = _getFontSize(context, 18);

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
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
                  size: iconSize,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Store Information',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              // Form Progress Indicator
              _buildFormProgressIndicator(),
            ],
          ),
          const SizedBox(height: 20),

          // Store Name Field
          CustomTextField(
            controller: _storeNameController,
            label: 'Store Name',
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            prefixIcon: Icon(Icons.store_outlined, color: AppTheme.primary),
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_storeAddressFocusNode),
            suffixIcon: _buildSuffixIcon(isValid: _isStoreNameValid),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter store name';
              }
              if (value.length < 2) {
                return 'Store name must be at least 2 characters';
              }
              return null;
            },
            focusNode: _storeNameFocusNode,
          ),
          const SizedBox(height: 20),

          // Store Type Selection
          _buildStoreTypeSection(),
          const SizedBox(height: 20),

          // Store Address Field
          CustomTextField(
            controller: _storeAddressController,
            label: _storeType == 'physical' ? 'Store Address' : 'Business Address (Optional)',
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primary),
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_storePhoneFocusNode),
            suffixIcon: _buildSuffixIcon(isValid: _isStoreAddressValid),
            validator: (value) {
              // Address is required for physical stores, optional for online stores
              if (_storeType == 'physical') {
                if (value == null || value.isEmpty) {
                  return 'Please enter store address';
                }
                if (value.length < 5) {
                  return 'Address must be at least 5 characters';
                }
              } else {
                // For online stores, validate only if provided
                if (value != null && value.isNotEmpty && value.length < 5) {
                  return 'Address must be at least 5 characters';
                }
              }
              return null;
            },
            focusNode: _storeAddressFocusNode,
          ),
          const SizedBox(height: 20),

          // Phone Field
          CustomTextField(
            controller: _storePhoneController,
            label: 'Phone Number (Optional)',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primary),
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_storeDescriptionFocusNode),
            suffixIcon: _buildSuffixIcon(isValid: _isStorePhoneValid),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                  return 'Enter a valid phone number';
                }
              }
              return null;
            },
            focusNode: _storePhoneFocusNode,
          ),
          const SizedBox(height: 20),

          // Description Field
          CustomTextField(
            controller: _storeDescriptionController,
            label: 'Store Description',
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLines: 3,
            prefixIcon: Icon(Icons.description_outlined, color: AppTheme.primary),
            onSubmitted: (_) => _submitForm(),
            suffixIcon: _buildSuffixIcon(isValid: _isStoreDescriptionValid),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter store description';
              }
              if (value.length < 10) {
                return 'Description must be at least 10 characters';
              }
              return null;
            },
            focusNode: _storeDescriptionFocusNode,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedBuilder(
      animation: _validationAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: _isFormValid
                ? LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: _isFormValid
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: _isFormValid && !_isLoading ? _submitForm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFormValid ? Colors.transparent : AppTheme.earthLight,
              foregroundColor: _isFormValid ? Colors.white : AppTheme.earth,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isFormValid ? Colors.white : AppTheme.earth,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_business_outlined,
                        size: _getIconSize(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Create Store',
                        style: TextStyle(
                          fontSize: _getFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _storeDescriptionController.dispose();
    
    _storeNameFocusNode.dispose();
    _storeAddressFocusNode.dispose();
    _storePhoneFocusNode.dispose();
    _storeDescriptionFocusNode.dispose();
    
    _fadeController.dispose();
    _slideController.dispose();
    _validationController.dispose();
    
    super.dispose();
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
            _checkFormValidity(); // Revalidate form
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
            _checkFormValidity(); // Revalidate form
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
                      // Platform icon could be added here
                      Text(platform['name'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPlatform = value;
                });
                _checkFormValidity(); // Revalidate form
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
            ),
        ],
      ],
    );
  }
}
