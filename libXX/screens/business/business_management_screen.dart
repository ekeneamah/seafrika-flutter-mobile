import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/business.dart';
import 'package:vendor_app/services/business_service.dart';
import 'package:vendor_app/providers/service_providers.dart';

class BusinessManagementScreen extends ConsumerStatefulWidget {
  final String? businessId; // null for create, businessId for edit

  const BusinessManagementScreen({super.key, this.businessId});

  @override
  ConsumerState<BusinessManagementScreen> createState() => _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends ConsumerState<BusinessManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _industryController = TextEditingController(); // Added industry controller
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Focus nodes for proper keyboard navigation
  final _nameFocusNode = FocusNode();
  final _industryFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _websiteFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isLoadingBusiness = false;
  String? _selectedCountry;
  String? _selectedState;
  String? _selectedIndustry;

  // Add these state variables for name availability checking
  bool _isCheckingName = false;
  String? _nameAvailabilityMessage;
  bool _isNameAvailable = true;
  Timer? _nameCheckTimer;

  final List<String> _industries = [
    'Technology & Digital Services',
    'Retail & E-commerce',
    'Food & Beverage',
    'Health & Wellness',
    'Professional Services',
    'Other',
  ];

  final Map<String, List<String>> _countryStates = {
    'Nigeria': [
      'Lagos',
      'Abuja',
      'Kano',
      'Rivers',
      'Oyo',
      'Kaduna',
      'Enugu',
      'Anambra',
      'Ogun',
      'Edo',
      'Delta',
      'Akwa Ibom',
      'Cross River',
      'Benue',
      'Borno',
      'Plateau',
      'Sokoto',
      'Katsina',
      'Kwara',
      'Ondo',
      'Osun',
      'Ekiti',
      'Imo',
      'Abia',
      'Bauchi',
      'Gombe',
      'Yobe',
      'Taraba',
      'Niger',
      'Jigawa',
      'Zamfara',
      'Kebbi',
      'Nasarawa',
      'Bayelsa',
      'Ebonyi'
    ],
    'Ghana': [
      'Greater Accra',
      'Ashanti',
      'Western',
      'Eastern',
      'Northern',
      'Volta',
      'Central',
      'Upper East',
      'Upper West',
      'Bono',
      'Ahafo',
      'Bono East',
      'Oti',
      'North East',
      'Savannah',
      'Western North'
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.businessId != null) {
      _loadBusiness();
    } else {
      // Auto-focus the first field for new business creation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _nameFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _industryController.dispose(); // Added industry controller disposal
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    
    // Dispose focus nodes
    _nameFocusNode.dispose();
    _industryFocusNode.dispose();
    _addressFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _websiteFocusNode.dispose();
    _descriptionFocusNode.dispose();
    
    // Cancel timer if it exists
    _nameCheckTimer?.cancel();
    
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    setState(() => _isLoadingBusiness = true);
    try {
      final businessService = BusinessService();
      final business = await businessService.getBusiness(widget.businessId!);
      if (business != null) {
        setState(() {
          _nameController.text = business.name;
          _addressController.text = business.address;
          _industryController.text = business.industry ?? ''; // Keep for custom input
          _selectedIndustry = business.industry != null && _industries.contains(business.industry) 
              ? business.industry 
              : (business.industry?.isNotEmpty == true ? 'Other' : null);
          _phoneController.text = business.phone ?? '';
          _emailController.text = business.email ?? '';
          _websiteController.text = business.website ?? '';
          _descriptionController.text = business.description ?? '';
          _selectedCountry = business.country;
          _selectedState = business.state;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading business: $e', isError: true);
    } finally {
      setState(() => _isLoadingBusiness = false);
    }
  }

  Future<void> _saveBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCountry == null || _selectedState == null) {
      _showSnackBar('Please select country and state', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final businessService = BusinessService();
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (widget.businessId == null) {
        // Create new business
        String? industryValue;
        if (_selectedIndustry == 'Other') {
          industryValue = _industryController.text.trim().isEmpty ? null : _industryController.text.trim();
        } else {
          industryValue = _selectedIndustry;
        }
        
        final business = Business(
          id: '',
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          country: _selectedCountry!,
          state: _selectedState!,
          industry: industryValue,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          ownerId: currentUser.id,
          isActive: true, // Explicitly set isActive to true for Firestore rules
          createdAt: DateTime.now(),
        );

        // Check if business name is available before creating
        final isAvailable = await businessService.isBusinessNameAvailable(business.name, business.country);
        if (!isAvailable) {
          throw Exception('A business with this name already exists in ${business.country}. Please choose a different name.');
        }

        await businessService.createBusiness(business);
        _showSnackBar('Business created successfully!', isError: false);
        
        // Navigate to business list screen after successful creation
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.businessList);
        }
      } else {
        // Update existing business
        String? industryValue;
        if (_selectedIndustry == 'Other') {
          industryValue = _industryController.text.trim().isEmpty ? null : _industryController.text.trim();
        } else {
          industryValue = _selectedIndustry;
        }
        
        final updates = {
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'country': _selectedCountry!,
          'state': _selectedState!,
          'industry': industryValue,
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        };

        await businessService.updateBusiness(widget.businessId!, updates);
        _showSnackBar('Business updated successfully!', isError: false);
        
        // For updates, just pop back to previous screen
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Method to check business name availability
  Future<void> _checkBusinessNameAvailability(String name) async {
    if (name.trim().isEmpty || name.trim().length < 2) {
      setState(() {
        _nameAvailabilityMessage = null;
        _isNameAvailable = true;
      });
      return;
    }

    if (_selectedCountry == null) {
      setState(() {
        _nameAvailabilityMessage = 'Please select a country first';
        _isNameAvailable = false;
      });
      return;
    }

    setState(() {
      _isCheckingName = true;
      _nameAvailabilityMessage = null;
    });

    try {
      final businessService = BusinessService();
      final isAvailable = await businessService.isBusinessNameAvailable(name.trim(), _selectedCountry!);
      
      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _isNameAvailable = isAvailable;
          _nameAvailabilityMessage = isAvailable 
              ? 'Business name is available!' 
              : 'Business name is already taken in ${_selectedCountry}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _nameAvailabilityMessage = 'Error checking name availability';
          _isNameAvailable = false;
        });
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.businessId == null ? 'Create Business' : 'Edit Business',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoadingBusiness
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBusinessForm(),
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBusinessForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Business Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // Business Name
          TextFormField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.words,
            onFieldSubmitted: (_) {
              // Focus moves to industry dropdown, but we can't focus dropdowns
              // so we'll let the system handle it
              _nameFocusNode.unfocus();
            },
            decoration: InputDecoration(
              labelText: 'Business Name *',
              hintText: 'Enter your business name',
              prefixIcon: Icon(Icons.business_outlined, color: AppTheme.accent),
              suffixIcon: _isCheckingName 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _nameAvailabilityMessage != null
                      ? Icon(
                          _isNameAvailable ? Icons.check_circle : Icons.error,
                          color: _isNameAvailable ? Colors.green : Colors.red,
                        )
                      : null,
              helperText: _nameAvailabilityMessage,
              helperStyle: TextStyle(
                color: _isNameAvailable ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter business name';
              }
              if (value.trim().length < 2) {
                return 'Business name must be at least 2 characters';
              }
              if (value.trim().length > 100) {
                return 'Business name must be less than 100 characters';
              }
              // Check for invalid characters
              final invalidChars = RegExp(r'[<>@#$%^&*()+=\[\]{}|\\/:";,?~`]');
              if (invalidChars.hasMatch(value)) {
                return 'Business name contains invalid characters';
              }
              // Check availability (only for create mode)
              if (widget.businessId == null && !_isNameAvailable) {
                return 'Business name is not available';
              }
              return null;
            },
            // Add this listener to check name availability in real-time
            onChanged: (value) {
              // Cancel the previous timer if still running
              _nameCheckTimer?.cancel();
              
              // Start a new timer for 500ms (adjust as needed)
              _nameCheckTimer = Timer(const Duration(milliseconds: 500), () {
                _checkBusinessNameAvailability(value);
              });
            },
          ),
          const SizedBox(height: 20),

          // Industry
          DropdownButtonFormField<String>(
            value: _selectedIndustry,
            decoration: InputDecoration(
              labelText: 'Industry',
              prefixIcon: Icon(Icons.category_outlined, color: AppTheme.accent),
            ),
            isExpanded: true,
            items: _industries.map((industry) {
              return DropdownMenuItem(
                value: industry,
                child: Text(industry),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedIndustry = value;
                // Clear custom industry input when not "Other"
                if (value != 'Other') {
                  _industryController.clear();
                }
              });
              // Auto-focus custom field when "Other" is selected
              if (value == 'Other') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _industryFocusNode.requestFocus();
                });
              }
            },
            validator: (value) => value == null ? 'Please select an industry' : null,
          ),
          const SizedBox(height: 20),

