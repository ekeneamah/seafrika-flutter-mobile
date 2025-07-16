import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vendor_app/config/theme.dart';

class StaffCredentialsModal extends StatefulWidget {
  final String staffEmail;
  final String staffPassword;
  final String staffName;
  final String businessName;
  final VoidCallback? onClose;

  const StaffCredentialsModal({
    Key? key,
    required this.staffEmail,
    required this.staffPassword,
    required this.staffName,
    required this.businessName,
    this.onClose,
  }) : super(key: key);

  @override
  State<StaffCredentialsModal> createState() => _StaffCredentialsModalState();
}

class _StaffCredentialsModalState extends State<StaffCredentialsModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  bool _isEmailCopied = false;
  bool _isPasswordCopied = false;
  bool _isAllCopied = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard(String text, String type) async {
    await Clipboard.setData(ClipboardData(text: text));
    
    setState(() {
      if (type == 'email') {
        _isEmailCopied = true;
      } else if (type == 'password') {
        _isPasswordCopied = true;
      } else if (type == 'all') {
        _isAllCopied = true;
      }
    });
    
    // Reset copied state after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (type == 'email') {
            _isEmailCopied = false;
          } else if (type == 'password') {
            _isPasswordCopied = false;
          } else if (type == 'all') {
            _isAllCopied = false;
          }
        });
      }
    });

    // Show success feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('${type == 'all' ? 'Credentials' : type.capitalize()} copied to clipboard!'),
            ],
          ),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareCredentials() async {
    final shareText = '''
🎉 Welcome to ${widget.businessName}!

Your staff account has been created successfully.

📧 Email: ${widget.staffEmail}
🔐 Password: ${widget.staffPassword}

📋 Next Steps:
1. Download the VendorHub app
2. Select "Staff Member" login
3. Use the credentials above to sign in
4. Change your password after first login for security

Welcome to the team! 🚀

#VendorHub #StaffAccess
''';

    try {
      await Share.share(shareText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    }
  }

  void _closeModal() {
    _slideController.reverse().then((_) {
      widget.onClose?.call();
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.08),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withOpacity(0.1),
            AppTheme.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Success Icon with Pulse Animation
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Staff Account Created!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share these credentials with ${widget.staffName}',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.earth,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff Name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.softGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accent.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff Member',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.earth,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.staffName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Email Credential
          _buildCredentialItem(
            'Email Address',
            widget.staffEmail,
            Icons.email_outlined,
            AppTheme.primary,
            'email',
            _isEmailCopied,
          ),
          const SizedBox(height: 16),
          
          // Password Credential
          _buildCredentialItem(
            'Temporary Password',
            widget.staffPassword,
            Icons.lock_outline,
            AppTheme.secondary,
            'password',
            _isPasswordCopied,
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialItem(
    String label,
    String value,
    IconData icon,
    Color color,
    String type,
    bool isCopied,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Credential Value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.earthLight.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFamily: type == 'password' ? 'monospace' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _copyToClipboard(value, type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCopied 
                          ? AppTheme.accent.withOpacity(0.1)
                          : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCopied ? Icons.check : Icons.copy,
                      color: isCopied ? AppTheme.accent : color,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    final instructions = [
      {
        'step': '1',
        'title': 'Share Credentials',
        'description': 'Send the email and password to ${widget.staffName}',
        'icon': Icons.share_outlined,
      },
      {
        'step': '2',
        'title': 'Download VendorHub',
        'description': 'Staff member downloads and installs the app',
        'icon': Icons.download_outlined,
      },
      {
        'step': '3',
        'title': 'Staff Login',
        'description': 'Use "Staff Member" login with these credentials',
        'icon': Icons.login_outlined,
      },
      {
        'step': '4',
        'title': 'Change Password',
        'description': 'Staff should change password after first login',
        'icon': Icons.security_outlined,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.earth.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppTheme.earth,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Next Steps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          ...instructions.map((instruction) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.whiteSmoke,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.earthLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Step Number
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accent, AppTheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        instruction['step'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      instruction['icon'] as IconData,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instruction['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          instruction['description'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.earth,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final allCredentials = '''
Staff Account for ${widget.businessName}

Name: ${widget.staffName}
Email: ${widget.staffEmail}
Password: ${widget.staffPassword}

Next Steps:
1. Download VendorHub app
2. Select "Staff Member" login
3. Use credentials above
4. Change password after first login
''';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Copy All Button
          Container(
            width: double.infinity,
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
            child: ElevatedButton.icon(
              onPressed: () => _copyToClipboard(allCredentials, 'all'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: Icon(_isAllCopied ? Icons.check : Icons.copy, size: 20),
              label: Text(
                _isAllCopied ? 'Copied!' : 'Copy All Credentials',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Share Button
          Container(
            width: double.infinity,
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
            child: ElevatedButton.icon(
              onPressed: _shareCredentials,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.share_outlined, size: 20),
              label: const Text(
                'Share Credentials',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Close Button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _closeModal,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  color: AppTheme.earth,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildModernCard(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildCredentialsSection(),
                    _buildInstructions(),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Helper function to show the modal
void showStaffCredentialsModal({
  required BuildContext context,
  required String staffEmail,
  required String staffPassword,
  required String staffName,
  required String businessName,
  VoidCallback? onClose,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StaffCredentialsModal(
      staffEmail: staffEmail,
      staffPassword: staffPassword,
      staffName: staffName,
      businessName: businessName,
      onClose: onClose,
    ),
  );
}