import { Module } from '@nestjs/common';
import { MetaController } from './meta/meta.controller';
import { MetaService } from './meta/meta.service';
import { InstagramMetricsService } from './meta/instagram-metrics.service';
import { TikTokController } from './tiktok/tiktok.controller';
import { TikTokService } from './tiktok/tiktok.service';
import { TikTokConfigController } from './tiktok/tiktok-config.controller';
import { WebhookManagementController } from './webhook-management.controller';
import { WhatsAppWebhookController } from './whatsapp/whatsapp-webhook.controller';
import { WhatsAppWebhookService } from './whatsapp/whatsapp-webhook.service';
import { FirestoreModule } from '../firestore/firestore.module';
import { CacheModule } from '@nestjs/cache-manager';


/**
 * Webhooks Module
 * 
 * Comprehensive webhook integrations module supporting multiple social media platforms:
 * - Meta (Facebook, Instagram, Messenger) - Unified service
 * - TikTok Business - Complete OAuth and webhook integration
 * - WhatsApp Business - Separate service for messaging
 * - Webhook Management - General webhook utilities
 */

@Module({
  imports: [FirestoreModule,CacheModule.register({ ttl: 600 /* 10 min */ })],
  controllers: [
    MetaController,                    // Unified Meta integration (Facebook, Instagram, Messenger)
    TikTokController,                  // TikTok Business integration
    TikTokConfigController,            // TikTok OAuth configuration and management
    WebhookManagementController,       // General webhook management
    WhatsAppWebhookController,         // WhatsApp Business webhooks
  ],
  providers: [
    MetaService,                       // Unified Meta service
    InstagramMetricsService,           // Instagram metrics sync service
    TikTokService,                     // TikTok Business service
    WhatsAppWebhookService,           // WhatsApp Business service
  ],
  exports: [
    MetaService,                      // Export for use in other modules
    InstagramMetricsService,          // Export Instagram metrics service
    TikTokService,                    // Export TikTok service
    WhatsAppWebhookService,           // Export WhatsApp service
  ],
})
export class WebhooksModule {}
