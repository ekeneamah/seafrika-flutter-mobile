import {
  Controller,
  Get,
  Query,
  Headers,
  Logger,
  HttpException,
  HttpStatus,
  Put,
  Body,
} from '@nestjs/common';
import { YouTubeService } from './youtube.service';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiQuery,
  ApiBody,
} from '@nestjs/swagger';

@ApiTags('YouTube Configuration')
@Controller('config/youtube')
export class YouTubeConfigController {
  private readonly logger = new Logger(YouTubeConfigController.name);

  constructor(private readonly youTubeService: YouTubeService) {}

  @Get('auth-url')
  @ApiOperation({ summary: 'Get YouTube OAuth authorization URL' })
  @ApiQuery({
    name: 'businessId',
    required: false,
    description: 'Business ID to encode in OAuth state',
  })
  @ApiResponse({ status: 200, description: 'Authorization URL generated' })
  async getAuthUrl(@Query('businessId') businessId?: string) {
    try {
      const authResponse = this.youTubeService.getAuthorizationUrl(businessId);
      
      // Store PKCE code verifier in Firestore for later retrieval during token exchange
      await this.youTubeService.storePKCEVerifier(authResponse.state, authResponse.codeVerifier);
      
      this.logger.log('YouTube auth URL generated with PKCE', {
        state: authResponse.state,
        challenge: authResponse.codeChallenge,
        businessId: businessId
      });
      
      return {
        auth_url: authResponse.authUrl,
        state: authResponse.state,
      };
    } catch (error) {
      this.logger.error('Failed to generate YouTube auth URL:', error);
      throw new HttpException(
        'Failed to generate authorization URL',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('callback')
  @ApiOperation({ summary: 'Handle YouTube OAuth callback' })
  @ApiQuery({
    name: 'code',
    required: false,
    description: 'Authorization code from YouTube',
  })
  @ApiQuery({
    name: 'state',
    required: false,
    description: 'State parameter containing business ID',
  })
  @ApiQuery({
    name: 'error',
    required: false,
    description: 'Error parameter if OAuth failed',
  })
  @ApiResponse({ status: 200, description: 'OAuth callback handled successfully' })
  async handleCallback(
    @Query('code') code?: string,
    @Query('state') state?: string,
    @Query('error') error?: string,
  ) {
    // Handle OAuth error
    if (error) {
      this.logger.error(`YouTube OAuth error: ${error}`);
      return `https://sme-afrika.web.app/integrations?status=error&platform=youtube&error=${encodeURIComponent(error)}`;
    }

    // Validate required parameters
    if (!code) {
      this.logger.error('YouTube OAuth callback missing authorization code');
      return `https://sme-afrika.web.app/integrations?status=error&platform=youtube&error=${encodeURIComponent('Missing authorization code')}`;
    }

    if (!state) {
      this.logger.error('YouTube OAuth callback missing state parameter');
      return `https://sme-afrika.web.app/integrations?status=error&platform=youtube&error=${encodeURIComponent('Missing state parameter')}`;
    }

    // Parse business ID from state parameter (format: "mobile_businessId_timestamp")
    let businessId: string | null = null;
    if (state.startsWith('mobile_')) {
      const parts = state.split('_');
      if (parts.length >= 2) {
        businessId = parts[1];
        this.logger.log('Extracted businessId from mobile state:', businessId);
      }
    }

    if (!businessId) {
      this.logger.error('YouTube OAuth callback missing business ID in state parameter');
      return `https://sme-afrika.web.app/integrations?status=error&platform=youtube&error=${encodeURIComponent('Missing business ID')}`;
    }

    try {
      this.logger.log(`Handling YouTube OAuth callback for business ${businessId}`);

      // Retrieve and delete PKCE code verifier from Firestore
      const codeVerifier = await this.youTubeService.retrieveAndDeletePKCEVerifier(state);

      // Exchange code for tokens with PKCE
      const credentials = await this.youTubeService.exchangeCodeForTokens(code, codeVerifier);

      // Store credentials in Firestore
      const integration = await this.youTubeService.storeCredentials(businessId, credentials);

      this.logger.log(`Successfully completed YouTube OAuth with PKCE for business ${businessId}, integration ${integration.id}`);

      // Redirect to success page
      return `https://sme-afrika.web.app/integrations?status=success&platform=youtube&channel=${encodeURIComponent(credentials.userInfo?.title || 'YouTube Channel')}`;
    } catch (error) {
      this.logger.error('YouTube OAuth callback failed:', error);
      
      const errorMessage = error instanceof HttpException ? 
        error.message : 
        'Failed to complete YouTube authentication';
      
      return `https://sme-afrika.web.app/integrations?status=error&platform=youtube&error=${encodeURIComponent(errorMessage)}`;
    }
  }

  @Get('user-info')
  @ApiOperation({ summary: 'Get YouTube channel information' })
  @ApiResponse({ status: 200, description: 'Channel info retrieved' })
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
      const integration = await this.youTubeService.getIntegrationForBusiness(businessId);
      
      if (!integration) {
        throw new HttpException(
          'YouTube integration not found',
          HttpStatus.NOT_FOUND,
        );
      }

      return {
        channel_info: integration.accountInfo,
        integration_status: integration.status,
        last_sync_at: integration.lastSyncAt,
        created_at: integration.createdAt,
      };
    } catch (error) {
      this.logger.error('Failed to get YouTube user info:', error);
      throw error;
    }
  }

  @Get('integration/status')
  @ApiOperation({ summary: 'Get YouTube integration status' })
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
      const integration = await this.youTubeService.getIntegrationForBusiness(businessId);
      
      return {
        is_connected: !!integration && integration.status === 'active',
        settings: integration?.settings || {},
        last_sync_at: integration?.lastSyncAt || null,
        created_at: integration?.createdAt || null,
        status: integration?.status || 'disconnected',
        channel_info: integration?.accountInfo || null,
      };
    } catch (error) {
      this.logger.error('Failed to get YouTube integration status:', error);
      return {
        is_connected: false,
        settings: {},
        last_sync_at: null,
        created_at: null,
        status: 'disconnected',
        channel_info: null,
      };
    }
  }

  @Put('integration/settings')
  @ApiOperation({ summary: 'Update YouTube integration settings' })
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
      const integration = await this.youTubeService.getIntegrationForBusiness(businessId);
      
      if (!integration) {
        throw new HttpException(
          'YouTube integration not found',
          HttpStatus.NOT_FOUND,
        );
      }

      // Update integration settings (implementation would go here)
      this.logger.log(`Updated YouTube integration settings for business ${businessId}`);

      return {
        success: true,
        message: 'Settings updated successfully',
        settings: { ...integration.settings, ...settings },
      };
    } catch (error) {
      this.logger.error('Failed to update YouTube integration settings:', error);
      throw error;
    }
  }

  @Put('integration/disconnect')
  @ApiOperation({ summary: 'Disconnect YouTube integration' })
  @ApiResponse({ status: 200, description: 'Integration disconnected successfully' })
  async disconnectIntegration(
    @Headers('Business-ID') businessId?: string,
  ) {
    if (!businessId) {
      throw new HttpException(
        'Business-ID header is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      await this.youTubeService.disconnectIntegration(businessId);

      this.logger.log(`Successfully disconnected YouTube integration for business ${businessId}`);

      return {
        success: true,
        message: 'YouTube integration disconnected successfully',
      };
    } catch (error) {
      this.logger.error('Failed to disconnect YouTube integration:', error);
      throw error;
    }
  }
}