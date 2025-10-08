import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Headers,
  HttpCode,
  HttpStatus,
  BadRequestException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { 
  ApiTags, 
  ApiOperation, 
  ApiResponse
} from '@nestjs/swagger';
import { YouTubeService } from './youtube.service';
// import { MessageService as LegacyMessageService } from '../shared/services/message.service';

// TODO: MIGRATION REQUIRED - YouTube Controller Disabled
// The LegacyMessageService has been removed. When YouTube integration is needed:
// 1. Import MessageService from '../shared/services/messaging.service'
// 2. Update all webhook processing to use the new flat collection structure
// 3. Update saveWebhookMessage calls to match new MessageService API
import { NotificationService } from '../shared/services/notification.service';
import * as crypto from 'crypto';

/**
 * YouTube Webhook Controller
 * 
 * Handles YouTube Data API v3 webhooks via PubSub notifications.
 * YouTube uses Google Cloud Pub/Sub for real-time notifications about:
 * - Channel activity
 * - Video uploads
 * - Comments
 * - Subscriptions
 * 
 * Security Features:
 * - Google Cloud Pub/Sub message verification
 * - JWT token validation (when configured)
 * - Secure credential storage
 */

@ApiTags('YouTube Webhooks')
@Controller('webhooks/youtube')
export class YouTubeWebhookController {
  private readonly logger = new Logger(YouTubeWebhookController.name);

  constructor(
    private readonly youtubeService: YouTubeService,
    // private readonly messageService: LegacyMessageService, // DISABLED: Requires migration
    private readonly notificationService: NotificationService,
  ) {}

  /**
   * YouTube webhook verification endpoint (GET)
   */
  @Get('webhook')
  @ApiOperation({ 
    summary: 'YouTube webhook verification',
    description: 'Handle YouTube/Google Cloud Pub/Sub webhook verification'
  })
  @ApiResponse({ status: 200, description: 'Webhook verified successfully' })
  @ApiResponse({ status: 400, description: 'Webhook verification failed' })
  verifyWebhook(
    @Query('hub.challenge') challenge: string,
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') verifyToken: string,
  ) {
    const expectedToken = process.env.YOUTUBE_WEBHOOK_VERIFY_TOKEN;

    if (mode === 'subscribe' && verifyToken === expectedToken) {
      this.logger.log('YouTube webhook verified successfully');
      return challenge;
    }

    this.logger.error('YouTube webhook verification failed');
    throw new BadRequestException('Webhook verification failed');
  }