          // Custom Industry Input (shown only when "Other" is selected)
          if (_selectedIndustry == 'Other') ...[
            TextFormField(
              controller: _industryController,
              focusNode: _industryFocusNode,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              onFieldSubmitted: (_) => _addressFocusNode.requestFocus(),
              decoration: InputDecoration(
                labelText: 'Custom Industry *',
                hintText: 'Enter your specific industry',
                prefixIcon: Icon(Icons.edit_outlined, color: AppTheme.accent),
              ),
              validator: (value) {
                if (_selectedIndustry == 'Other' && (value == null || value.trim().isEmpty)) {
                  return 'Please enter your industry';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],

          // Business Address
          TextFormField(
            controller: _addressController,
            focusNode: _addressFocusNode,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
            maxLines: 2,
            onFieldSubmitted: (_) {
              // Focus will move to country dropdown, but we can't focus dropdowns
              // so we'll let the system handle it
              _addressFocusNode.unfocus();
            },
            decoration: InputDecoration(
              labelText: 'Business Address *',
              hintText: 'Enter your business address',
              prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.accent),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter business address';
              }
              if (value.trim().length < 5) {
                return 'Address must be at least 5 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Country Dropdown
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: InputDecoration(
              labelText: 'Country *',
              prefixIcon: Icon(Icons.flag_outlined, color: AppTheme.accent),
            ),
            items: _countryStates.keys.map((country) {
              return DropdownMenuItem(
                value: country,
                child: Text(country),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCountry = value;
                _selectedState = null; // Reset state when country changes
              });
              
              // Re-check name availability when country changes
              if (_nameController.text.isNotEmpty) {
                _checkBusinessNameAvailability(_nameController.text);
              }
            },
            validator: (value) => value == null ? 'Please select a country' : null,
          ),
          const SizedBox(height: 20),

          // State Dropdown
          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration: InputDecoration(
              labelText: 'State *',
              prefixIcon: Icon(Icons.map_outlined, color: AppTheme.accent),
            ),
            items: (_selectedCountry != null
                    ? (_countryStates[_selectedCountry!] ?? <String>[])
                    : <String>[])
                .map<DropdownMenuItem<String>>(
                    (state) => DropdownMenuItem<String>(
                          value: state,
                          child: Text(state),
                        ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedState = value;
              });
            },
            validator: (value) => value == null ? 'Please select a state' : null,
          ),
          const SizedBox(height: 20),

          // Phone (Optional)
          TextFormField(
            controller: _phoneController,
            focusNode: _phoneFocusNode,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15), // Maximum phone number length
            ],
            onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter business phone number',
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.accent),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (value.length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Email (Optional)
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onFieldSubmitted: (_) => _websiteFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'Business Email',
              hintText: 'Enter business email',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.accent),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Website (Optional)
          TextFormField(
            controller: _websiteController,
            focusNode: _websiteFocusNode,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onFieldSubmitted: (_) => _descriptionFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'Website',
              hintText: 'https://yourwebsite.com',
              prefixIcon: Icon(Icons.language_outlined, color: AppTheme.accent),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^https?://[^\s/$.?#].[^\s]*$').hasMatch(value)) {
                  return 'Please enter a valid website URL';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Description (Optional)
          TextFormField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            maxLength: 500,
            onFieldSubmitted: (_) {
              _descriptionFocusNode.unfocus();
              _saveBusiness(); // Submit form when user taps Done
            },
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe your business',
              prefixIcon: Icon(Icons.description_outlined, color: AppTheme.accent),
            ),
          ),
          // Business name availability message
          if (_nameAvailabilityMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _nameAvailabilityMessage!,
              style: TextStyle(
                color: _isNameAvailable ? Colors.green : Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveBusiness,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
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
                    widget.businessId == null ? Icons.add : Icons.save,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.businessId == null ? 'Create Business' : 'Update Business',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
