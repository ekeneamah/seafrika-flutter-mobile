import { 
  Controller, 
  Get, 
  Post, 
  Query, 
  Body, 
  Headers, 
  BadRequestException,
  Logger,
  HttpCode,
  HttpStatus,
  Param,
} from '@nestjs/common';
import { MetaService } from './meta.service';
import { InstagramMetricsService } from './instagram-metrics.service';
import { FirestoreService } from '../../firestore/firestore.service';
import { MessageService } from '../shared/services/message.service';
import { NotificationService } from '../shared/services/notification.service';

/**
 * Meta Integration Controller
 * 
 * Unified controller for Facebook Pages, Messenger, and Instagram Business integrations.
 * 
 * Endpoints:
 * - GET /api/config/meta/auth-url - Generate OAuth URL for multiple channels
 * - GET /api/config/meta/oauth/redirect - Handle OAuth callback
 * - POST /webhooks/meta/webhook - Handle all Meta platform webhooks
 * - GET /webhooks/meta/webhook - Webhook verification
 */

@Controller()
export class MetaController {
  private readonly logger = new Logger(MetaController.name);

  constructor(
    private readonly metaService: MetaService,
    private readonly instagramMetricsService: InstagramMetricsService,
    private readonly firestoreService: FirestoreService,
    private readonly messageService: MessageService,
    private readonly notificationService: NotificationService,
  ) {}

  /**
   * Health check endpoint for Meta controller
   */
  @Get('config/meta/health')
  healthCheck() {
    return {
      status: 'ok',
      service: 'Meta Controller',
      timestamp: new Date().toISOString(),
      endpoints: [
        'GET /api/config/meta/auth-url',
        'GET /api/config/meta/oauth/redirect',
        'POST /api/webhooks/meta/webhook',
        'GET /api/webhooks/meta/webhook'
      ]
    };
  }

