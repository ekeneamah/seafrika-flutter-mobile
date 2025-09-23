import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/screens/integrations/whatsapp_integration_screen.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';

class AddIntegrationScreen extends ConsumerStatefulWidget {
  const AddIntegrationScreen({super.key});

  @override
  ConsumerState<AddIntegrationScreen> createState() =>
      _AddIntegrationScreenState();
}

class _AddIntegrationScreenState extends ConsumerState<AddIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  String? _selectedPlatform;
  String _selectedCategory = 'ecommerce';
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, bool> _expandedCategories = {
    'social': false,
    'ecommerce': false,
    'marketplace': false,
    'payment': false,
    'reviews': false,
  };

  final Map<String, List<Map<String, dynamic>>> _platformsByCategory = {
    'ecommerce': [
      {
        'id': 'shopify',
        'name': 'Shopify',
        'icon': 'assets/icons/shopify.png',
        'fields': ['apiKey', 'apiSecret', 'storeUrl'],
        'description': 'Connect your Shopify store for seamless inventory sync',
      },
      {
        'id': 'woocommerce',
        'name': 'WooCommerce',
        'icon': 'assets/icons/woocommerce.png',
        'fields': ['consumerKey', 'consumerSecret', 'storeUrl'],
        'description': 'Integrate with your WordPress WooCommerce store',
      },
      {
        'id': 'magento',
        'name': 'Magento',
        'icon': 'assets/icons/magento.png',
        'fields': ['accessToken', 'storeUrl'],
        'description': 'Connect your Magento e-commerce platform',
      },
    ],
    'marketplace': [
      {
        'id': 'amazon',
        'name': 'Amazon',
        'icon': 'assets/icons/amazon.png',
        'fields': ['accessKey', 'secretKey', 'marketplaceId'],
        'description': 'Sell on Amazon marketplace with automated sync',
      },
      {
        'id': 'ebay',
        'name': 'eBay',
        'icon': 'assets/icons/ebay.png',
        'fields': ['appId', 'certId', 'userToken'],
        'description': 'List and manage products on eBay marketplace',
      },
    ],
    'payment': [
      {
        'id': 'stripe',
        'name': 'Stripe',
        'icon': 'assets/icons/stripe.png',
        'fields': ['publishableKey', 'secretKey'],
        'description': 'Process payments with Stripe integration',
      },
      {
        'id': 'paypal',
        'name': 'PayPal',
        'icon': 'assets/icons/paypal.png',
        'fields': ['clientId', 'clientSecret'],
        'description': 'Accept PayPal payments in your store',
      },
      {
        'id': 'square',
        'name': 'Square',
        'icon': 'assets/icons/square.png',
        'fields': ['applicationId', 'accessToken'],
        'description': 'Integrate Square payment processing',
      },
      {
        'id': 'razorpay',
        'name': 'Razorpay',
        'icon': 'assets/icons/razorpay.png',
        'fields': ['keyId', 'keySecret'],
        'description': 'Accept payments via Razorpay (India)',
      },
      {
        'id': 'paystack',
        'name': 'Paystack',
        'icon': 'assets/icons/paystack.png',
        'fields': ['publicKey', 'secretKey'],
        'description': 'Payment processing for African businesses',
      },
      {
        'id': 'flutterwave',
        'name': 'Flutterwave',
        'icon': 'assets/icons/flutterwave.png',
        'fields': ['publicKey', 'secretKey'],
        'description': 'Global payment solutions for African businesses',
      },
    ],
    'social': [
      {
        'id': 'facebook',
        'name': 'Facebook',
        'icon': 'assets/icons/facebook.png',
        'fields': ['appId', 'appSecret', 'accessToken'],
        'description': 'Connect Facebook for marketing and customer engagement',
      },
      {
        'id': 'instagram',
        'name': 'Instagram',
        'icon': 'assets/icons/instagram.png',
        'fields': ['appId', 'appSecret', 'accessToken'],
        'description': 'Promote products on Instagram Business',
      },
      {
        'id': 'twitter',
        'name': 'Twitter',
        'icon': 'assets/icons/twitter.png',
        'fields': [
          'consumerKey',
          'consumerSecret',
          'accessToken',
          'accessTokenSecret'
        ],
        'description': 'Share products and engage customers on Twitter',
      },
      {
        'id': 'tiktok',
        'name': 'TikTok',
        'icon': 'assets/icons/tiktok.png',
        'fields': ['appId', 'appSecret', 'accessToken'],
        'description': 'Reach younger audiences through TikTok marketing',
      },
      {
        'id': 'whatsapp_business',
        'name': 'WhatsApp Business',
        'icon': 'assets/icons/whatsapp.png',
        'fields': ['phoneNumberId', 'accessToken'],
        'description': 'Customer support and marketing via WhatsApp',
      },
      {
        'id': 'telegram',
        'name': 'Telegram',
        'icon': 'assets/icons/telegram.png',
        'fields': ['botToken', 'chatId'],
        'description': 'Automated customer service with Telegram bot',
      },
    ],
    'reviews': [
      {
        'id': 'google_business',
        'name': 'Google My Business',
        'icon': 'assets/icons/google_business.png',
        'fields': ['placeId', 'apiKey'],
        'description': 'Monitor and respond to Google Business reviews',
      },
      {
        'id': 'google_reviews',
        'name': 'Google Reviews',
        'icon': 'assets/icons/google_reviews.png',
        'fields': ['businessId', 'serviceAccountKey'],
        'description': 'Advanced Google Reviews management and analytics',
      },
      {
        'id': 'trustpilot',
        'name': 'Trustpilot',
        'icon': 'assets/icons/trustpilot.png',
        'fields': ['apiKey', 'businessUnitId'],
        'description': 'Collect and manage Trustpilot customer reviews',
      },
      {
        'id': 'yelp',
        'name': 'Yelp',
        'icon': 'assets/icons/yelp.png',
        'fields': ['apiKey', 'businessId'],
        'description': 'Track Yelp reviews and business insights',
      },
      {
        'id': 'tripadvisor',
        'name': 'TripAdvisor',
        'icon': 'assets/icons/tripadvisor.png',
        'fields': ['apiKey', 'locationId'],
        'description': 'Hospitality and travel review management',
      },
      {
        'id': 'bazaarvoice',
        'name': 'Bazaarvoice',
        'icon': 'assets/icons/bazaarvoice.png',
        'fields': ['apiKey', 'clientId'],
        'description': 'Enterprise review and rating management',
      },
      {
        'id': 'yotpo',
        'name': 'Yotpo',
        'icon': 'assets/icons/yotpo.png',
        'fields': ['appKey', 'secret'],
        'description': 'Reviews, ratings, and visual marketing',
      },
      {
        'id': 'reviews_io',
        'name': 'Reviews.io',
        'icon': 'assets/icons/reviews_io.png',
        'fields': ['apiKey', 'storeId'],
        'description': 'Verified customer review platform',
      },
      {
        'id': 'shopify_reviews',
        'name': 'Shopify Reviews',
        'icon': 'assets/icons/shopify_reviews.png',
        'fields': ['shopDomain', 'accessToken'],
        'description': 'Native Shopify product reviews integration',
      },
      {
        'id': 'woocommerce_reviews',
        'name': 'WooCommerce Reviews',
        'icon': 'assets/icons/woocommerce_reviews.png',
        'fields': ['consumerKey', 'consumerSecret', 'storeUrl'],
        'description': 'WooCommerce product reviews and ratings',
      },
    ],
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBusinessSelection();
    });
  }

  Future<void> _checkBusinessSelection() async {
    final hasSelected = await BusinessPreferencesHelper.hasSelectedBusiness();
    if (!hasSelected && mounted) {
      _showBusinessSelectionDialog();
    }
  }

  void _showBusinessSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Business Selection Required'),
          content: const Text(
            'You need to select a business before you can add integrations. '
            'Would you like to go to the business selection screen?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pushNamed(context, '/business-selection');
              },
              child: const Text('Select Business'),
            ),
          ],
        );
      },
    );
  }

  void _initializeControllers(String platformId) {
    final platform =
        _getAllPlatforms().firstWhere((p) => p['id'] == platformId);
    for (final field in platform['fields']) {
      _controllers[field] = TextEditingController();
    }
  }

  List<Map<String, dynamic>> _getAllPlatforms() {
    List<Map<String, dynamic>> allPlatforms = [];
    for (var category in _platformsByCategory.values) {
      allPlatforms.addAll(category);
    }
    return allPlatforms;
  }

  List<Map<String, dynamic>> _getCurrentCategoryPlatforms() {
    return _platformsByCategory[_selectedCategory] ?? [];
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'ecommerce':
        return 'E-commerce Platforms';
      case 'marketplace':
        return 'Marketplaces';
      case 'payment':
        return 'Payment Processors';
      case 'social':
        return 'Social Media';
      case 'reviews':
        return 'Reviews & Feedback';
      default:
        return 'Other Platforms';
    }
  }

  IconData _getPlatformIcon(String platformId) {
    switch (platformId) {
      // E-commerce
      case 'shopify':
      case 'woocommerce':
      case 'magento':
        return Icons.store;
      // Marketplace
      case 'amazon':
      case 'ebay':
        return Icons.shopping_cart;
      // Payment
      case 'stripe':
      case 'paypal':
      case 'square':
      case 'razorpay':
      case 'paystack':
      case 'flutterwave':
        return Icons.payment;
      // Social Media
      case 'facebook':
      case 'instagram':
      case 'twitter':
      case 'tiktok':
      case 'whatsapp_business':
      case 'telegram':
        return Icons.share;
      // Reviews & Feedback
      case 'google_business':
      case 'google_reviews':
      case 'trustpilot':
      case 'yelp':
      case 'tripadvisor':
      case 'bazaarvoice':
      case 'yotpo':
      case 'reviews_io':
      case 'shopify_reviews':
      case 'woocommerce_reviews':
        return Icons.star_rate;
      default:
        return Icons.integration_instructions;
    }
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'apiKey':
        return 'API Key';
      case 'apiSecret':
        return 'API Secret';
      case 'storeUrl':
        return 'Store URL';
      case 'consumerKey':
        return 'Consumer Key';
      case 'consumerSecret':
        return 'Consumer Secret';
      case 'accessKey':
        return 'Access Key';
      case 'secretKey':
        return 'Secret Key';
      case 'accessToken':
        return 'Access Token';
      case 'accessTokenSecret':
        return 'Access Token Secret';
      case 'appId':
        return 'App ID';
      case 'appSecret':
        return 'App Secret';
      case 'certId':
        return 'Certificate ID';
      case 'userToken':
        return 'User Token';
      case 'marketplaceId':
        return 'Marketplace ID';
      case 'publishableKey':
        return 'Publishable Key';
      case 'clientId':
        return 'Client ID';
      case 'clientSecret':
        return 'Client Secret';
      case 'applicationId':
        return 'Application ID';
      case 'keyId':
        return 'Key ID';
      case 'keySecret':
        return 'Key Secret';
      case 'publicKey':
        return 'Public Key';
      case 'phoneNumberId':
        return 'Phone Number ID';
      case 'botToken':
        return 'Bot Token';
      case 'chatId':
        return 'Chat ID';
      case 'placeId':
        return 'Place ID';
      case 'businessId':
        return 'Business ID';
      case 'serviceAccountKey':
        return 'Service Account Key';
      case 'businessUnitId':
        return 'Business Unit ID';
      case 'locationId':
        return 'Location ID';
      case 'appKey':
        return 'App Key';
      case 'secret':
        return 'Secret Key';
      case 'shopDomain':
        return 'Shop Domain';
      default:
        return field
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .trim();
    }
  }

  String? _getFieldHint(String field) {
    switch (field) {
      case 'storeUrl':
        return 'https://yourstore.myshopify.com';
      case 'marketplaceId':
        return 'e.g., ATVPDKIKX0DER';
      case 'phoneNumberId':
        return 'WhatsApp Business Phone Number ID';
      case 'chatId':
        return 'Telegram Chat or Channel ID';
      case 'botToken':
        return 'Telegram Bot Token';
      case 'placeId':
        return 'Google Place ID (e.g., ChIJ...)';
      case 'businessId':
        return 'Your business identifier';
      case 'locationId':
        return 'TripAdvisor location identifier';
      case 'shopDomain':
        return 'yourstore.myshopify.com';
      default:
        return null;
    }
  }

  String? _getFieldHelper(String field, String platformId) {
    switch (platformId) {
      case 'stripe':
        if (field == 'publishableKey') return 'Start with pk_';
        if (field == 'secretKey') return 'Start with sk_';
        break;
      case 'paypal':
        return 'Get from PayPal Developer Dashboard';
      case 'facebook':
      case 'instagram':
        return 'Get from Meta for Developers';
      case 'twitter':
        return 'Get from Twitter Developer Portal';
      case 'whatsapp_business':
        return 'Get from Meta Business Manager';
      case 'telegram':
        if (field == 'botToken') return 'Get from @BotFather';
        break;
      case 'google_business':
      case 'google_reviews':
        return 'Get from Google Cloud Console';
      case 'trustpilot':
        return 'Get from Trustpilot Business Account';
      case 'yelp':
        return 'Get from Yelp Fusion API';
      case 'tripadvisor':
        return 'Get from TripAdvisor Content API';
      case 'bazaarvoice':
        return 'Get from Bazaarvoice Developer Portal';
      case 'yotpo':
        return 'Get from Yotpo App Settings';
      case 'reviews_io':
        return 'Get from Reviews.io Dashboard';
    }
    return null;
  }

  bool _isSecureField(String field) {
    return field.toLowerCase().contains('secret') ||
        field.toLowerCase().contains('key') ||
        field.toLowerCase().contains('token') ||
        field == 'certId' ||
        field == 'serviceAccountKey';
  }

  TextInputType _getKeyboardType(String field) {
    if (field.toLowerCase().contains('url')) {
      return TextInputType.url;
    }
    if (field.toLowerCase().contains('email')) {
      return TextInputType.emailAddress;
    }
    return TextInputType.text;
  }

  String? _validateField(String field, String value) {
    if (field.toLowerCase().contains('url')) {
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) {
        return 'Please enter a valid URL';
      }
    }
    if (field.toLowerCase().contains('email')) {
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
        return 'Please enter a valid email';
      }
    }
    return null;
  }

  Future<void> _connectPlatform() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }
      final credentials = {
        for (var entry in _controllers.entries) entry.key: entry.value.text,
      };

      await integrationService.connectPlatform(
        platformId: _selectedPlatform!,
        credentials: credentials,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Platform connected successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } on IntegrationException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to connect platform');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect platform'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(selectedBusinessIdProvider);

    // If no business is selected, show a simple loading scaffold
    // The dialog will handle the business selection prompt
    if (businessId == null) {
      return Scaffold(
        appBar: IntegrationAppBar(
          title: 'Add Integration',
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Add Integration',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Your Platforms',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Integrate your business with popular platforms to manage everything in one place',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? error.ErrorView(
                        message: _error!,
                        onRetry: () {
                          setState(() => _error = null);
                        },
                      )
                    : Column(
                        children: [
                          // Search Bar
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search integrations...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),

                          // Category Accordions
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  // Build accordion for each category
                                  ..._platformsByCategory.keys.map((category) {
                                    final platforms =
                                        _getCategoryPlatforms(category);
                                    if (platforms.isEmpty &&
                                        _searchQuery.isNotEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return _buildCategoryAccordion(
                                        category, platforms);
                                  }).toList(),

                                  const SizedBox(height: 24),

                                  // Help Section
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.blue.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: Colors.blue.shade700,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Need Help?',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Each platform requires specific credentials. Click on any platform to see the required information and setup instructions.',
                                          style: TextStyle(
                                            color: Colors.blue.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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

  // Get all platforms from all categories
  List<Map<String, dynamic>> get _allPlatforms {
    return _platformsByCategory.values
        .expand((platforms) => platforms)
        .toList();
  }

  // Get filtered platforms based on search query
  List<Map<String, dynamic>> _getFilteredPlatforms(
      List<Map<String, dynamic>> platforms) {
    if (_searchQuery.isEmpty) return platforms;

    return platforms.where((platform) {
      final name = platform['name'].toString().toLowerCase();
      final description = platform['description'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || description.contains(query);
    }).toList();
  }

  // Get platforms for a specific category with search filter
  List<Map<String, dynamic>> _getCategoryPlatforms(String category) {
    final platforms = _platformsByCategory[category] ?? [];
    return _getFilteredPlatforms(platforms);
  }

  Widget _buildCategoryAccordion(
      String category, List<Map<String, dynamic>> platforms) {
    final isExpanded = _expandedCategories[category] ?? false;
    final categoryName = _getCategoryDisplayName(category);
    final categoryIcon = _getCategoryIcon(category);
    final categoryColor = _getCategoryColor(category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Category Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedCategories[category] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: isExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: categoryColor.withOpacity(0.2),
                    ),
                    child: Icon(
                      categoryIcon,
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${platforms.length} platform${platforms.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: categoryColor,
                  ),
                ],
              ),
            ),
          ),

          // Platform Grid (when expanded)
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75, // Adjusted for better text visibility
                ),
                itemCount: platforms.length,
                itemBuilder: (context, index) {
                  return _buildIntegrationCard(platforms[index]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'social':
        return Icons.share;
      case 'ecommerce':
        return Icons.store;
      case 'marketplace':
        return Icons.shopping_cart;
      case 'payment':
        return Icons.payment;
      case 'reviews':
        return Icons.star_rate;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'social':
        return const Color(0xFF1877F2); // Facebook blue
      case 'ecommerce':
        return const Color(0xFF96BF47); // Shopify green
      case 'marketplace':
        return const Color(0xFFFF9900); // Amazon orange
      case 'payment':
        return const Color(0xFF635BFF); // Stripe purple
      case 'reviews':
        return const Color(0xFF4285F4); // Google blue
      default:
        return const Color(0xFF6366F1);
    }
  }

  Widget _buildIntegrationCard(Map<String, dynamic> platform) {
    final String platformId = platform['id'];
    final String platformName = platform['name'];
    final String description = platform['description'];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _navigateToIntegrationScreen(platformId, platformName),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Platform Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getPlatformColor(platformId).withOpacity(0.1),
                  border: Border.all(
                    color: _getPlatformColor(platformId).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getPlatformIcon(platformId),
                  size: 24,
                  color: _getPlatformColor(platformId),
                ),
              ),
              const SizedBox(height: 8),
              // Platform Name
              Text(
                platformName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Platform Description
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              // Status indicator or small icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPlatformColor(platformId).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Connect',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getPlatformColor(platformId),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToIntegrationScreen(String platformId, String platformName) {
    // Navigate to specific integration screens
    switch (platformId) {
      case 'instagram':
        Navigator.pushNamed(context, '/meta-integration');
        break;
      case 'facebook':
        Navigator.pushNamed(context, '/meta-integration');
        break;
      case 'tiktok':
        Navigator.pushNamed(context, '/tiktok-integration');
        break;
      case 'whatsapp_business':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WhatsAppIntegrationScreen(),
          ),
        );
        break;
      case 'shopify':
      case 'woocommerce':
      case 'magento':
      case 'amazon':
      case 'ebay':
      case 'stripe':
      case 'paypal':
      case 'square':
      default:
        // For now, show coming soon for other platforms
        _showComingSoonDialog(platformName);
        break;
    }
  }

  void _showComingSoonDialog(String platformName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$platformName Integration'),
        content: Text(
          '$platformName integration is coming soon. We\'re working on bringing you the best integration experience.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getPlatformColor(String platformId) {
    switch (platformId) {
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'twitter':
        return const Color(0xFF1DA1F2);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'whatsapp_business':
        return const Color(0xFF25D366);
      case 'telegram':
        return const Color(0xFF0088CC);
      case 'shopify':
        return const Color(0xFF96BF47);
      case 'woocommerce':
        return const Color(0xFF96588A);
      case 'magento':
        return const Color(0xFFEE672F);
      case 'amazon':
        return const Color(0xFFFF9900);
      case 'ebay':
        return const Color(0xFF0064D2);
      case 'stripe':
        return const Color(0xFF635BFF);
      case 'paypal':
        return const Color(0xFF00457C);
      case 'square':
        return const Color(0xFF3E4348);
      case 'razorpay':
        return const Color(0xFF528FF0);
      case 'paystack':
        return const Color(0xFF00C3F7);
      case 'flutterwave':
        return const Color(0xFFFFB000);
      case 'google_business':
      case 'google_reviews':
        return const Color(0xFF4285F4);
      case 'trustpilot':
        return const Color(0xFF00B67A);
      case 'yelp':
        return const Color(0xFFD32323);
      case 'tripadvisor':
        return const Color(0xFF00AF87);
      default:
        return const Color(0xFF6366F1);
    }
  }
}
