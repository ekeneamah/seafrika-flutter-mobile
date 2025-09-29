import 'package:flutter/material.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/services/analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        children: [
          _buildSearchBar(context),
          _buildFAQs(context),
          _buildContactSupport(context),
          _buildResources(context),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for help...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        onChanged: (value) {
          // Implement search functionality
        },
      ),
    );
  }

  Widget _buildFAQs(BuildContext context) {
    final faqs = [
      {
        'question': 'How do I add a new product?',
        'answer':
            'To add a new product, go to the Products tab and tap the + button. Fill in the product details and upload images. Tap Save to add the product to your store.',
      },
      {
        'question': 'How do I manage orders?',
        'answer':
            'You can view and manage all your orders in the Orders tab. Tap on an order to view details and update its status.',
      },
      {
        'question': 'How do I update my profile?',
        'answer':
            'Go to the Profile tab and tap the edit button. Update your information and tap Save to apply changes.',
      },
      {
        'question': 'How do I handle returns?',
        'answer':
            'When a customer requests a return, you\'ll receive a notification. Go to the Orders tab, find the order, and follow the return process.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...faqs.map((faq) => _buildFAQItem(context, faq)),
      ],
    );
  }

  Widget _buildFAQItem(BuildContext context, Map<String, String> faq) {
    return ExpansionTile(
      title: Text(
        faq['question']!,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(faq['answer']!),
        ),
      ],
    );
  }

  Widget _buildContactSupport(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email Support'),
            subtitle: const Text('support@vendorapp.com'),
            onTap: () => _launchEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone Support'),
            subtitle: const Text('+1 (555) 123-4567'),
            onTap: () => _launchPhone(context),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Live Chat'),
            subtitle: const Text('Available 24/7'),
            onTap: () {
              // Implement live chat
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResources(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resources',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('User Guide'),
            onTap: () {
              // Navigate to user guide
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Video Tutorials'),
            onTap: () {
              // Navigate to video tutorials
            },
          ),
          ListTile(
            leading: const Icon(Icons.forum),
            title: const Text('Community Forum'),
            onTap: () {
              // Navigate to forum
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final url = Uri.parse('mailto:support@vendorapp.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email')),
      );
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    final url = Uri.parse('tel:+15551234567');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone')),
      );
    }
  }
}
