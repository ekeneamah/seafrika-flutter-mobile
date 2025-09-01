import 'package:flutter/material.dart';
import 'package:vendor_app/config/theme.dart';

/// A responsive contact information display widget that adapts to different screen sizes
class ResponsiveContactDisplay extends StatelessWidget {
  final String? name;
  final String? email;
  final String? phone;
  final String? address;
  final String? notes;
  final String? title;
  final Color? accentColor;
  final bool showActions;
  final VoidCallback? onEmailTap;
  final VoidCallback? onPhoneTap;
  final EdgeInsets? padding;

  const ResponsiveContactDisplay({
    Key? key,
    this.name,
    this.email,
    this.phone,
    this.address,
    this.notes,
    this.title = 'Contact Information',
    this.accentColor,
    this.showActions = true,
    this.onEmailTap,
    this.onPhoneTap,
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
            const SizedBox(height: 16),
          ],
          _buildContactInfo(context),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.earthLight.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 2),
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
    final color = accentColor ?? AppTheme.primary;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
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
              fontSize: _getFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo(BuildContext context) {
    final shouldStack = _shouldStackFields(context);
    
    return Column(
      children: [
        // Main contact fields
        if (name != null) _buildInfoRow(context, 'Name', name!),
        
        shouldStack 
            ? _buildStackedContactFields(context)
            : _buildRowContactFields(context),
        
        // Additional fields
        if (address != null && address!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildInfoRow(context, 'Address', address!),
        ],
        
        if (notes != null && notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildInfoRow(context, 'Notes', notes!),
        ],
      ],
    );
  }

  Widget _buildStackedContactFields(BuildContext context) {
    return Column(
      children: [
        if (email != null && email!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildEmailInfoRow(context),
        ],
        if (phone != null && phone!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildPhoneInfoRow(context),
        ],
      ],
    );
  }

  Widget _buildRowContactFields(BuildContext context) {
    final hasEmail = email != null && email!.isNotEmpty;
    final hasPhone = phone != null && phone!.isNotEmpty;
    
    if (!hasEmail && !hasPhone) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (hasEmail) ...[
            Expanded(child: _buildEmailInfoRow(context)),
            if (hasPhone) const SizedBox(width: 16),
          ],
          if (hasPhone) Expanded(child: _buildPhoneInfoRow(context)),
        ],
      ),
    );
  }

  Widget _buildEmailInfoRow(BuildContext context) {
    return _buildActionableInfoRow(
      context, 
      'Email', 
      email!, 
      Icons.email_outlined,
      onEmailTap,
    );
  }

  Widget _buildPhoneInfoRow(BuildContext context) {
    return _buildActionableInfoRow(
      context, 
      'Phone', 
      phone!, 
      Icons.phone_outlined,
      onPhoneTap,
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _getLabelWidth(context),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.earth,
                fontSize: _getFontSize(context, 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: _getFontSize(context, 14),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionableInfoRow(
    BuildContext context, 
    String label, 
    String value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    final color = accentColor ?? AppTheme.primary;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: _getLabelWidth(context),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.earth,
                fontSize: _getFontSize(context, 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: showActions && onTap != null
                ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: color,
                            size: _getIconSize(context) * 0.8,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              value,
                              style: TextStyle(
                                color: color,
                                fontSize: _getFontSize(context, 14),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: _getFontSize(context, 14),
                      height: 1.3,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Responsive helper methods
  double _getCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return 20.0; // Tablet/Desktop
    return 16.0; // Mobile
  }

  bool _shouldStackFields(BuildContext context) {
    return MediaQuery.of(context).size.width < 500;
  }

  double _getIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 18.0; // Mobile
    if (screenWidth < 1200) return 20.0; // Tablet
    return 22.0; // Desktop
  }

  double _getFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize - 1; // Mobile
    return baseSize; // Tablet/Desktop
  }

  double _getLabelWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 80.0; // Mobile
    if (screenWidth < 1200) return 100.0; // Tablet
    return 120.0; // Desktop
  }
}