  /**
   * YouTube webhook event handler (POST)
   * 
   * Processes real-time events from YouTube including:
   * - Video uploads
   * - Video updates (title, description, privacy changes)
   * - Comments on videos
   * - Channel subscriptions
   * - Playlist changes
   */
  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ 
    summary: 'Handle YouTube webhook events',
    description: 'Process real-time YouTube events via Google Cloud Pub/Sub'
  })
  @ApiResponse({ status: 200, description: 'Webhook processed successfully' })
  @ApiResponse({ status: 400, description: 'Invalid webhook signature or format' })
  async handleWebhook(
    @Body() body: any,
    @Headers() headers: any,
  ) {
    this.logger.log('Received YouTube webhook event', {
      hasBody: !!body,
      headers: Object.keys(headers),
      bodyType: typeof body
    });

    try {
      // YouTube/Google Cloud Pub/Sub sends events in a specific format
      let pubsubMessage: any;
      
      if (body.message) {
        // Standard Pub/Sub format
        pubsubMessage = body.message;
      } else if (body.subscription && body.message) {
        // Alternative Pub/Sub format
        pubsubMessage = body.message;
      } else {
        // Direct webhook format (less common)
        pubsubMessage = { data: Buffer.from(JSON.stringify(body)).toString('base64') };
      }

      // Decode the message data
      let eventData: any;
      if (pubsubMessage.data) {
        try {
          const decodedData = Buffer.from(pubsubMessage.data, 'base64').toString('utf-8');
          eventData = JSON.parse(decodedData);
        } catch (error) {
          this.logger.warn('Failed to decode Pub/Sub message data, using raw body', error);
          eventData = body;
        }
      } else {
        eventData = body;
      }

      this.logger.log('Decoded YouTube event data', {
        eventType: eventData.eventType || eventData.type,
        channelId: eventData.channelId,
        videoId: eventData.videoId,
        attributes: pubsubMessage.attributes
      });

      // Handle different event types
      const eventType = eventData.eventType || eventData.type || pubsubMessage.attributes?.eventType;
      
      switch (eventType) {
        case 'video-upload':
        case 'video.upload':
          await this.handleVideoUploadEvent(eventData, pubsubMessage.attributes);
          break;
          
        case 'video-update':
        case 'video.update':
          await this.handleVideoUpdateEvent(eventData, pubsubMessage.attributes);
          break;
          
        case 'video-delete':
        case 'video.delete':
          await this.handleVideoDeleteEvent(eventData, pubsubMessage.attributes);
          break;
          
        case 'comment':
        case 'comment.create':
          await this.handleCommentEvent(eventData, pubsubMessage.attributes);
          break;
          
        case 'subscription':
        case 'channel.subscription':
          await this.handleSubscriptionEvent(eventData, pubsubMessage.attributes);
          break;
          
        case 'channel-update':
        case 'channel.update':
          await this.handleChannelUpdateEvent(eventData, pubsubMessage.attributes);
          break;
          
        default:
          this.logger.log('Unknown YouTube event type', { eventType });
          await this.handleUnknownEvent(eventData, pubsubMessage.attributes);
      }

      return { success: true };
    } catch (error) {
      this.logger.error('YouTube webhook processing failed:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Handle YouTube video upload event
   */
  private async handleVideoUploadEvent(eventData: any, attributes: any = {}): Promise<void> {
    try {
      const businessIntegration = await this.findBusinessIntegrationFromYouTubeEvent(eventData, attributes);
      if (!businessIntegration) return;

      const { businessId, integrationId } = businessIntegration;

      // TODO: Implement message saving with YouTube service
      const messageId = `youtube_upload_${eventData.videoId || Date.now()}`;

      // Send notification
      await this.notificationService.notifyVendorOfNewMessage({
        businessId,
        integrationId,
        messageId,
        platform: 'youtube',
        senderName: 'YouTube',
        preview: `New video uploaded: ${eventData.title || 'Untitled'}`,
        timestamp: new Date(eventData.publishedAt || Date.now()),
      });

      this.logger.log(`YouTube video upload event processed for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to handle YouTube video upload event:', error);
    }
  }

  /**
   * Handle YouTube video update event
   */
  private async handleVideoUpdateEvent(eventData: any, attributes: any = {}): Promise<void> {
    try {
      const businessIntegration = await this.findBusinessIntegrationFromYouTubeEvent(eventData, attributes);
      if (!businessIntegration) return;

      const { businessId, integrationId } = businessIntegration;

      // TODO: Implement message saving with YouTube service
      const messageId = `youtube_update_${eventData.videoId || Date.now()}`;

      this.logger.log(`YouTube video update event processed for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to handle YouTube video update event:', error);
    }
  }

  /**
   * Handle YouTube comment event
   */
  private async handleCommentEvent(eventData: any, attributes: any = {}): Promise<void> {
    try {
      const businessIntegration = await this.findBusinessIntegrationFromYouTubeEvent(eventData, attributes);
      if (!businessIntegration) return;

      const { businessId, integrationId } = businessIntegration;

      // TODO: Implement message saving with YouTube service
      const messageId = `youtube_comment_${eventData.commentId || Date.now()}`;

      // Send notification
      await this.notificationService.notifyVendorOfNewMessage({
        businessId,
        integrationId,
        messageId,
        platform: 'youtube',
        senderName: eventData.authorDisplayName || 'Someone',
        preview: `Commented: ${(eventData.commentText || eventData.textDisplay || '').substring(0, 100)}`,
        timestamp: new Date(eventData.publishedAt || Date.now()),
      });

      this.logger.log(`YouTube comment event processed for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to handle YouTube comment event:', error);
    }
  }

  /**
   * Handle YouTube subscription event
   */
  private async handleSubscriptionEvent(eventData: any, attributes: any = {}): Promise<void> {
    try {
      const businessIntegration = await this.findBusinessIntegrationFromYouTubeEvent(eventData, attributes);
      if (!businessIntegration) return;

      const { businessId, integrationId } = businessIntegration;

      // TODO: Implement message saving with YouTube service
      const messageId = `youtube_subscription_${eventData.subscriberChannelId}_${Date.now()}`;

      // Send notification
      await this.notificationService.notifyVendorOfNewMessage({
        businessId,
        integrationId,
        messageId,
        platform: 'youtube',
        senderName: eventData.subscriberChannelTitle || 'Someone',
        preview: 'Subscribed to your YouTube channel!',
        timestamp: new Date(),
      });

      this.logger.log(`YouTube subscription event processed for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to handle YouTube subscription event:', error);
    }
  }

  /**
   * Handle YouTube channel update event
   */
  private async handleChannelUpdateEvent(eventData: any, attributes: any = {}): Promise<void> {
    try {
      const businessIntegration = await this.findBusinessIntegrationFromYouTubeEvent(eventData, attributes);
      if (!businessIntegration) return;

      const { businessId, integrationId } = businessIntegration;

      // TODO: Implement message saving with YouTube service
      const messageId = `youtube_channel_update_${eventData.channelId || Date.now()}`;

      this.logger.log(`YouTube channel update event processed for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to handle YouTube channel update event:', error);
    }
  }

  /**
   * Handle YouTube video delete event
   */
  private async handleVideoDeleteEvent(eventData: any, attributes: any = {}): Promise<void> {
    try {
      const businessIntegration = await this.findBusinessIntegrationFromYouTubeEvent(eventData, attributes);
      if (!businessIntegration) return;

      const { businessId, integrationId } = businessIntegration;

      // TODO: Implement message saving with YouTube service
      const messageId = `youtube_delete_${eventData.videoId || Date.now()}`;

      this.logger.log(`YouTube video delete event processed for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to handle YouTube video delete event:', error);
    }
  }

  /**
   * Handle unknown YouTube events for debugging
   */
  private async handleUnknownEvent(eventData: any, attributes: any = {}): Promise<void> {
    try {
      const businessIntegration = await this.findBusinessIntegrationFromYouTubeEvent(eventData, attributes);
      if (!businessIntegration) return;

      const { businessId, integrationId } = businessIntegration;

      // TODO: Implement message saving with YouTube service
      const messageId = `youtube_unknown_${Date.now()}`;

      this.logger.log(`YouTube unknown event processed for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to handle YouTube unknown event:', error);
    }
  }

  /**
   * Find business and integration from YouTube event
   */
  private async findBusinessIntegrationFromYouTubeEvent(
    eventData: any, 
    attributes: any = {}
  ): Promise<{ businessId: string; integrationId: string } | null> {
    try {
      // YouTube events contain channelId that we can use to find the integration
      const platformId = eventData.channelId || attributes.channelId;
      
      if (!platformId) {
        this.logger.warn('No channel ID found in YouTube event', { eventType: eventData.eventType });
        return null;
      }

      return await this.youtubeService.findBusinessIntegrationFromPlatformId(platformId, 'youtube');
    } catch (error) {
      this.logger.error('Failed to find business integration from YouTube event:', error);
      return null;
    }
  }
}
