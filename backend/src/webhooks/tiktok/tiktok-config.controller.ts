import { Controller, Get, Post, Put, Delete, Query, Body, Headers, Res, Req, Param, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiBody } from '@nestjs/swagger';
import { Response, Request } from 'express';
import { ConfigService } from '@nestjs/config';
import { TikTokService } from './tiktok.service';

@ApiTags('TikTok Configuration')
@Controller('config/tiktok')
export class TikTokConfigController {
  private readonly logger = new Logger(TikTokConfigController.name);

  constructor(
    private readonly configService: ConfigService,
    private readonly tikTokService: TikTokService,
  ) {}

  @Get('auth-url')
  @ApiOperation({ summary: 'Generate TikTok authorization URL' })
  @ApiResponse({ status: 200, description: 'Authorization URL generated' })
  @ApiQuery({ name: 'redirect_uri', description: 'OAuth redirect URI' })
  @ApiQuery({ name: 'state', description: 'Optional state parameter', required: false })
  async getTikTokAuthUrl(
    @Query('redirect_uri') redirectUri: string,
    @Query('state') state?: string,
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!redirectUri) {
      throw new HttpException(
        'redirect_uri parameter is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const authUrl = this.tikTokService.generateAuthUrl({
        scopes: ['user.info.basic', 'user.info.profile', 'user.info.stats', 'video.list', 'video.upload'],
        redirectUri,
        state
      });
      
      // Store PKCE code verifier in Firestore for later retrieval during token exchange
      await this.tikTokService.storePKCEVerifier(authUrl.state, authUrl.codeVerifier);
      
      this.logger.log('TikTok auth URL generated with PKCE', {
        businessId,
        redirectUri,
        state: authUrl.state,
        codeChallenge: authUrl.codeChallenge,
      });

