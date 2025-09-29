import 'package:flutter/material.dart';
import 'package:vendor_app/config/theme.dart';

/// A responsive contact information form widget that adapts to different screen sizes
class ResponsiveContactForm extends StatelessWidget {
  final TextEditingController? phoneController;
  final TextEditingController? emailController;
  final TextEditingController? addressController;
  final FocusNode? phoneFocusNode;
  final FocusNode? emailFocusNode;
  final FocusNode? addressFocusNode;
  final String? Function(String?)? phoneValidator;
  final String? Function(String?)? emailValidator;
  final String? Function(String?)? addressValidator;
  final Function(String)? onPhoneSubmitted;
  final Function(String)? onEmailSubmitted;
  final Function(String)? onAddressSubmitted;
  final bool showAddress;
  final bool isPhoneRequired;
  final bool isEmailRequired;
  final bool isAddressRequired;
  final String? phoneHint;
  final String? emailHint;
  final String? addressHint;
  final String? title;
  final Color? accentColor;
  final EdgeInsets? padding;

  const ResponsiveContactForm({
    Key? key,
    this.phoneController,
    this.emailController,
    this.addressController,
    this.phoneFocusNode,
    this.emailFocusNode,
    this.addressFocusNode,
    this.phoneValidator,
    this.emailValidator,
    this.addressValidator,
    this.onPhoneSubmitted,
    this.onEmailSubmitted,
    this.onAddressSubmitted,
    this.showAddress = false,
    this.isPhoneRequired = true,
    this.isEmailRequired = true,
    this.isAddressRequired = false,
    this.phoneHint = '+234 xxx xxx xxxx',
    this.emailHint = 'store@example.com',
    this.addressHint = 'Enter address',
    this.title = 'Contact Information',
    this.accentColor,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildModernCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            _buildSectionHeader(context),
            const SizedBox(height: 24),
          ],
          _buildContactFields(context),
        ],
      ),
    );
  }

  Widget _buildModernCard({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
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
        padding: padding ?? EdgeInsets.all(_getCardPadding(context)),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    final iconSize = _getIconSize(context);
    final color = accentColor ?? AppTheme.accent;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.contact_phone_outlined,
            color: color,
            size: iconSize,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title!,
            style: TextStyle(
              fontSize: _getFontSize(context, 20),
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildContactFields(BuildContext context) {
    final shouldStack = _shouldStackFields(context);

    return Column(
      children: [
        // Phone and Email fields
        shouldStack ? _buildStackedFields(context) : _buildRowFields(context),

        // Address field (if enabled)
        if (showAddress) ...[
          const SizedBox(height: 20),
          _buildAddressField(context),
        ],
      ],
    );
  }

  Widget _buildStackedFields(BuildContext context) {
    return Column(
      children: [
        _buildPhoneField(context),
        const SizedBox(height: 20),
        _buildEmailField(context),
      ],
    );
  }

  Widget _buildRowFields(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildPhoneField(context)),
        const SizedBox(width: 16),
        Expanded(child: _buildEmailField(context)),
      ],
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    final color = accentColor ?? AppTheme.accent;

    return TextFormField(
      controller: phoneController,
      focusNode: phoneFocusNode,
      textInputAction:
          showAddress ? TextInputAction.next : TextInputAction.done,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: isPhoneRequired ? 'Phone *' : 'Phone',
        hintText: phoneHint,
        prefixIcon: Icon(Icons.phone_outlined, color: color),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _getFieldVerticalPadding(context),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.earthLight.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.earthLight.withOpacity(0.3)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.secondary, width: 1),
        ),
      ),
      validator: phoneValidator ??
          (v) {
            if (isPhoneRequired && (v == null || v.isEmpty)) {
              return 'Enter phone number';
            }
            if (v != null &&
                v.isNotEmpty &&
                !RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(v)) {
              return 'Enter valid phone number';
            }
            return null;
          },
      onFieldSubmitted: onPhoneSubmitted,
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final color = accentColor ?? AppTheme.accent;

    return TextFormField(
      controller: emailController,
      focusNode: emailFocusNode,
      textInputAction:
          showAddress ? TextInputAction.next : TextInputAction.done,
      keyboardType: TextInputType.emailAddress,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: isEmailRequired ? 'Email *' : 'Email',
        hintText: emailHint,
        prefixIcon: Icon(Icons.email_outlined, color: color),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _getFieldVerticalPadding(context),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.earthLight.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.earthLight.withOpacity(0.3)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.secondary, width: 1),
        ),
      ),
      validator: emailValidator ??
          (v) {
            if (isEmailRequired && (v == null || v.isEmpty)) {
              return 'Enter email address';
            }
            if (v != null &&
                v.isNotEmpty &&
                !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
              return 'Enter valid email address';
            }
            return null;
          },
      onFieldSubmitted: onEmailSubmitted,
    );
  }

  Widget _buildAddressField(BuildContext context) {
    final color = accentColor ?? AppTheme.accent;

    return TextFormField(
      controller: addressController,
      focusNode: addressFocusNode,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.streetAddress,
      textCapitalization: TextCapitalization.words,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: isAddressRequired ? 'Address *' : 'Address',
        hintText: addressHint,
        prefixIcon: Icon(Icons.location_on_outlined, color: color),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _getFieldVerticalPadding(context),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.earthLight.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.earthLight.withOpacity(0.3)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.secondary, width: 1),
        ),
      ),
      validator: addressValidator ??
          (v) {
            if (isAddressRequired && (v == null || v.isEmpty)) {
              return 'Enter address';
            }
            if (v != null && v.isNotEmpty && v.length < 5) {
              return 'Address must be at least 5 characters';
            }
            return null;
          },
      onFieldSubmitted: onAddressSubmitted,
    );
  }

  // Responsive helper methods
  double _getCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return 24.0; // Tablet/Desktop
    return 16.0; // Mobile
  }

  bool _shouldStackFields(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  double _getIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 20.0; // Mobile
    if (screenWidth < 1200) return 22.0; // Tablet
    return 24.0; // Desktop
  }

  double _getFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize - 2; // Mobile
    return baseSize; // Tablet/Desktop
  }

  double _getFieldVerticalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 12.0; // Mobile
    return 16.0; // Tablet/Desktop
  }
}
