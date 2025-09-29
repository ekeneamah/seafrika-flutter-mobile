import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendor_app/services/analytics_service.dart';

class ShareService {
  final AnalyticsService _analytics;

  ShareService({required AnalyticsService analytics}) : _analytics = analytics;

  Future<void> shareProduct({
    required String productId,
    required String productName,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final text = 'Check out $productName on our app!\n\n$description';
      await Share.share(
        text,
        subject: productName,
      );

      await _analytics.logEvent(
        name: 'product_share',
        parameters: {
          'product_id': productId,
          'product_name': productName,
          'platform': 'general',
        },
      );
    } catch (e) {
      debugPrint('Share product error: $e');
    }
  }

  Future<void> shareOnFacebook({
    required String productId,
    required String productName,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final text = Uri.encodeComponent(
          'Check out $productName on our app!\n\n$description');
      final url = 'https://www.facebook.com/sharer/sharer.php?u=$text';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        await _analytics.logEvent(
          name: 'product_share',
          parameters: {
            'product_id': productId,
            'product_name': productName,
            'platform': 'facebook',
          },
        );
      }
    } catch (e) {
      debugPrint('Share on Facebook error: $e');
    }
  }

  Future<void> shareOnTwitter({
    required String productId,
    required String productName,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final text = Uri.encodeComponent(
          'Check out $productName on our app!\n\n$description');
      final url = 'https://twitter.com/intent/tweet?text=$text';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        await _analytics.logEvent(
          name: 'product_share',
          parameters: {
            'product_id': productId,
            'product_name': productName,
            'platform': 'twitter',
          },
        );
      }
    } catch (e) {
      debugPrint('Share on Twitter error: $e');
    }
  }

  Future<void> shareOnWhatsApp({
    required String productId,
    required String productName,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final text = Uri.encodeComponent(
          'Check out $productName on our app!\n\n$description');
      final url = 'whatsapp://send?text=$text';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        await _analytics.logEvent(
          name: 'product_share',
          parameters: {
            'product_id': productId,
            'product_name': productName,
            'platform': 'whatsapp',
          },
        );
      }
    } catch (e) {
      debugPrint('Share on WhatsApp error: $e');
    }
  }

  Future<void> shareOnEmail({
    required String productId,
    required String productName,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final subject = Uri.encodeComponent('Check out $productName');
      final body = Uri.encodeComponent(
          'Check out $productName on our app!\n\n$description');
      final url = 'mailto:?subject=$subject&body=$body';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        await _analytics.logEvent(
          name: 'product_share',
          parameters: {
            'product_id': productId,
            'product_name': productName,
            'platform': 'email',
          },
        );
      }
    } catch (e) {
      debugPrint('Share on Email error: $e');
    }
  }

  Future<void> shareOnTelegram({
    required String productId,
    required String productName,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final text = Uri.encodeComponent(
          'Check out $productName on our app!\n\n$description');
      final url = 'https://t.me/share/url?url=$text';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        await _analytics.logEvent(
          name: 'product_share',
          parameters: {
            'product_id': productId,
            'product_name': productName,
            'platform': 'telegram',
          },
        );
      }
    } catch (e) {
      debugPrint('Share on Telegram error: $e');
    }
  }
}