  /**
   * Debug endpoint to check integration lookup
   */
  @Get('config/meta/debug-integration/:platformId')
  async debugIntegration(@Param('platformId') platformId: string) {
    this.logger.log(`🔍 Debug integration lookup for platformId: ${platformId}`);
    
    try {
      // Test integration lookup using MessagingService
      const result = await this.messageService.findBusinessIntegrationFromPlatformId(
        platformId, 
        'messenger'
      );

      if (result) {
        return {
          success: true,
          platformId,
          businessId: result.businessId,
          integrationId: result.integrationId,
          timestamp: new Date().toISOString()
        };
      } else {
        return {
          success: false,
          platformId,
          message: 'No integration found',
          timestamp: new Date().toISOString()
        };
      }
    } catch (error) {
      this.logger.error(`Error in debug integration lookup: ${error.message}`);
      return {
        success: false,
        platformId,
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  /**
   * Generate OAuth URL for multiple Meta channels
   * 
   * Query Parameters:
   * - channels: Comma-separated list of channels (facebook_pages,messenger,instagram)
   * - redirect_uri: OAuth redirect URI
   * - state: Optional state parameter
   * 
   * Headers:
   * - Business-ID: Business context for integration
   */
  @Get('config/meta/auth-url')
  generateAuthUrl(
    @Query('channels') channelsParam: string,
    @Query('redirect_uri') redirectUri: string,
    @Query('state') state?: string,
    @Headers('Business-ID') businessId?: string,
  ) {
    try {
      this.logger.log(`Meta auth URL request - channels: ${channelsParam}, redirect: ${redirectUri}, business: ${businessId}`);

      // Validate required parameters
      if (!channelsParam || !redirectUri) {
        this.logger.error('Missing required parameters for Meta auth URL generation');
        throw new BadRequestException('Missing required parameters: channels, redirect_uri');
      }

      // Validate Business-ID header
      if (!businessId) {
        this.logger.error('Missing Business-ID header for Meta auth URL generation');
        throw new BadRequestException('Business-ID header is required for Meta integration');
      }

      // Parse channels
      const channels = channelsParam.split(',').map(c => c.trim()).filter(Boolean);
      if (channels.length === 0) {
        this.logger.error('No channels specified for Meta auth URL');
        throw new BadRequestException('At least one channel must be specified');
      }

      this.logger.log(`Generating Meta OAuth URL for channels: ${channels.join(', ')}`);

      // Generate OAuth URL
      const result = this.metaService.generateAuthUrl({
        channels,
        redirectUri,
        state: state || (businessId ? `business_${businessId}_${Date.now()}` : undefined),
      });

      this.logger.log('Meta OAuth URL generated successfully');

      return {
        success: true,
        data: {
          auth_url: result.authUrl,
          redirect_uri: result.redirectUri,
          channels: result.channels,
          scopes: result.scopes,
          app_id: result.appId,
          instructions: result.instructions,
          ...(businessId && { business_id: businessId }),
          ...(state && { state }),
        },
      };
    } catch (error) {
      this.logger.error('Meta auth URL generation failed:', error);
      throw error;
    }
  }

  /**
   * Handle OAuth callback and complete integration setup
   * 
   * Query Parameters:
   * - code: Authorization code from Meta
   * - state: State parameter (should contain business context)
   * - error: Error code if authorization failed
   */
  @Get('config/meta/oauth/redirect')
  async handleOAuthCallback(
    @Query('code') code: string,
    @Query('state') state: string,
    @Query('error') error?: string,
    @Query('error_description') errorDescription?: string,
  ) {
    this.logger.log(`OAuth callback received - state: ${state}, hasCode: ${!!code}, error: ${error}`);

    // Handle OAuth errors
    if (error) {
      this.logger.error(`OAuth authorization failed: ${error} - ${errorDescription}`);
      
      // Redirect to error page
      const redirectUrl = `https://sme-afrika.web.app/integrations?status=error&platform=meta&message=${encodeURIComponent(errorDescription || 'Authorization failed')}&error=${encodeURIComponent(error)}`;
      
      return `
        <!DOCTYPE html>
        <html>
          <head>
            <title>Redirecting...</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script>
              window.location.href = '${redirectUrl}';
            </script>
          </head>
          <body>
            <p>Redirecting...</p>
          </body>
        </html>
      `;
    }

    if (!code || !state) {
      throw new BadRequestException('Missing authorization code or state parameter');
    }

    try {
      // Parse state to extract business context and channels
      this.logger.log(`Parsing state parameter: ${state}`);
      const { businessId, channels } = await this.parseState(state);
      this.logger.log(`Parsed state - businessId: ${businessId}, channels: ${channels.join(', ')}`);
      
      if (!businessId) {
        throw new BadRequestException('Invalid state parameter - business context missing');
      }

      // Build redirect URI for token exchange
      const redirectUri = `${process.env.API_DOMAIN || 'https://localhost:3000'}/api/config/meta/oauth/redirect`;

      // Exchange code for tokens and get integrations
      const { userAccessToken, expiresAt, scopes, userId, integrations } = await this.metaService.exchangeCodeForTokens(
        code,
        redirectUri,
        channels,
      );

      // Store credentials and create integrations
      await this.metaService.storeCredentials(businessId, userAccessToken, expiresAt, scopes, userId, integrations);

      // Subscribe pages to webhooks
      const pages = integrations
        .filter(integration => integration.pageInfo)
        .map(integration => integration.pageInfo);
      await this.subscribeToWebhooks({ pages }, channels);

      this.logger.log(`Successfully completed OAuth for business ${businessId}, created ${integrations.length} integrations`);

      // Determine platforms for success message
      const platforms = integrations.map(integration => {
        if (integration.platformName.toLowerCase().includes('facebook')) return 'facebook';
        if (integration.platformName.toLowerCase().includes('instagram')) return 'instagram';
        if (integration.platformName.toLowerCase().includes('messenger')) return 'messenger';
        return 'meta';
      }).join(',');

      // Redirect to success page
      const redirectUrl = `https://sme-afrika.web.app/integrations?status=success&platform=${platforms}&message=${encodeURIComponent('Meta platforms connected successfully')}&integrations=${integrations.length}`;
      
      return `
        <!DOCTYPE html>
        <html>
          <head>
            <title>Redirecting...</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script>
              window.location.href = '${redirectUrl}';
            </script>
          </head>
          <body>
            <p>Redirecting...</p>
          </body>
        </html>
      `;

    } catch (error) {
      this.logger.error('OAuth callback processing failed:', error);
      
      // Redirect to error page
      const redirectUrl = `https://sme-afrika.web.app/integrations?status=error&platform=meta&message=${encodeURIComponent('Authentication failed')}&error=${encodeURIComponent(error.message)}`;
      
      return `
        <!DOCTYPE html>
        <html>
          <head>
            <title>Redirecting...</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script>
              window.location.href = '${redirectUrl}';
            </script>
          </head>
          <body>
            <p>Redirecting...</p>
          </body>
        </html>
      `;
    }
  }

  /**
   * Parse state parameter to extract business context and channels
   */
  private async parseState(state: string): Promise<{ businessId: string | null; channels: string[] }> {
    try {
      let potentialBusinessId: string | null = null;

      // State format: "BIZ-{businessId}_{timestamp}" where BIZ- is part of the business ID
      if (state.startsWith('BIZ-')) {
        const parts = state.split('_');
        if (parts.length >= 2) {
          potentialBusinessId = parts[0]; // "BIZ-1757246154270715"
        }
      }

      // Try to parse as JSON for more complex state
      if (!potentialBusinessId) {
        try {
          const parsed = JSON.parse(decodeURIComponent(state));
          potentialBusinessId = parsed.businessId || null;
        } catch {
          // Continue to fallback
        }
      }

      // Fallback - extract business ID from BIZ- prefix format
      if (!potentialBusinessId) {
        const bizMatch = state.match(/^(BIZ-[a-zA-Z0-9]+)/i);
        if (bizMatch) {
          potentialBusinessId = bizMatch[1];
        }
      }

      // Validate that the business ID exists in Firestore
      if (potentialBusinessId) {
        const businessExists = await this.validateBusinessExists(potentialBusinessId);
        if (businessExists) {
          this.logger.log(`Validated business ID exists in Firestore: ${potentialBusinessId}`);
          return {
            businessId: potentialBusinessId,
            channels: ['facebook_pages', 'messenger', 'instagram'],
          };
        } else {
          this.logger.warn(`Business ID not found in Firestore: ${potentialBusinessId}`);
        }
      }

      return {
        businessId: null,
        channels: ['facebook_pages', 'messenger', 'instagram'],
      };
    } catch (error) {
      this.logger.error('Error parsing state parameter:', error);
      return {
        businessId: null,
        channels: ['facebook_pages', 'messenger', 'instagram'],
      };
    }
  }

  /**
   * Validate that a business ID exists in the Firestore businesses collection
   */
  private async validateBusinessExists(businessId: string): Promise<boolean> {
    try {
      const businessDoc = await this.firestoreService.getDocument('businesses', businessId);
      this.logger.log(`Business document for ID ${businessId}: ${businessDoc ? 'found' : 'not found'}`);
      return businessDoc !== null;
    } catch (error) {
      this.logger.error(`Error validating business ${businessId}:`, error);
      return false;
    }
  }

  /**
   * Subscribe pages to webhooks for the given channels
   */
  private async subscribeToWebhooks(credentials: any, channels: string[]): Promise<void> {
    if (!credentials.pages || credentials.pages.length === 0) {
      this.logger.warn('No pages available for webhook subscription');
      return;
    }

    const webhookUrl = `${process.env.API_DOMAIN || 'https://localhost:3000'}/webhooks/meta/webhook`;
    this.logger.log(`Subscribing pages to webhooks at ${webhookUrl} for channels: ${channels.join(', ')}`);

    for (const page of credentials.pages) {
      try {
        await this.metaService.subscribePageToWebhooks(
          page.accessToken,
          page.pageId,
          webhookUrl,
          channels,
        );
      } catch (error) {
        this.logger.error(`Failed to subscribe page ${page.pageId} to webhooks:`, error);
        // Continue with other pages even if one fails
      }
    }
  }

  /**
   * Webhook verification endpoint (GET)
   */
  @Get('webhooks/meta/webhook')
  verifyWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.challenge') challenge: string,
    @Query('hub.verify_token') verifyToken: string,
  ) {
    this.logger.log(`🔐 Webhook verification attempt - mode: ${mode}, challenge: ${challenge?.substring(0, 20)}..., verifyToken: ${verifyToken?.substring(0, 10)}...`);
    
    const expectedToken = process.env.META_WEBHOOK_VERIFY_TOKEN;
    
    if (!expectedToken) {
      this.logger.error('❌ META_WEBHOOK_VERIFY_TOKEN not configured in environment');
      throw new BadRequestException('Webhook verification not configured');
    }

    if (mode === 'subscribe' && verifyToken === expectedToken) {
      this.logger.log('✅ Webhook verified successfully, returning challenge');
      return challenge;
    }

    this.logger.error(`❌ Webhook verification failed - mode: ${mode}, token match: ${verifyToken === expectedToken}`);
    throw new BadRequestException('Webhook verification failed');
  }

  /**
   * Webhook event handler (POST)
   */
  @Post('webhooks/meta/webhook')
  @HttpCode(HttpStatus.OK)
  async handleWebhook(
    @Body() body: any,
    @Headers('x-hub-signature-256') signature: string,
  ) {
    const requestStartTime = Date.now();
    this.logger.log(`🔄 Webhook received - Object: ${body.object}, Entries: ${body.entry?.length || 0}`);
    this.logger.debug(`📋 Webhook body: ${JSON.stringify(body, null, 2)}`);
    this.logger.debug(`🔐 Signature header: ${signature?.substring(0, 30)}...`);

    // Verify webhook signature
    const payloadString = JSON.stringify(body);
    const isSignatureValid = this.metaService.verifyWebhookSignature(payloadString, signature);
    
    if (!isSignatureValid) {
      this.logger.error('❌ Invalid webhook signature - rejecting request');
      this.logger.error(`❌ Payload length: ${payloadString.length}, Signature: ${signature}`);
      this.logger.error(`❌ Environment check - META_APP_SECRET configured: ${!!process.env.META_APP_SECRET}`);
      throw new BadRequestException('Invalid signature');
    }
    this.logger.log('✅ Webhook signature verified successfully');

    try {
      // Process webhook events
      if (body.object === 'page') {
        this.logger.log(`📄 Processing Facebook Page webhook with ${body.entry.length} entries`);
        await this.handlePageWebhookEvents(body.entry);
      } else if (body.object === 'instagram') {
        this.logger.log(`📷 Processing Instagram webhook with ${body.entry.length} entries`);
        await this.handleInstagramWebhookEvents(body.entry);
      } else {
        this.logger.warn(`⚠️ Unknown webhook object type: ${body.object} - skipping processing`);
      }

      const processingTime = Date.now() - requestStartTime;
      this.logger.log(`✅ Webhook processed successfully in ${processingTime}ms`);
      return { success: true };
    } catch (error) {
      const processingTime = Date.now() - requestStartTime;
      this.logger.error(`❌ Webhook processing failed after ${processingTime}ms:`, error);
      this.logger.error(`📋 Failed webhook body: ${JSON.stringify(body, null, 2)}`);
      return { success: false, error: error.message };
    }
  }

  /**
   * Handle Facebook Page webhook events (including Messenger)
   */
  private async handlePageWebhookEvents(entries: any[]): Promise<void> {
    this.logger.log(`📄 Processing ${entries.length} page webhook entries`);
    
    for (const [index, entry] of entries.entries()) {
      const pageId = entry.id;
      this.logger.log(`📄 [${index + 1}/${entries.length}] Processing page entry for pageId: ${pageId}`);
      this.logger.debug(`📄 Entry data: ${JSON.stringify(entry, null, 2)}`);
      
      try {
        // Handle different event types
        if (entry.messaging) {
          this.logger.log(`💬 Found ${entry.messaging.length} Messenger events for page ${pageId}`);
          await this.handleMessengerEvents(pageId, entry.messaging);
        }
        
        if (entry.changes) {
          this.logger.log(`🔄 Found ${entry.changes.length} page changes for page ${pageId}`);
          await this.handlePageChanges(pageId, entry.changes);
        }

        if (!entry.messaging && !entry.changes) {
          this.logger.warn(`⚠️ Page entry ${pageId} has no messaging or changes - skipping`);
        }
      } catch (error) {
        this.logger.error(`❌ Failed to process page entry ${pageId}:`, error);
        // Continue processing other entries even if one fails
      }
    }
    
    this.logger.log(`✅ Completed processing ${entries.length} page webhook entries`);
  }

  /**
   * Handle Instagram webhook events
   */
  private async handleInstagramWebhookEvents(entries: any[]): Promise<void> {
    this.logger.log(`📷 Processing ${entries.length} Instagram webhook entries`);
    
    for (const [index, entry] of entries.entries()) {
      const instagramId = entry.id;
      this.logger.log(`📷 [${index + 1}/${entries.length}] Processing Instagram entry for ID: ${instagramId}`);
      this.logger.debug(`📷 Entry data: ${JSON.stringify(entry, null, 2)}`);
      
      try {
        if (entry.messaging) {
          this.logger.log(`💬 Found ${entry.messaging.length} Instagram DM events for account ${instagramId}`);
          await this.handleInstagramMessages(instagramId, entry.messaging);
        }
        
        if (entry.changes) {
          this.logger.log(`🔄 Found ${entry.changes.length} Instagram changes for account ${instagramId}`);
          await this.handleInstagramChanges(instagramId, entry.changes);
        }

        if (!entry.messaging && !entry.changes) {
          this.logger.warn(`⚠️ Instagram entry ${instagramId} has no messaging or changes - skipping`);
        }
      } catch (error) {
        this.logger.error(`❌ Failed to process Instagram entry ${instagramId}:`, error);
        // Continue processing other entries even if one fails
      }
    }
    
    this.logger.log(`✅ Completed processing ${entries.length} Instagram webhook entries`);
  }

  /**
   * Handle Messenger events
   */
  private async handleMessengerEvents(pageId: string, messages: any[]): Promise<void> {
    for (const message of messages) {
      try {
        // Find business and integration from page ID
        const businessIntegration = await this.messageService.findBusinessIntegrationFromPlatformId(
          pageId, 
          'messenger'
        );

        if (!businessIntegration) {
          this.logger.warn(`No business integration found for Messenger page ${pageId}`);
          continue;
        }

        const { businessId, integrationId } = businessIntegration;

        if (message.message) {
          this.logger.log(`Messenger message received for page ${pageId}: ${message.message.text || '[Media]'}`);
          
          // Prepare message data for MessagingService (3-tier flat structure)
          const webhookData = {
            messageId: message.message.mid || `msg_${Date.now()}`,
            businessId,
            integrationId,
            platform: 'messenger',
            messageType: message.message.text ? 'text' : 'media',
            content: {
              text: message.message.text,
              attachments: message.message.attachments?.map(att => ({
                type: att.type,
                url: att.payload?.url,
                payload: att.payload,
              })),
            },
            sender: {
              id: message.sender.id,
              name: message.sender.name,
            },
            recipient: {
              id: message.recipient.id,
              name: 'Business',
            },
            conversation: {
              threadId: `messenger_${message.sender.id}_${pageId}`,
              pageId: pageId,
            },
            metadata: {
              timestamp: message.timestamp,
              source: 'webhook',
              rawPayload: message,
              isRead: false,
              isReplied: false,
            },
          };

          this.logger.log(`💾 Saving Messenger message to MessagingService with messageId: ${webhookData.messageId}`);
          const messageId = await this.messageService.saveWebhookMessage(webhookData);

          // Send notification to vendor
          await this.notificationService.notifyVendorOfNewMessage({
            businessId,
            integrationId,
            messageId,
            platform: 'messenger',
            senderName: message.sender.name || 'Customer',
            preview: message.message.text || '[Media message]',
            timestamp: new Date(message.timestamp),
          });
        }
        
        if (message.postback) {
          this.logger.log(`Messenger postback received for page ${pageId}: ${message.postback.payload}`);
          
          // Prepare postback data for MessagingService
          const postbackData = {
            messageId: `postback_${Date.now()}`,
            businessId,
            integrationId,
            platform: 'messenger',
            messageType: 'postback',
            content: {
              text: message.postback.title,
              attachments: [],
            },
            sender: {
              id: message.sender.id,
              name: message.sender.name,
            },
            recipient: {
              id: message.recipient.id,
              name: 'Business',
            },
            conversation: {
              threadId: `messenger_${message.sender.id}_${pageId}`,
              pageId: pageId,
            },
            metadata: {
              timestamp: message.timestamp,
              source: 'webhook',
              rawPayload: message,
              isRead: false,
              isReplied: false,
            },
          };

          this.logger.log(`💾 Saving Messenger postback to MessagingService`);
          const messageId = await this.messageService.saveWebhookMessage(postbackData);

          // Send notification
          await this.notificationService.notifyVendorOfNewMessage({
            businessId,
            integrationId,
            messageId,
            platform: 'messenger',
            senderName: message.sender.name || 'Customer',
            preview: `Clicked: ${message.postback.title}`,
            timestamp: new Date(message.timestamp),
          });
        }
      } catch (error) {
        this.logger.error(`Failed to process Messenger event for page ${pageId}:`, error);
        // Continue processing other messages
      }
    }
  }

  /**
   * Handle Facebook Page changes
   */
  private async handlePageChanges(pageId: string, changes: any[]): Promise<void> {
    for (const change of changes) {
      try {
        this.logger.log(`Page change received for ${pageId}: ${change.field}`);
        
        // Find business and integration from page ID
        const businessIntegration = await this.messageService.findBusinessIntegrationFromPlatformId(
          pageId, 
          'facebook'
        );

        if (!businessIntegration) {
          this.logger.warn(`No business integration found for Facebook page ${pageId}`);
          continue;
        }

        const { businessId, integrationId } = businessIntegration;
        
        switch (change.field) {
          case 'feed':
            // New post or post update - could implement post tracking here
            this.logger.log(`Feed change for page ${pageId}: ${JSON.stringify(change.value)}`);
            break;
          case 'mention':
            // Page was mentioned - TODO: Implement mention tracking with MessagingService
            this.logger.log(`Mention detected for page ${pageId}: ${JSON.stringify(change.value)}`);
            // TODO: Convert to MessagingService format when mention tracking is needed
            /*
            if (change.value?.item === 'comment' && change.value?.comment_id) {
              // Mention tracking implementation needed
            }
            */
            break;
          default:
            this.logger.log(`Unhandled page change type: ${change.field}`);
        }
      } catch (error) {
        this.logger.error(`Failed to process page change for ${pageId}:`, error);
        // Continue processing other changes
      }
    }
  }

  /**
   * Handle Instagram messages
   */
  private async handleInstagramMessages(instagramId: string, messages: any[]): Promise<void> {
    this.logger.log(`📷💬 Processing ${messages.length} Instagram messages for account ${instagramId}`);
    
    for (const [index, message] of messages.entries()) {
      const messageStartTime = Date.now();
      this.logger.log(`📷💬 [${index + 1}/${messages.length}] Processing Instagram message`);
      this.logger.debug(`📷💬 Message data: ${JSON.stringify(message, null, 2)}`);
      
      try {
        // Find business and integration from Instagram account ID
        this.logger.log(`🔍 Looking up business integration for Instagram ID: ${instagramId}`);
        const businessIntegration = await this.messageService.findBusinessIntegrationFromPlatformId(
          instagramId, 
          'instagram'
        );

        if (!businessIntegration) {
          this.logger.warn(`⚠️ No business integration found for Instagram account ${instagramId} - skipping message`);
          continue;
        }

        const { businessId, integrationId } = businessIntegration;
        this.logger.log(`✅ Found integration: businessId=${businessId}, integrationId=${integrationId}`);

        if (message.message) {
          const messageText = message.message.text || '[Media]';
          this.logger.log(`📷💬 Instagram DM received for ${instagramId}: ${messageText.substring(0, 100)}...`);
          
          // Prepare message data for MessagingService
          const webhookData = {
            messageId: message.message.mid || `ig_msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            businessId,
            integrationId,
            platform: 'instagram',
            messageType: message.message.text ? 'text' : 'image',
            content: {
              text: message.message.text || '',
              attachments: message.message.attachments?.map((att: any) => ({
                type: att.type || 'unknown',
                url: att.payload?.url || '',
                payload: att.payload
              })) || []
            },
            sender: {
              id: message.sender?.id || 'unknown',
              name: message.sender?.name || message.sender?.username || 'Instagram User',
              username: message.sender?.username
            },
            recipient: {
              id: message.recipient?.id || instagramId,
              name: 'Business'
            },
            conversation: {
              threadId: `ig_thread_${instagramId}_${message.sender?.id || 'unknown'}`,
              pageId: instagramId
            },
            metadata: {
              timestamp: message.timestamp || Date.now(),
              source: 'instagram_webhook',
              rawPayload: message,
              isRead: false,
              isReplied: false,
            },
          };

          this.logger.log(`💾 Saving Instagram DM to MessagingService with messageId: ${webhookData.messageId}`);
          this.logger.debug(`💾 Webhook data: ${JSON.stringify(webhookData, null, 2)}`);
          
          // Save message using messaging service
          const messageId = await this.messageService.saveWebhookMessage(webhookData);
          
          const messageProcessTime = Date.now() - messageStartTime;
          this.logger.log(`✅ Instagram DM saved successfully as messageId: ${messageId} in ${messageProcessTime}ms`);

          // Send notification
          this.logger.log(`🔔 Sending notification for Instagram DM`);
          await this.notificationService.notifyVendorOfNewMessage({
            businessId,
            integrationId,
            messageId,
            platform: 'instagram',
            senderName: message.sender?.username || message.sender?.name || 'Instagram User',
            preview: messageText.substring(0, 100),
            timestamp: new Date(message.timestamp || Date.now()),
          });
          this.logger.log(`✅ Notification sent for Instagram DM`);
        } else {
          this.logger.warn(`⚠️ Instagram message has no message content - skipping`);
        }
      } catch (error) {
        const messageProcessTime = Date.now() - messageStartTime;
        this.logger.error(`❌ Failed to process Instagram message after ${messageProcessTime}ms:`, error);
        this.logger.error(`📋 Failed message data: ${JSON.stringify(message, null, 2)}`);
        // Continue processing other messages even if one fails
      }
    }
    
    this.logger.log(`✅ Completed processing ${messages.length} Instagram messages for account ${instagramId}`);
  }

  /**
   * Handle Instagram changes
   */
  private async handleInstagramChanges(instagramId: string, changes: any[]): Promise<void> {
    this.logger.log(`📷🔄 Processing ${changes.length} Instagram changes for account ${instagramId}`);
    
    for (const [index, change] of changes.entries()) {
      const changeStartTime = Date.now();
      this.logger.log(`📷🔄 [${index + 1}/${changes.length}] Processing Instagram change: ${change.field}`);
      this.logger.debug(`📷🔄 Change data: ${JSON.stringify(change, null, 2)}`);
      
      try {
        // Find business and integration from Instagram account ID
        this.logger.log(`🔍 Looking up business integration for Instagram ID: ${instagramId}`);
        const businessIntegration = await this.messageService.findBusinessIntegrationFromPlatformId(
          instagramId, 
          'instagram'
        );

        if (!businessIntegration) {
          this.logger.warn(`⚠️ No business integration found for Instagram account ${instagramId} - skipping change`);
          continue;
        }

        const { businessId, integrationId } = businessIntegration;
        this.logger.log(`✅ Found integration: businessId=${businessId}, integrationId=${integrationId}`);
        
        switch (change.field) {
          case 'comments':
            this.logger.log(`💬 Processing Instagram comment for account ${instagramId}`);
            // New comment on Instagram post
            if (change.value?.text) {
              this.logger.log(`💬 Comment text: ${change.value.text.substring(0, 100)}...`);
              
              const webhookData = {
                messageId: change.value.id || `ig_comment_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                businessId,
                integrationId,
                platform: 'instagram',
                messageType: 'text',
                content: {
                  text: change.value.text,
                  attachments: []
                },
                sender: {
                  id: change.value.from?.id || 'unknown',
                  name: change.value.from?.username || 'Instagram User',
                  username: change.value.from?.username
                },
                recipient: {
                  id: instagramId,
                  name: 'Business'
                },
                conversation: {
                  threadId: `ig_comment_${change.value.media?.id || 'unknown'}_${change.value.from?.id || 'unknown'}`,
                  pageId: instagramId,
                  postId: change.value.media?.id
                },
                metadata: {
                  timestamp: Date.now(),
                  source: 'instagram_webhook_comment',
                  rawPayload: change,
                  isRead: false,
                  isReplied: false,
                },
              };

              this.logger.log(`💾 Saving Instagram comment to MessagingService`);
              const messageId = await this.messageService.saveWebhookMessage(webhookData);
              
              const changeProcessTime = Date.now() - changeStartTime;
              this.logger.log(`✅ Instagram comment saved successfully as messageId: ${messageId} in ${changeProcessTime}ms`);

              // Send notification
              this.logger.log(`🔔 Sending notification for Instagram comment`);
              await this.notificationService.notifyVendorOfNewMessage({
                businessId,
                integrationId,
                messageId,
                platform: 'instagram',
                senderName: change.value.from?.username || 'Someone',
                preview: `Commented: ${change.value.text.substring(0, 100)}`,
                timestamp: new Date(),
              });
              this.logger.log(`✅ Notification sent for Instagram comment`);
            } else {
              this.logger.warn(`⚠️ Instagram comment has no text - skipping`);
            }
            break;
          case 'mentions':
            this.logger.log(`🏷️ Processing Instagram mention for account ${instagramId}`);
            // Account was mentioned in story or post
            if (change.value?.comment_id || change.value?.media_id) {
              this.logger.log(`🏷️ Mention in ${change.value.media_id ? 'media' : 'comment'}`);
              
              const webhookData = {
                messageId: change.value.comment_id || `ig_mention_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                businessId,
                integrationId,
                platform: 'instagram',
                messageType: 'text',
                content: {
                  text: '[Mentioned in Instagram content]',
                  attachments: []
                },
                sender: {
                  id: change.value.from?.id || 'unknown',
                  name: change.value.from?.username || 'Instagram User',
                  username: change.value.from?.username
                },
                recipient: {
                  id: instagramId,
                  name: 'Business'
                },
                conversation: {
                  threadId: `ig_mention_${change.value.media_id || Date.now()}_${change.value.from?.id || 'unknown'}`,
                  pageId: instagramId,
                  postId: change.value.media_id
                },
                metadata: {
                  timestamp: Date.now(),
                  source: 'instagram_webhook_mention',
                  rawPayload: change,
                  isRead: false,
                  isReplied: false,
                },
              };

              this.logger.log(`💾 Saving Instagram mention to MessagingService`);
              const messageId = await this.messageService.saveWebhookMessage(webhookData);
              
              const changeProcessTime = Date.now() - changeStartTime;
              this.logger.log(`✅ Instagram mention saved successfully as messageId: ${messageId} in ${changeProcessTime}ms`);

              // Send notification
              this.logger.log(`🔔 Sending notification for Instagram mention`);
              await this.notificationService.notifyVendorOfNewMessage({
                businessId,
                integrationId,
                messageId,
                platform: 'instagram',
                senderName: change.value.from?.username || 'Someone',
                preview: 'Mentioned you in Instagram content',
                timestamp: new Date(),
              });
              this.logger.log(`✅ Notification sent for Instagram mention`);
            } else {
              this.logger.warn(`⚠️ Instagram mention has no identifiable content - skipping`);
            }
            break;
          default:
            this.logger.log(`⚠️ Unhandled Instagram change type: ${change.field} - skipping`);
        }
      } catch (error) {
        const changeProcessTime = Date.now() - changeStartTime;
        this.logger.error(`❌ Failed to process Instagram change after ${changeProcessTime}ms:`, error);
        this.logger.error(`📋 Failed change data: ${JSON.stringify(change, null, 2)}`);
        // Continue processing other changes even if one fails
      }
    }
    
    this.logger.log(`✅ Completed processing ${changes.length} Instagram changes for account ${instagramId}`);
  }

  /**
   * Manually sync Instagram metrics for a specific integration
   */
  @Post('config/instagram/:integrationId/sync-metrics')
  async syncInstagramMetrics(
    @Param('integrationId') integrationId: string,
    @Headers('Business-ID') businessId: string,
  ) {
    try {
      this.logger.log(`Manual Instagram metrics sync requested for integration: ${integrationId}`);
      
      const updatedMetrics = await this.instagramMetricsService.syncInstagramMetricsById(integrationId);
      
      return {
        success: true,
        message: 'Instagram metrics updated successfully',
        metrics: updatedMetrics,
        updatedAt: new Date().toISOString(),
      };
    } catch (error) {
      this.logger.error(`Failed to sync Instagram metrics for integration ${integrationId}:`, error);
      throw new BadRequestException('Failed to sync Instagram metrics');
    }
  }

  /**
   * Get Instagram metrics history for trend analysis
   */
  @Get('config/instagram/:integrationId/metrics-history')
  async getInstagramMetricsHistory(
    @Param('integrationId') integrationId: string,
    @Query('days') days: string = '30',
    @Headers('Business-ID') businessId: string,
  ) {
    try {
      const daysNum = parseInt(days, 10) || 30;
      const history = await this.instagramMetricsService.getMetricsHistory(integrationId, daysNum);
      
      return {
        success: true,
        history,
        period: `${daysNum} days`,
      };
    } catch (error) {
      this.logger.error(`Failed to get Instagram metrics history for integration ${integrationId}:`, error);
      throw new BadRequestException('Failed to get metrics history');
    }
  }

  /**
   * Trigger bulk sync of all Instagram metrics (admin endpoint)
   */
  @Post('config/instagram/sync-all-metrics')
  async syncAllInstagramMetrics(@Headers('Business-ID') businessId: string) {
    try {
      this.logger.log('Manual bulk Instagram metrics sync requested');
      
      // Run the sync in background
      this.instagramMetricsService.syncAllInstagramMetrics();
      
      return {
        success: true,
        message: 'Bulk Instagram metrics sync started',
        startedAt: new Date().toISOString(),
      };
    } catch (error) {
      this.logger.error('Failed to start bulk Instagram metrics sync:', error);
      throw new BadRequestException('Failed to start bulk sync');
    }
  }

  /**
   * Get messages for a business
   */
  @Get('messages/:businessId')
  async getMessages(
    @Param('businessId') businessId: string,
    @Query('integrationId') integrationId?: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
    @Query('unreadOnly') unreadOnly?: string,
    @Headers('Business-ID') headerBusinessId?: string,
  ) {
    try {
      // Validate business access
      if (headerBusinessId && headerBusinessId !== businessId) {
        throw new BadRequestException('Access denied to this business');
      }

      const options = {
        integrationId,
        limit: limit ? parseInt(limit, 10) : 50,
        cursor,
        unreadOnly: unreadOnly === 'true',
      };

      const result = await this.messageService.getMessages(businessId, options);
      
      return {
        success: true,
        data: result,
      };
    } catch (error) {
      this.logger.error(`Failed to get messages for business ${businessId}:`, error);
      throw new BadRequestException('Failed to get messages');
    }
  }

  /**
   * Mark messages as read
   */
  @Post('messages/:businessId/mark-read')
  async markMessagesAsRead(
    @Param('businessId') businessId: string,
    @Body() body: { messageIds: string[]; readAt?: string },
    @Headers('Business-ID') headerBusinessId?: string,
  ) {
    try {
      // Validate business access
      if (headerBusinessId && headerBusinessId !== businessId) {
        throw new BadRequestException('Access denied to this business');
      }

      // Use messaging service with readAt support
      const requests = body.messageIds.map(messageId => ({
        messageId,
        isRead: true,
        readAt: body.readAt,
      }));

      await this.messageService.markMessagesAsRead(businessId, requests);
      
      return {
        success: true,
        message: `Marked ${body.messageIds.length} messages as read`,
        readAt: body.readAt || new Date().toISOString(),
      };
    } catch (error) {
      this.logger.error(`Failed to mark messages as read for business ${businessId}:`, error);
      throw new BadRequestException('Failed to mark messages as read');
    }
  }

  /**
   * Get unread message count
   */
  @Get('messages/:businessId/unread-count')
  async getUnreadCount(
    @Param('businessId') businessId: string,
    @Query('integrationId') integrationId?: string,
    @Headers('Business-ID') headerBusinessId?: string,
  ) {
    try {
      // Validate business access
      if (headerBusinessId && headerBusinessId !== businessId) {
        throw new BadRequestException('Access denied to this business');
      }

      const count = await this.messageService.getUnreadCount(businessId, integrationId);
      
      return {
        success: true,
        data: { unreadCount: count },
      };
    } catch (error) {
      this.logger.error(`Failed to get unread count for business ${businessId}:`, error);
      throw new BadRequestException('Failed to get unread count');
    }
  }

  /**
   * Update notification preferences
   */
  @Post('notifications/:businessId/preferences')
  async updateNotificationPreferences(
    @Param('businessId') businessId: string,
    @Body() preferences: any,
    @Headers('Business-ID') headerBusinessId?: string,
  ) {
    try {
      // Validate business access
      if (headerBusinessId && headerBusinessId !== businessId) {
        throw new BadRequestException('Access denied to this business');
      }

      await this.notificationService.updateNotificationPreferences(businessId, preferences);
      
      return {
        success: true,
        message: 'Notification preferences updated successfully',
      };
    } catch (error) {
      this.logger.error(`Failed to update notification preferences for business ${businessId}:`, error);
      throw new BadRequestException('Failed to update notification preferences');
    }
  }
}
