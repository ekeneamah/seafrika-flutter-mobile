import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class AddIntegrationScreen extends ConsumerStatefulWidget {
  const AddIntegrationScreen({super.key});

  @override
  ConsumerState<AddIntegrationScreen> createState() => _AddIntegrationScreenState();
}

class _AddIntegrationScreenState extends ConsumerState<AddIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  String? _selectedPlatform;
  String _selectedCategory = 'ecommerce';
  final Map<String, TextEditingController> _controllers = {};

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
        'fields': ['consumerKey', 'consumerSecret', 'accessToken', 'accessTokenSecret'],
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
    super.dispose();
  }

  void _initializeControllers(String platformId) {
    final platform = _getAllPlatforms().firstWhere((p) => p['id'] == platformId);
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
        return field.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        ).trim();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Integration'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                  },
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Platform Category',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _platformsByCategory.keys.map((category) {
                                    final isSelected = category == _selectedCategory;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(_getCategoryDisplayName(category)),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _selectedCategory = category;
                                              _selectedPlatform = null; // Reset platform selection
                                              _controllers.clear(); // Clear form controllers
                                            });
                                          }
                                        },
                                        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                        checkmarkColor: Theme.of(context).primaryColor,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _getCategoryDisplayName(_selectedCategory),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedPlatform,
                                decoration: const InputDecoration(
                                  labelText: 'Select Platform',
                                  border: OutlineInputBorder(),
                                ),
                                items: _getCurrentCategoryPlatforms().map((platform) {
                                  return DropdownMenuItem<String>(
                                    value: platform['id'] as String,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey.shade200,
                                          ),
                                          child: Icon(
                                            _getPlatformIcon(platform['id']),
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                platform['name'],
                                                style: const TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                platform['description'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPlatform = value;
                                    if (value != null) {
                                      _initializeControllers(value);
                                    }
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a platform';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedPlatform != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Platform Credentials',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                ..._getAllPlatforms()
                                    .firstWhere((p) =>
                                        p['id'] == _selectedPlatform)['fields']
                                    .map<Widget>((field) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: TextFormField(
                                      controller: _controllers[field],
                                      decoration: InputDecoration(
                                        labelText: _getFieldDisplayName(field),
                                        hintText: _getFieldHint(field),
                                        border: const OutlineInputBorder(),
                                        helperText: _getFieldHelper(field, _selectedPlatform!),
                                        helperMaxLines: 2,
                                      ),
                                      obscureText: _isSecureField(field),
                                      keyboardType: _getKeyboardType(field),
                                      validator: (value) {
                                        if (value?.isEmpty ?? true) {
                                          return 'This field is required';
                                        }
                                        return _validateField(field, value!);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _connectPlatform,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                          child: const Text('Connect Platform'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