      return {
        auth_url: authUrl,
        client_key: this.configService.get('TIKTOK_CLIENT_KEY'),
        redirect_uri: redirectUri,
        state: authUrl.state,
      };
    } catch (error) {
      this.logger.error('Failed to generate TikTok auth URL:', error);
      throw new HttpException(
        'Failed to generate authorization URL',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('mobile-auth-url')
  @ApiOperation({ summary: 'Generate TikTok authorization URL for mobile apps' })
  @ApiResponse({ status: 200, description: 'Mobile authorization URL generated successfully' })
  @ApiQuery({ name: 'state', description: 'Optional state parameter', required: false })
  async getMobileTikTokAuthUrl(
    @Query('state') state?: string,
    @Headers('Business-ID') businessId?: string,
  ) {
    try {
      // Use the same HTTPS redirect URI as web, but we'll detect mobile requests
      const baseUrl = process.env.BASE_URL || 'https://seafrikaapi-u53tcgosiq-uc.a.run.app';
      const mobileRedirectUri = `${baseUrl}/api/config/tiktok/oauth/redirect`;
      
      const authUrl = this.tikTokService.generateAuthUrl({
        scopes: ['user.info.basic', 'user.info.profile', 'user.info.stats', 'video.list', 'video.upload'],
        redirectUri: mobileRedirectUri,
        state: `mobile_${businessId}_${Date.now()}`  // Always use mobile_ prefix for mobile requests
      });
      
      // Store PKCE code verifier in Firestore for later retrieval during token exchange
      await this.tikTokService.storePKCEVerifier(authUrl.state, authUrl.codeVerifier);
      
      this.logger.log('TikTok mobile auth URL generated with PKCE', {
        businessId,
        redirectUri: mobileRedirectUri,
        state: authUrl.state,
        codeChallenge: authUrl.codeChallenge,
      });

      return {
        authUrl: authUrl.authUrl,
        state: authUrl.state,
      };
    } catch (error) {
      this.logger.error('Failed to generate TikTok mobile auth URL:', error);
      throw new HttpException(
        'Failed to generate mobile authorization URL',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('oauth/redirect')
  @ApiOperation({ summary: 'TikTok OAuth redirect handler' })
  @ApiResponse({ status: 200, description: 'OAuth redirect handled successfully' })
  @ApiQuery({ name: 'code', description: 'Authorization code from TikTok', required: false })
  @ApiQuery({ name: 'state', description: 'State parameter', required: false })
  @ApiQuery({ name: 'error', description: 'Error code if authentication failed', required: false })
  @ApiQuery({ name: 'error_description', description: 'Error description', required: false })
  async handleTikTokOAuthRedirect(
    @Req() req: Request,
    @Query('code') code?: string,
    @Query('state') state?: string,
    @Query('error') error?: string,
    @Query('error_description') errorDescription?: string,
    @Res() res?: Response,
  ) {
    this.logger.log('TikTok OAuth callback received', {
      hasCode: !!code,
      state,
      error,
      errorDescription,
      fullQuery: JSON.stringify(req.query),
      userAgent: req.headers['user-agent']
    });

    // Parse business ID and requested channels from state
    let businessId: string | undefined;
    let requestedChannels: string[] = ['tiktok'];
    let isMobileRequest = false;

    if (state) {
      try {
        this.logger.log('Parsing state parameter:', state);
        
        // Check if this is a mobile request (state starts with "mobile_")
        if (state.startsWith('mobile_')) {
          isMobileRequest = true;
          this.logger.log('Mobile request detected from state:', state);
          // State format: "mobile_businessId_timestamp" 
          const parts = state.split('_');
          if (parts.length >= 2) {
            businessId = parts[1];
            this.logger.log('Extracted businessId from mobile state:', businessId);
          }
        } else {
          this.logger.log('Web request detected from state:', state);
          // For legacy states or web requests
          // State format: "businessId:channel1,channel2" or just "businessId"
          const [stateBusinessId, channelsString] = state.split(':');
          businessId = stateBusinessId;
          if (channelsString) {
            requestedChannels = channelsString.split(',');
          }
        }
      } catch (e) {
        this.logger.warn('Failed to parse state parameter:', state);
      }
    }

    this.logger.log('Request detection results:', {
      businessId,
      requestedChannels,
      isMobileRequest,
      originalState: state
    });

    // Handle OAuth error
    if (error) {
      this.logger.error('TikTok OAuth error:', {
        error,
        errorDescription,
        businessId,
        isMobileRequest,
      });

      if (businessId) {
        await this.tikTokService.storeIntegrationError(
          businessId,
          'tiktok',
          `OAuth error: ${error} - ${errorDescription || 'Unknown error'}`
        );
      }

      // Handle OAuth errors with web app redirects
      if (isMobileRequest) {
        const errorMessage = encodeURIComponent(errorDescription || 'TikTok authorization failed');
        const redirectUrl = `https://sme-afrika.web.app/integrations?error=${error}&error_description=${errorMessage}&platform=tiktok&source=mobile&state=${state}`;
        this.logger.log(`Redirecting mobile OAuth error to web app: ${redirectUrl}`);
        return res?.redirect(redirectUrl);
      } else {
        const errorMessage = encodeURIComponent(
          errorDescription || 'TikTok authorization failed'
        );
        const redirectUrl = `https://sme-afrika.web.app/integrations?error=${errorMessage}`;
        return res?.redirect(redirectUrl);
      }
    }

    // Handle missing authorization code
    if (!code) {
      this.logger.error('No authorization code received');
      
      if (businessId) {
        await this.tikTokService.storeIntegrationError(
          businessId,
          'tiktok',
          'No authorization code received from TikTok'
        );
      }

      // Handle missing code with web app redirects
      if (isMobileRequest) {
        const errorMessage = encodeURIComponent('Authorization failed: No code received');
        const redirectUrl = `https://sme-afrika.web.app/integrations?error=no_code&error_description=${errorMessage}&platform=tiktok&source=mobile&state=${state}`;
        this.logger.log(`Redirecting mobile no-code error to web app: ${redirectUrl}`);
        return res?.redirect(redirectUrl);
      } else {
        const errorMessage = encodeURIComponent('Authorization failed: No code received');
        const redirectUrl = `https://sme-afrika.web.app/integrations?error=${errorMessage}`;
        return res?.redirect(redirectUrl);
      }
    }

    this.logger.log('Processing TikTok OAuth callback', {
      businessId,
      requestedChannels,
      hasCode: !!code
    });

    try {
      // Exchange code for access token
      const baseUrl = process.env.BASE_URL || 'https://seafrikaapi-u53tcgosiq-uc.a.run.app';
      const redirectUri = `${baseUrl}/api/config/tiktok/oauth/redirect`;
      
      // Retrieve and delete PKCE code verifier from Firestore
      const codeVerifier = await this.tikTokService.retrieveAndDeletePKCEVerifier(state);
      
      const authData = await this.tikTokService.exchangeCodeForTokens(
        code,
        redirectUri,
        codeVerifier,
        ['user.info.basic', 'user.info.profile', 'user.info.stats', 'video.list', 'video.upload']
      );

      this.logger.log('TikTok OAuth exchange successful', {
        openId: authData.userInfo.openId,
        businessId,
        requestedChannels
      });

      // Create TikTok integration if business ID is available
      let createdIntegrations: any[] = [];
      
      if (businessId && requestedChannels.includes('tiktok')) {
        this.logger.log(`Creating TikTok integration for business: ${businessId}`);
        try {
          const tikTokIntegration = await this.createTikTokIntegration(businessId, authData);
          if (tikTokIntegration) {
            createdIntegrations.push(tikTokIntegration);
            this.logger.log(`TikTok integration created successfully: ${tikTokIntegration.id}`);
          }
        } catch (integrationError) {
          this.logger.error(`Failed to create TikTok integration for business ${businessId}:`, integrationError);
          // Continue with redirect even if integration creation fails
        }
      } else {
        this.logger.warn(`Skipping TikTok integration creation:`, {
          businessId,
          requestedChannels,
          hasBusinessId: !!businessId,
          includesTikTok: requestedChannels.includes('tiktok')
        });
      }

      this.logger.log(`Created ${createdIntegrations.length} integrations for business ${businessId}`);

      // Trigger completion notification
      if (businessId) {
        await this.tikTokService.triggerAuthorizationComplete(businessId, {
          platform: 'tiktok',
          status: 'success',
          open_id: authData.userInfo.openId,
          timestamp: new Date().toISOString(),
          integration_id: createdIntegrations[0]?.id || 'unknown',
          created_integrations: createdIntegrations,
        });
      }

      // Redirect to success page (use web app hosted on Firebase)
      const successParams = new URLSearchParams({
        platform: 'tiktok',
        status: 'success',
        integrations: createdIntegrations.length.toString(),
      });
      
      if (isMobileRequest) {
        // For mobile, add additional data as query parameters
        successParams.append('open_id', authData.userInfo.openId);
        successParams.append('display_name', authData.userInfo.displayName || '');
        // Redirect to web app with mobile detection
        const redirectUrl = `https://sme-afrika.web.app/integrations?${successParams.toString()}&source=mobile`;
        this.logger.log(`Redirecting mobile success to web app: ${redirectUrl}`);
        return res?.redirect(redirectUrl);
      } else {
        // Web redirect as before
        const redirectUrl = `https://sme-afrika.web.app/integrations?${successParams.toString()}`;
        return res?.redirect(redirectUrl);
      }

    } catch (error) {
      this.logger.error('TikTok OAuth exchange failed:', error);

      if (businessId) {
        await this.tikTokService.storeIntegrationError(
          businessId,
          'tiktok',
          `OAuth exchange failed: ${error.message}`
        );
      }

      // Handle errors with web redirects for all requests
      if (isMobileRequest) {
        const errorMessage = encodeURIComponent(`TikTok authorization failed: ${error.message}`);
        const redirectUrl = `https://sme-afrika.web.app/integrations?error=${errorMessage}&platform=tiktok&source=mobile&state=${state}`;
        this.logger.log(`Redirecting mobile OAuth exchange error to web app: ${redirectUrl}`);
        return res?.redirect(redirectUrl);
      } else {
        const errorMessage = encodeURIComponent(
          `TikTok authorization failed: ${error.message}`
        );
        const redirectUrl = `https://sme-afrika.web.app/integrations?error=${errorMessage}`;
        return res?.redirect(redirectUrl);
      }
    }
  }

  @Get('user/profile')
  @ApiOperation({ summary: 'Get TikTok user profile' })
  @ApiResponse({ status: 200, description: 'User profile retrieved' })
  async getUserProfile(
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      return await this.tikTokService.getStoredUserProfile(businessId);
    } catch (error) {
      this.logger.error('Failed to get TikTok user profile:', error);
      throw new HttpException(
        `Failed to get user profile: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('user/info')
  @ApiOperation({ summary: 'Get TikTok user info with statistics' })
  @ApiResponse({ status: 200, description: 'User info retrieved' })
  async getUserInfo(
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      return await this.tikTokService.getUserInfo(businessId);
    } catch (error) {
      this.logger.error('Failed to get TikTok user info:', error);
      throw new HttpException(
        `Failed to get user info: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('integration/status')
  @ApiOperation({ summary: 'Get TikTok integration status' })
  @ApiResponse({ status: 200, description: 'Integration status retrieved' })
  async getIntegrationStatus(
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const integration = await this.tikTokService.getIntegrationForBusiness(businessId);
      
      return {
        is_connected: !!integration && integration.status === 'active',
        settings: integration?.settings || {},
        last_sync_at: integration?.lastSyncAt || null,
        created_at: integration?.createdAt || null,
        status: integration?.status || 'disconnected',
      };
    } catch (error) {
      this.logger.error('Failed to get integration status:', error);
      return {
        is_connected: false,
        settings: {},
        last_sync_at: null,
        created_at: null,
        status: 'disconnected',
      };
    }
  }

  @Put('integration/settings')
  @ApiOperation({ summary: 'Update TikTok integration settings' })
  @ApiResponse({ status: 200, description: 'Settings updated successfully' })
  @ApiBody({ description: 'Integration settings to update' })
  async updateIntegrationSettings(
    @Body() settings: any,
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.tikTokService.updateIntegrationSettings(businessId, settings);
      return { success: true, message: 'Settings updated successfully' };
    } catch (error) {
      this.logger.error('Failed to update integration settings:', error);
      throw new HttpException(
        `Failed to update settings: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('integration/sync')
  @ApiOperation({ summary: 'Trigger TikTok data sync' })
  @ApiResponse({ status: 200, description: 'Sync triggered successfully' })
  async syncTikTokData(
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.tikTokService.syncUserData(businessId);
      return { success: true, message: 'Data sync triggered successfully' };
    } catch (error) {
      this.logger.error('Failed to trigger data sync:', error);
      throw new HttpException(
        `Failed to trigger sync: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Delete('auth')
  @ApiOperation({ summary: 'Disconnect TikTok integration' })
  @ApiResponse({ status: 200, description: 'Integration disconnected successfully' })
  async disconnectTikTok(
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.tikTokService.disconnectIntegration(businessId);
      return { success: true, message: 'TikTok integration disconnected successfully' };
    } catch (error) {
      this.logger.error('Failed to disconnect TikTok integration:', error);
      throw new HttpException(
        `Failed to disconnect integration: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('integration/logs')
  @ApiOperation({ summary: 'Get TikTok integration logs' })
  @ApiResponse({ status: 200, description: 'Integration logs retrieved' })
  @ApiQuery({ name: 'limit', description: 'Number of logs to retrieve', required: false })
  async getIntegrationLogs(
    @Query('limit') limit: string = '50',
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const logs = await this.tikTokService.getIntegrationLogs(
        businessId,
        parseInt(limit, 10) || 50
      );
      return { logs };
    } catch (error) {
      this.logger.error('Failed to get integration logs:', error);
      throw new HttpException(
        `Failed to get logs: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('debug/oauth-urls')
  @ApiOperation({ summary: 'Debug TikTok OAuth URLs and configuration' })
  @ApiResponse({ status: 200, description: 'OAuth configuration debug information' })
  @ApiQuery({ name: 'redirect_uri', description: 'OAuth redirect URI to test' })
  async debugOAuthUrls(@Query('redirect_uri') redirectUri: string) {
    if (!redirectUri) {
      throw new HttpException(
        'redirect_uri parameter is required for debugging',
        HttpStatus.BAD_REQUEST,
      );
    }

    const tikTokClientKey = this.configService.get('TIKTOK_CLIENT_KEY');
    const tikTokClientSecret = this.configService.get('TIKTOK_CLIENT_SECRET');

    const authUrl = this.tikTokService.generateAuthUrl({
      scopes: ['user.info.basic', 'user.info.profile', 'user.info.stats', 'video.list', 'video.upload'],
      redirectUri,
      state: 'debug_test'
    });

    return {
      configuration: {
        tiktok_client_key: tikTokClientKey || 'NOT_SET',
        tiktok_client_secret: tikTokClientSecret ? 'SET' : 'NOT_SET',
        redirect_uri: redirectUri,
      },
      oauth_urls: {
        auth_url: authUrl,
        description: 'TikTok for Business OAuth 2.0 authorization URL',
        scopes: ['user.info.basic', 'user.info.profile', 'user.info.stats', 'video.list', 'video.upload'],
      },
      test_steps: [
        'Copy the auth_url above',
        'Open it in a browser',
        'Complete TikTok authorization',
        'Check if redirect works correctly',
      ],
      webhook_info: {
        webhook_url: `${process.env.BASE_URL || 'https://seafrikaapi-u53tcgosiq-uc.a.run.app'}/api/webhooks/tiktok/webhook`,
        webhook_secret: 'seafrika_tiktok_webhook_2024',
      },
    };
  }

  @Get('troubleshoot')
  @ApiOperation({ summary: 'TikTok integration troubleshooting guide' })
  @ApiResponse({ status: 200, description: 'Troubleshooting information' })
  async troubleshootTikTok() {
    const baseUrl = process.env.BASE_URL || 'https://seafrikaapi-u53tcgosiq-uc.a.run.app';
    
    return {
      common_issues: [
        {
          issue: 'OAuth redirect URL mismatch',
          solution: `Ensure redirect URL in TikTok Developer Console exactly matches: ${baseUrl}/api/config/tiktok/oauth/redirect`,
        },
        {
          issue: 'Missing client credentials',
          solution: 'Check TIKTOK_CLIENT_KEY and TIKTOK_CLIENT_SECRET environment variables',
        },
        {
          issue: 'Webhook verification failing',
          solution: 'Verify webhook secret matches: seafrika_tiktok_webhook_2024',
        },
        {
          issue: 'App not approved for production',
          solution: 'TikTok app must be approved for production use. Use test environment for development.',
        },
      ],
      configuration_checklist: [
        'TikTok Developer App created',
        'OAuth redirect URI configured',
        'Client Key and Secret set in environment',
        'Webhook URL configured in TikTok Console',
        'Required scopes enabled',
        'App approved for production (if needed)',
      ],
      required_scopes: [
        'user.info.basic - Get basic user information',
        'video.list - List user videos',
        'video.upload - Upload videos (if needed)',
      ],
      webhook_events: [
        'video.publish - Video published',
        'video.delete - Video deleted',
        'comment.create - New comment',
        'comment.delete - Comment deleted',
      ],
    };
  }

  /**
   * Create TikTok integration for a business
   */
  private async createTikTokIntegration(businessId: string, authData: any): Promise<any> {
    try {
      const integration = await this.tikTokService.storeCredentials(businessId, authData.credentials);

      this.logger.log(`TikTok integration created for business: ${businessId}`);
      return integration;
    } catch (error) {
      this.logger.error(`Failed to create TikTok integration for business ${businessId}:`, error);
      throw error;
    }
  }

  /**
   * Get integration errors for a business
   */
  @Get('/errors/:businessId')
  async getIntegrationErrors(
    @Param('businessId') businessId: string,
    @Query('platformId') platformId?: string
  ): Promise<any> {
    try {
      const errors = await this.tikTokService.getIntegrationErrors(businessId, platformId);
      
      return {
        success: true,
        errors: errors,
        count: errors.length
      };
    } catch (error) {
      this.logger.error('Failed to retrieve integration errors:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Mark integration error as resolved
   */
  @Post('/errors/:errorId/resolve')
  async resolveIntegrationError(@Param('errorId') errorId: string): Promise<any> {
    try {
      await this.tikTokService.markErrorAsResolved(errorId);
      
      return {
        success: true,
        message: 'Error marked as resolved'
      };
    } catch (error) {
      this.logger.error('Failed to resolve integration error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Cleanup incomplete integrations (migrate to integration_errors collection)
   */
  @Post('/cleanup/incomplete-integrations')
  async cleanupIncompleteIntegrations(): Promise<any> {
    try {
      await this.tikTokService.cleanupIncompleteIntegrations();
      
      return {
        success: true,
        message: 'Incomplete integrations cleanup completed'
      };
    } catch (error) {
      this.logger.error('Failed to cleanup incomplete integrations:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }
}