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
      return this.renderErrorPage(error, errorDescription);
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

      // Return success page
      return this.renderSuccessPage(integrations);

    } catch (error) {
      this.logger.error('OAuth callback processing failed:', error);
      return this.renderErrorPage('processing_failed', error.message);
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
   * Render success page after successful OAuth
   */
  private renderSuccessPage(integrations: any[]): string {
    const platformNames = integrations.map(i => i.platformName).join(', ');
    
    return `
      <!DOCTYPE html>
      <html>
        <head>
          <title>Integration Successful</title>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
            .container { max-width: 500px; margin: 50px auto; background: white; border-radius: 12px; padding: 40px; text-align: center; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .success-icon { width: 60px; height: 60px; background: #10B981; border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; }
            .check { color: white; font-size: 30px; font-weight: bold; }
            h1 { color: #065F46; margin: 0 0 10px; font-size: 24px; }
            p { color: #6B7280; margin: 0 0 20px; line-height: 1.5; }
            .platforms { background: #F3F4F6; padding: 15px; border-radius: 8px; margin: 20px 0; }
            .close-btn { background: #10B981; color: white; border: none; padding: 12px 24px; border-radius: 6px; cursor: pointer; font-size: 16px; }
            .close-btn:hover { background: #059669; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="success-icon">
              <span class="check">✓</span>
            </div>
            <h1>Integration Successful!</h1>
            <p>Your Meta platforms have been successfully connected to your business account.</p>
            <div class="platforms">
              <strong>Connected Platforms:</strong><br>
              ${platformNames}
            </div>
            <p>You can now close this window and return to your app to start managing your social media presence.</p>
            <button class="close-btn" onclick="window.close()">Close Window</button>
          </div>
          <script>
            // Auto-close after 5 seconds if not manually closed
            setTimeout(() => {
              if (window.opener) {
                window.close();
              }
            }, 5000);
          </script>
        </body>
      </html>
    `;
  }

  /**
   * Render error page for OAuth failures
   */
  private renderErrorPage(error: string, description?: string): string {
    return `
      <!DOCTYPE html>
      <html>
        <head>
          <title>Integration Failed</title>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
            .container { max-width: 500px; margin: 50px auto; background: white; border-radius: 12px; padding: 40px; text-align: center; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .error-icon { width: 60px; height: 60px; background: #EF4444; border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; }
            .x { color: white; font-size: 30px; font-weight: bold; }
            h1 { color: #DC2626; margin: 0 0 10px; font-size: 24px; }
            p { color: #6B7280; margin: 0 0 20px; line-height: 1.5; }
            .error-details { background: #FEF2F2; border: 1px solid #FECACA; padding: 15px; border-radius: 8px; margin: 20px 0; text-align: left; }
            .retry-btn { background: #3B82F6; color: white; border: none; padding: 12px 24px; border-radius: 6px; cursor: pointer; font-size: 16px; margin-right: 10px; }
            .close-btn { background: #6B7280; color: white; border: none; padding: 12px 24px; border-radius: 6px; cursor: pointer; font-size: 16px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="error-icon">
              <span class="x">✕</span>
            </div>
            <h1>Integration Failed</h1>
            <p>There was an issue connecting your Meta platforms. This could be due to:</p>
            <div class="error-details">
              <strong>Error:</strong> ${error}<br>
              ${description ? `<strong>Details:</strong> ${description}` : ''}
            </div>
            <p>
              • Network connectivity issues<br>
              • Permissions not granted<br>
              • Temporary service problems
            </p>
            <button class="retry-btn" onclick="history.back()">Try Again</button>
            <button class="close-btn" onclick="window.close()">Close Window</button>
          </div>
        </body>
      </html>
    `;
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
    const expectedToken = process.env.META_WEBHOOK_VERIFY_TOKEN;

    if (mode === 'subscribe' && verifyToken === expectedToken) {
      this.logger.log('Webhook verified successfully');
      return challenge;
    }

    this.logger.error('Webhook verification failed');
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
    this.logger.log('Received webhook event');

    // Verify webhook signature
    if (!this.metaService.verifyWebhookSignature(JSON.stringify(body), signature)) {
      this.logger.error('Invalid webhook signature');
      throw new BadRequestException('Invalid signature');
    }

    try {
      // Process webhook events
      if (body.object === 'page') {
        await this.handlePageWebhookEvents(body.entry);
      } else if (body.object === 'instagram') {
        await this.handleInstagramWebhookEvents(body.entry);
      } else {
        this.logger.warn(`Unknown webhook object type: ${body.object}`);
      }

      return { success: true };
    } catch (error) {
      this.logger.error('Webhook processing failed:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Handle Facebook Page webhook events (including Messenger)
   */
  private async handlePageWebhookEvents(entries: any[]): Promise<void> {
    for (const entry of entries) {
      const pageId = entry.id;
      
      // Handle different event types
      if (entry.messaging) {
        // Messenger events
        await this.handleMessengerEvents(pageId, entry.messaging);
      }
      
      if (entry.changes) {
        // Page changes (posts, mentions, etc.)
        await this.handlePageChanges(pageId, entry.changes);
      }
    }
  }

  /**
   * Handle Instagram webhook events
   */
  private async handleInstagramWebhookEvents(entries: any[]): Promise<void> {
    for (const entry of entries) {
      const instagramId = entry.id;
      
      if (entry.messaging) {
        // Instagram DM events
        await this.handleInstagramMessages(instagramId, entry.messaging);
      }
      
      if (entry.changes) {
        // Instagram changes (comments, mentions, etc.)
        await this.handleInstagramChanges(instagramId, entry.changes);
      }
    }
  }

  /**
   * Handle Messenger events
   */
  private async handleMessengerEvents(pageId: string, messages: any[]): Promise<void> {
    for (const message of messages) {
      if (message.message) {
        this.logger.log(`Messenger message received for page ${pageId}: ${message.message.text}`);
        // Process message - implement your business logic here
      }
      
      if (message.postback) {
        this.logger.log(`Messenger postback received for page ${pageId}: ${message.postback.payload}`);
        // Process postback - implement your business logic here
      }
    }
  }

  /**
   * Handle Facebook Page changes
   */
  private async handlePageChanges(pageId: string, changes: any[]): Promise<void> {
    for (const change of changes) {
      this.logger.log(`Page change received for ${pageId}: ${change.field}`);
      
      switch (change.field) {
        case 'feed':
          // New post or post update
          break;
        case 'mention':
          // Page was mentioned
          break;
        default:
          this.logger.log(`Unhandled page change type: ${change.field}`);
      }
    }
  }

  /**
   * Handle Instagram messages
   */
  private async handleInstagramMessages(instagramId: string, messages: any[]): Promise<void> {
    for (const message of messages) {
      if (message.message) {
        this.logger.log(`Instagram DM received for ${instagramId}: ${message.message.text}`);
        // Process Instagram DM - implement your business logic here
      }
    }
  }

  /**
   * Handle Instagram changes
   */
  private async handleInstagramChanges(instagramId: string, changes: any[]): Promise<void> {
    for (const change of changes) {
      this.logger.log(`Instagram change received for ${instagramId}: ${change.field}`);
      
      switch (change.field) {
        case 'comments':
          // New comment
          break;
        case 'mentions':
          // Account was mentioned
          break;
        default:
          this.logger.log(`Unhandled Instagram change type: ${change.field}`);
      }
    }
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
}