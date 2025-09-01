import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/staff_credentials_modal.dart';
import 'package:vendor_app/widgets/custom_text_field.dart';
import 'package:vendor_app/models/user.dart' as app_models;

class CreateEditUserScreen extends ConsumerStatefulWidget {
  final app_models.User? user;
  const CreateEditUserScreen({super.key, this.user});

  @override
  ConsumerState<CreateEditUserScreen> createState() =>
      _CreateEditUserScreenState();
}

class _CreateEditUserScreenState extends ConsumerState<CreateEditUserScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _defaultPasswordController = TextEditingController();
  
  // Personal attributes controllers
  final _dateOfBirthController = TextEditingController();
  final _weddingAnniversaryController = TextEditingController();
  final _addressController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Focus nodes for managing keyboard navigation
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _defaultPasswordFocusNode = FocusNode();
  
  // Personal attributes focus nodes
  final _dateOfBirthFocusNode = FocusNode();
  final _weddingAnniversaryFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _hobbiesFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _validationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _validationAnimation;
  
  final Set<app_models.UserRole> _selectedRoles = {app_models.UserRole.staff}; // Default role
  bool _isLoading = false;
  bool _obscureDefaultPassword = true;
  bool _isPersonalDetailsExpanded = false; // Accordion state

  // Real-time validation states
  bool _isFirstNameValid = false;
  bool _isLastNameValid = false;
  bool _isEmailValid = false;
  bool _isPhoneValid = true; // Phone is optional, so default to valid
  bool _isDefaultPasswordValid = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _addValidationListeners();
    _populateFormForEdit();
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
    _firstNameController.addListener(_validateFirstNameRealTime);
    _lastNameController.addListener(_validateLastNameRealTime);
    _emailController.addListener(_validateEmailRealTime);
    _phoneController.addListener(_validatePhoneRealTime);
    _defaultPasswordController.addListener(_validateDefaultPasswordRealTime);
  }

  void _validateFirstNameRealTime() {
    final value = _firstNameController.text.trim();
    final isValid = value.isNotEmpty && 
        value.length >= 2 && 
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);
    
    if (_isFirstNameValid != isValid) {
      setState(() => _isFirstNameValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateLastNameRealTime() {
    final value = _lastNameController.text.trim();
    final isValid = value.isNotEmpty && 
        value.length >= 2 && 
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);
    
    if (_isLastNameValid != isValid) {
      setState(() => _isLastNameValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateEmailRealTime() {
    final value = _emailController.text.trim();
    final isValid = value.isNotEmpty && 
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
    
    if (_isEmailValid != isValid) {
      setState(() => _isEmailValid = isValid);
      _checkFormValidity();
    }
  }

  void _validatePhoneRealTime() {
    final value = _phoneController.text.trim();
    // Phone number is optional, so empty is valid
    final isValid = value.isEmpty || RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value);
    
    if (_isPhoneValid != isValid) {
      setState(() => _isPhoneValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateDefaultPasswordRealTime() {
    final value = _defaultPasswordController.text;
    final isValid = value.isNotEmpty && value.length >= 6;
    
    if (_isDefaultPasswordValid != isValid) {
      setState(() => _isDefaultPasswordValid = isValid);
      _checkFormValidity();
    }
  }

  // Removed password validation methods

  void _checkFormValidity() {
    final isValid = _isFirstNameValid && 
                   _isLastNameValid && 
                   _isEmailValid && 
                   _isPhoneValid &&
                   (widget.user != null || _isDefaultPasswordValid); // Password optional in edit mode
    
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
      if (isValid) {
        _validationController.forward();
      } else {
        _validationController.reverse();
      }
    }
  }

  void _populateFormForEdit() {
    if (widget.user != null) {
      final user = widget.user!;
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      
      // Populate personal details
      _dateOfBirthController.text = user.dateOfBirth != null 
          ? DateFormat('MMM dd, yyyy').format(user.dateOfBirth!)
          : '';
      _weddingAnniversaryController.text = user.weddingAnniversary != null 
          ? DateFormat('MMM dd, yyyy').format(user.weddingAnniversary!)
          : '';
      _addressController.text = user.address ?? '';
      _hobbiesController.text = user.hobbies ?? '';
      _notesController.text = user.notes ?? '';
      
      // Set the selected roles
      _selectedRoles.clear();
      _selectedRoles.addAll(user.roles);
      
      // Validate the pre-populated fields
      _validateFirstNameRealTime();
      _validateLastNameRealTime();
      _validateEmailRealTime();
      _validatePhoneRealTime();
      
      // For edit mode, we don't require password validation
      _isDefaultPasswordValid = true;
      _checkFormValidity();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _defaultPasswordController.dispose();
    
    // Personal details controllers
    _dateOfBirthController.dispose();
    _weddingAnniversaryController.dispose();
    _addressController.dispose();
    _hobbiesController.dispose();
    _notesController.dispose();
    
    _fadeController.dispose();
    _slideController.dispose();
    _validationController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _defaultPasswordFocusNode.dispose();
    
    // Personal details focus nodes
    _dateOfBirthFocusNode.dispose();
    _weddingAnniversaryFocusNode.dispose();
    _addressFocusNode.dispose();
    _hobbiesFocusNode.dispose();
    _notesFocusNode.dispose();
    
    super.dispose();
  }

  String _generateBusinessId() {
    // Generate a 13-digit code starting with BIZ-
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = timestamp.substring(timestamp.length - 9);
    return 'BIZ-$randomPart';
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userService = ref.read(userServiceProvider);
      
      if (widget.user != null) {
        // Edit mode - update existing user
        await userService.updateUser(
          userId: widget.user!.id,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          roles: _selectedRoles.toList(),
          // Personal details
          dateOfBirth: _dateOfBirthController.text.isEmpty 
              ? null 
              : DateFormat('MMM dd, yyyy').parse(_dateOfBirthController.text),
          weddingAnniversary: _weddingAnniversaryController.text.isEmpty 
              ? null 
              : DateFormat('MMM dd, yyyy').parse(_weddingAnniversaryController.text),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          hobbies: _hobbiesController.text.trim().isEmpty ? null : _hobbiesController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'User updated successfully!',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back
        Navigator.pop(context);

      } else {
        // Create mode - create new user
        final auth = FirebaseAuth.instance;  // Get FirebaseAuth instance
        
        // Create the user using the new method
        final user = await userService.addBusinessUser(
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          defaultPassword: _defaultPasswordController.text,
          roles: _selectedRoles.toList(),
          teamIds: [], // Empty array for now, can be populated later
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          profileImage: null, // Can be added later
          auth: auth,
          // Personal details
          dateOfBirth: _dateOfBirthController.text.isEmpty 
              ? null 
              : DateFormat('MMM dd, yyyy').parse(_dateOfBirthController.text),
          weddingAnniversary: _weddingAnniversaryController.text.isEmpty 
              ? null 
              : DateFormat('MMM dd, yyyy').parse(_weddingAnniversaryController.text),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          hobbies: _hobbiesController.text.trim().isEmpty ? null : _hobbiesController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'User created successfully!',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Show Staff Credentials Modal
        showStaffCredentialsModal(
          context: context,
          staffEmail: user.email,
          staffPassword: _defaultPasswordController.text,
          staffName: '${user.firstName} ${user.lastName}',
          businessName: user.businessName ?? 'Your Business',
          onClose: () {
            // Navigate back or reset form
            Navigator.pop(context);
          },
        );
      }

    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Failed to create user';
      
      // Extract user-friendly message from exception
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Check your Firestore security rules and ensure you have proper permissions.';
      } else if (e.toString().contains('email already exists')) {
        errorMessage = 'A user with this email already exists in this business.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else {
        // Get the error message without the Exception prefix
        final message = e.toString().replaceAll('Exception: ', '');
        errorMessage = message;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  errorMessage,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.secondary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method for date selection
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      controller.text = DateFormat('MMM dd, yyyy').format(picked);
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

  bool _shouldStackFields(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
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

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // We only need cardPadding here
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

  Widget _buildSuffixIcon({
    required bool isValid,
    Widget? actionButton,
  }) {
    if (actionButton != null) {
      return IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isValid) ...[
              _buildValidationTick(isValid),
              const SizedBox(width: 6),
            ],
            actionButton,
          ],
        ),
      );
    } else {
      return _buildValidationTick(isValid);
    }
  }

  Widget _buildUserForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = _getHorizontalPadding(context);
        
        return Column(
          children: [
            _buildRequiredFieldsCard(constraints, horizontalPadding),
            const SizedBox(height: 16),
            _buildOptionalFieldsCard(constraints, horizontalPadding),
          ],
        );
      },
    );
  }

  Widget _buildRequiredFieldsCard(BoxConstraints constraints, double horizontalPadding) {
    final shouldStack = _shouldStackFields(context);
    final iconSize = _getIconSize(context);
    final fontSize = _getFontSize(context, 18);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: _buildModernCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Responsive layout
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth,
                ),
                child: shouldStack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person_add_outlined,
                                  color: AppTheme.primary,
                                  size: iconSize,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'User Information',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Required',
                                  style: TextStyle(
                                    fontSize: _getFontSize(context, 11),
                                    color: AppTheme.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Form Progress Indicator
                          _buildFormProgressIndicator(),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_add_outlined,
                              color: AppTheme.primary,
                              size: iconSize,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'User Information',
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Required',
                              style: TextStyle(
                                fontSize: _getFontSize(context, 11),
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Form Progress Indicator
                          _buildFormProgressIndicator(),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Name Fields - Responsive layout
              shouldStack
                  ? Column(
                      children: [
                        CustomTextField(
                          controller: _firstNameController,
                          label: 'First Name',
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(_lastNameFocusNode),
                          suffixIcon: _buildSuffixIcon(isValid: _isFirstNameValid),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter first name';
                            }
                            if (value.length < 2) {
                              return 'Min 2 chars';
                            }
                            return null;
                          },
                          focusNode: _firstNameFocusNode,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocusNode),
                          suffixIcon: _buildSuffixIcon(isValid: _isLastNameValid),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter last name';
                            }
                            if (value.length < 2) {
                              return 'Min 2 chars';
                            }
                            return null;
                          },
                          focusNode: _lastNameFocusNode,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                            onSubmitted: (_) => FocusScope.of(context).requestFocus(_lastNameFocusNode),
                            suffixIcon: _buildSuffixIcon(isValid: _isFirstNameValid),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter first name';
                              }
                              if (value.length < 2) {
                                return 'Min 2 chars';
                              }
                              return null;
                            },
                            focusNode: _firstNameFocusNode,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                            onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocusNode),
                            suffixIcon: _buildSuffixIcon(isValid: _isLastNameValid),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter last name';
                              }
                              if (value.length < 2) {
                                return 'Min 2 chars';
                              }
                              return null;
                            },
                            focusNode: _lastNameFocusNode,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 20),

              // Email Field
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth,
                ),
                child: CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                  onSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocusNode),
                  suffixIcon: _buildSuffixIcon(isValid: _isEmailValid),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                      return 'Invalid email format';
                    }
                    return null;
                  },
                  focusNode: _emailFocusNode,
                ),
              ),
              const SizedBox(height: 20),

              // Phone Field
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth,
                ),
                child: CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  textInputAction: widget.user != null ? TextInputAction.done : TextInputAction.next,
                  prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primary),
                  onSubmitted: (_) => widget.user != null 
                      ? _saveUser() 
                      : FocusScope.of(context).requestFocus(_defaultPasswordFocusNode),
                  suffixIcon: _buildSuffixIcon(isValid: _isPhoneValid),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (value.length < 10) {
                        return 'Min 10 digits';
                      }
                    }
                    return null;
                  },
                  focusNode: _phoneFocusNode,
                ),
              ),
              const SizedBox(height: 20),

              // Default Password Field - Only show in create mode
              if (widget.user == null) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                  ),
                  child: CustomTextField(
                    controller: _defaultPasswordController,
                    label: 'Default Password',
                    obscureText: _obscureDefaultPassword,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.none,
                    prefixIcon: Icon(Icons.lock_outline, color: AppTheme.secondary),
                    onSubmitted: (_) => _saveUser(),
                    suffixIcon: _buildSuffixIcon(
                      isValid: _isDefaultPasswordValid,
                      actionButton: IconButton(
                        icon: Icon(
                          _obscureDefaultPassword ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.earth,
                          size: iconSize,
                        ),
                        onPressed: () {
                          setState(() => _obscureDefaultPassword = !_obscureDefaultPassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a default password';
                      }
                      if (value.length < 6) {
                        return 'Min 6 chars';
                      }
                      return null;
                    },
                    focusNode: _defaultPasswordFocusNode,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionalFieldsCard(BoxConstraints constraints, double horizontalPadding) {
    final iconSize = _getIconSize(context);
    final fontSize = _getFontSize(context, 18);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: _buildModernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accordion Header
            InkWell(
              onTap: () {
                setState(() {
                  _isPersonalDetailsExpanded = !_isPersonalDetailsExpanded;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.earth.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: AppTheme.earth,
                        size: iconSize,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Personal Details',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.earth.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Optional',
                        style: TextStyle(
                          fontSize: _getFontSize(context, 11),
                          color: AppTheme.earth,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _isPersonalDetailsExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppTheme.earth,
                        size: iconSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Accordion Content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Date of Birth Field
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: CustomTextField(
                      controller: _dateOfBirthController,
                      label: 'Date of Birth',
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icon(Icons.cake_outlined, color: AppTheme.primary),
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_weddingAnniversaryFocusNode),
                      focusNode: _dateOfBirthFocusNode,
                      onTap: () => _selectDate(context, _dateOfBirthController),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Wedding Anniversary Field
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: CustomTextField(
                      controller: _weddingAnniversaryController,
                      label: 'Wedding Anniversary',
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icon(Icons.favorite_outline, color: AppTheme.primary),
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_addressFocusNode),
                      focusNode: _weddingAnniversaryFocusNode,
                      onTap: () => _selectDate(context, _weddingAnniversaryController),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Address Field
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: CustomTextField(
                      controller: _addressController,
                      label: 'Address',
                      keyboardType: TextInputType.streetAddress,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primary),
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_hobbiesFocusNode),
                      focusNode: _addressFocusNode,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Hobbies Field
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: CustomTextField(
                      controller: _hobbiesController,
                      label: 'Hobbies & Interests',
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      prefixIcon: Icon(Icons.sports_esports_outlined, color: AppTheme.primary),
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_notesFocusNode),
                      focusNode: _hobbiesFocusNode,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Notes Field
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: CustomTextField(
                      controller: _notesController,
                      label: 'Additional Notes',
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      prefixIcon: Icon(Icons.note_outlined, color: AppTheme.primary),
                      onSubmitted: (_) => _saveUser(),
                      focusNode: _notesFocusNode,
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
              crossFadeState: _isPersonalDetailsExpanded 
                  ? CrossFadeState.showSecond 
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormProgressIndicator() {
    return AnimatedBuilder(
      animation: _validationAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = _getFontSize(context, 12);
            final iconSize = _getIconSize(context) - 4;
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isFormValid 
                    ? AppTheme.accent.withOpacity(0.1)
                    : AppTheme.earth.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isFormValid 
                      ? AppTheme.accent.withOpacity(0.3)
                      : AppTheme.earth.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isFormValid ? Icons.check_circle : Icons.edit_outlined,
                      color: _isFormValid ? AppTheme.accent : AppTheme.earth,
                      size: iconSize,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _isFormValid ? 'Ready' : 'Fill form',
                        style: TextStyle(
                          color: _isFormValid ? AppTheme.accent : AppTheme.earth,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserRoles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = _getHorizontalPadding(context);
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);
        
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _buildModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: AppTheme.secondary,
                        size: iconSize,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'User Roles',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the roles this user will have',
                  style: TextStyle(
                    fontSize: _getFontSize(context, 14),
                    color: AppTheme.earth,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Roles Grid - Responsive
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: app_models.UserRole.values.map((role) {
                      final isSelected = _selectedRoles.contains(role);
                      final roleColor = _getRoleColor(role);
                      final isStaff = role == app_models.UserRole.staff;
                      
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          minWidth: 0,
                        ),
                        child: IntrinsicWidth(
                          child: GestureDetector(
                            onTap: isStaff
                                ? null // Staff role cannot be deselected
                                : () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedRoles.remove(role);
                                      } else {
                                        _selectedRoles.add(role);
                                      }
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? roleColor.withOpacity(0.1)
                                    : AppTheme.softGreen,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? roleColor.withOpacity(0.3)
                                      : AppTheme.earthLight.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: roleColor.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected ? roleColor : AppTheme.earth,
                                    size: iconSize - 2,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _formatRoleName(role),
                                      style: TextStyle(
                                        color: isSelected ? roleColor : AppTheme.earth,
                                        fontWeight:
                                            isSelected ? FontWeight.w600 : FontWeight.w500,
                                        fontSize: _getFontSize(context, 14),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isStaff)
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          '(default)',
                                          style: TextStyle(
                                            fontSize: _getFontSize(context, 12),
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = _getHorizontalPadding(context);
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 16);
        
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _buildModernCard(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _validationAnimation,
                  builder: (context, child) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isFormValid
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: ElevatedButton(
                          onPressed: (_isLoading || !_isFormValid) ? null : _saveUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFormValid 
                                ? AppTheme.primary 
                                : AppTheme.earth.withOpacity(0.5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isFormValid ? Icons.save_outlined : Icons.edit_outlined,
                                      size: iconSize,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _isFormValid 
                                            ? (widget.user != null ? 'Update User' : 'Create User') 
                                            : 'Complete Form First',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: fontSize,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
                if (!_isFormValid) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: Text(
                      'Please fill all required fields correctly',
                      style: TextStyle(
                        color: AppTheme.earth,
                        fontSize: _getFontSize(context, 12),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRoleColor(app_models.UserRole role) {
    switch (role) {
      case app_models.UserRole.staff:
        return AppTheme.primary;
      case app_models.UserRole.manager:
        return AppTheme.accent;
      case app_models.UserRole.viewer:
        return AppTheme.earth;
      case app_models.UserRole.business_owner:
        return AppTheme.secondary;
      case app_models.UserRole.admin:
        return Colors.redAccent;
      default:
        return AppTheme.earth;
    }
  }

  String _formatRoleName(app_models.UserRole role) {
    switch (role) {
      case app_models.UserRole.staff:
        return 'Staff Member';
      case app_models.UserRole.manager:
        return 'Manager';
      case app_models.UserRole.viewer:
        return 'Viewer';
      case app_models.UserRole.business_owner:
        return 'Business Owner';
      case app_models.UserRole.admin:
        return 'Admin';
      default:
        return 'Unknown Role';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Text(
              widget.user != null ? 'Edit User' : 'Add New User',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: _getFontSize(context, 20),
              ),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios, 
            color: AppTheme.textPrimary,
            size: _getIconSize(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildUserForm(),
                      _buildUserRoles(),
                      _buildSaveButton(),
                      SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 32),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}