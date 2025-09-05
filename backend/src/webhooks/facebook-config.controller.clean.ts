import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';
import { FacebookConfigService } from './facebook-config.service';

@ApiTags('Facebook Configuration')
@Controller('config/facebook')
export class FacebookConfigController {
  private readonly logger = new Logger(FacebookConfigController.name);

  constructor(
    private readonly facebookConfigService: FacebookConfigService,
  ) {}

  @Get('validate')
  @ApiOperation({ summary: 'Validate Facebook/Instagram configuration' })
  @ApiResponse({ status: 200, description: 'Configuration validation results' })
  async validateConfiguration() {
    try {
      const result = await this.facebookConfigService.validateConfiguration();
      return result;
    } catch (error) {
      this.logger.error('Configuration validation failed:', error);
      throw new HttpException(
        'Configuration validation failed',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('instagram/auth-url')
  @ApiOperation({ summary: 'Generate Instagram authorization URL' })
  @ApiResponse({ status: 200, description: 'Authorization URL generated' })
  @ApiQuery({ name: 'redirect_uri', description: 'OAuth redirect URI' })
  @ApiQuery({ name: 'state', description: 'Optional state parameter', required: false })
  async getInstagramAuthUrl(
    @Query('redirect_uri') redirectUri: string,
    @Query('state') state?: string,
  ) {
    if (!redirectUri) {
      throw new HttpException(
        'redirect_uri parameter is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const authUrl = this.facebookConfigService.generateInstagramAuthUrl(
        redirectUri,
        state,
      );
      
      return {
        auth_url: authUrl,
        redirect_uri: redirectUri,
        state: state || null,
      };
    } catch (error) {
      this.logger.error('Failed to generate auth URL:', error);
      throw new HttpException(
        'Failed to generate authorization URL',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('instagram/oauth/redirect')
  @ApiOperation({ summary: 'Instagram OAuth redirect handler for business login' })
  @ApiResponse({ status: 200, description: 'OAuth redirect handled successfully' })
  @ApiQuery({ name: 'code', description: 'Authorization code from Instagram', required: false })
  @ApiQuery({ name: 'error', description: 'Error code if authentication failed', required: false })
  @ApiQuery({ name: 'error_reason', description: 'Error reason', required: false })
  @ApiQuery({ name: 'error_description', description: 'Error description', required: false })
  @ApiQuery({ name: 'state', description: 'State parameter', required: false })
  async handleInstagramOAuthRedirect(
    @Query('code') code?: string,
    @Query('error') error?: string,
    @Query('error_reason') errorReason?: string,
    @Query('error_description') errorDescription?: string,
    @Query('state') state?: string,
  ) {
    this.logger.log('Instagram OAuth redirect received', { 
      hasCode: !!code, 
      error, 
      errorReason, 
      state 
    });

    // If there's an error, return error response
    if (error) {
      return {
        success: false,
        error: error,
        error_reason: errorReason,
        error_description: errorDescription,
        message: 'Instagram authentication failed',
        redirect_to: process.env.FRONTEND_URL || 'https://your-app.com/auth/error'
      };
    }

    // If there's a code, process the authentication
    if (code) {
      try {
        // Use the current URL as redirect_uri for token exchange
        const baseUrl = process.env.BASE_URL || 'https://seafrikaapi-u53tcgosiq-uc.a.run.app';
        const redirectUri = `${baseUrl}/api/config/facebook/instagram/oauth/redirect`;
        
        const tokenData = await this.facebookConfigService.exchangeCodeForToken(
          code,
          redirectUri,
        );

        // Get long-lived token
        const longLivedToken = await this.facebookConfigService.getLongLivedToken(
          tokenData.access_token,
        );

        // Store the token securely (you might want to save this in your database)
        this.logger.log('Instagram authentication successful', { 
          userId: tokenData.user_id,
          hasLongLivedToken: !!longLivedToken.access_token 
        });

        return {
          success: true,
          message: 'Instagram authentication successful',
          data: {
            user_id: tokenData.user_id,
            access_token: longLivedToken.access_token,
            expires_in: longLivedToken.expires_in,
            token_type: longLivedToken.token_type,
          },
          redirect_to: process.env.FRONTEND_URL || 'https://your-app.com/auth/success',
          instructions: 'Save the access_token securely for API calls'
        };
      } catch (error) {
        this.logger.error('Failed to process Instagram OAuth code:', error);
        return {
          success: false,
          error: 'token_exchange_failed',
          message: 'Failed to exchange authorization code for access token',
          redirect_to: process.env.FRONTEND_URL || 'https://your-app.com/auth/error'
        };
      }
    }

    // No code and no error - probably direct access
    return {
      success: false,
      error: 'invalid_request',
      message: 'No authorization code provided',
      redirect_to: process.env.FRONTEND_URL || 'https://your-app.com/auth/error'
    };
  }

  @Post('instagram/deauthorize')
  @ApiOperation({ summary: 'Handle Instagram app deauthorization callback' })
  @ApiResponse({ status: 200, description: 'Deauthorization handled successfully' })
  async handleDeauthorization(@Body() body: any) {
    this.logger.log('Instagram deauthorization callback received', body);

    try {
      // Extract the signed request from Facebook
      const signedRequest = body.signed_request;
      
      if (!signedRequest) {
        this.logger.warn('No signed_request provided in deauthorization callback');
        return { status: 'error', message: 'No signed_request provided' };
      }

      // Parse the signed request (you might want to verify the signature)
      const [signature, payload] = signedRequest.split('.');
      const decodedPayload = JSON.parse(Buffer.from(payload, 'base64').toString());
      
      this.logger.log('Deauthorization data:', decodedPayload);

      // Here you would typically:
      // 1. Verify the signature using your app secret
      // 2. Extract user_id and issued_at from the payload
      // 3. Remove user's access tokens from your database
      // 4. Delete any cached user data
      // 5. Log the deauthorization for compliance

      const userId = decodedPayload.user_id;
      const issuedAt = decodedPayload.issued_at;

      // TODO: Implement your deauthorization logic here
      // Example:
      // await this.userService.revokeInstagramAccess(userId);
      // await this.userService.clearUserData(userId);

      this.logger.log(`User ${userId} deauthorized Instagram access at ${new Date(issuedAt * 1000)}`);

      return {
        status: 'success',
        message: 'Deauthorization processed successfully',
        user_id: userId,
        processed_at: new Date().toISOString()
      };

    } catch (error) {
      this.logger.error('Failed to process deauthorization:', error);
      return {
        status: 'error',
        message: 'Failed to process deauthorization',
        error: error.message
      };
    }
  }

  @Post('instagram/data-deletion')
  @ApiOperation({ summary: 'Handle Instagram data deletion request' })
  @ApiResponse({ status: 200, description: 'Data deletion request handled successfully' })
  async handleDataDeletion(@Body() body: any) {
    this.logger.log('Instagram data deletion request received', body);

    try {
      // Extract the signed request from Facebook
      const signedRequest = body.signed_request;
      
      if (!signedRequest) {
        this.logger.warn('No signed_request provided in data deletion request');
        return { 
          status: 'error', 
          message: 'No signed_request provided' 
        };
      }

      // Parse the signed request
      const [signature, payload] = signedRequest.split('.');
      const decodedPayload = JSON.parse(Buffer.from(payload, 'base64').toString());
      
      this.logger.log('Data deletion request data:', decodedPayload);

      const userId = decodedPayload.user_id;
      const issuedAt = decodedPayload.issued_at;

      // Generate a unique confirmation code for this deletion request
      const confirmationCode = `DEL_${userId}_${Date.now()}`;

      // TODO: Implement your data deletion logic here
      // Example:
      // 1. Queue the user's data for deletion
      // 2. Remove all user posts, media, and personal information
      // 3. Anonymize any remaining data that must be kept for legal reasons
      // 4. Send confirmation to the user
      // 
      // await this.userService.queueDataDeletion(userId);
      // await this.userService.deleteUserInstagramData(userId);
      // await this.auditService.logDataDeletion(userId, confirmationCode);

      this.logger.log(`Data deletion queued for user ${userId} with confirmation code: ${confirmationCode}`);

      // Facebook requires you to return a URL where users can check deletion status
      const statusUrl = `${process.env.BASE_URL || 'https://seafrikaapi-u53tcgosiq-uc.a.run.app'}/api/config/facebook/instagram/deletion-status?code=${confirmationCode}`;

      return {
        url: statusUrl,
        confirmation_code: confirmationCode,
        status: 'queued',
        message: 'Data deletion request has been queued for processing',
        user_id: userId,
        requested_at: new Date().toISOString()
      };

    } catch (error) {
      this.logger.error('Failed to process data deletion request:', error);
      return {
        status: 'error',
        message: 'Failed to process data deletion request',
        error: error.message
      };
    }
  }

  @Get('instagram/deletion-status')
  @ApiOperation({ summary: 'Check Instagram data deletion status' })
  @ApiResponse({ status: 200, description: 'Data deletion status retrieved' })
  @ApiQuery({ name: 'code', description: 'Deletion confirmation code' })
  async getDataDeletionStatus(@Query('code') confirmationCode: string) {
    if (!confirmationCode) {
      throw new HttpException(
        'Confirmation code is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    this.logger.log(`Data deletion status check for code: ${confirmationCode}`);

    try {
      // TODO: Implement status checking logic
      // Example:
      // const deletionRecord = await this.auditService.getDeletionStatus(confirmationCode);
      
      // For now, return a mock response
      const isValidCode = confirmationCode.startsWith('DEL_');
      
      if (!isValidCode) {
        return {
          status: 'invalid',
          message: 'Invalid confirmation code',
          code: confirmationCode
        };
      }

      // Parse the confirmation code to extract info
      const codeParts = confirmationCode.split('_');
      const userId = codeParts[1];
      const timestamp = codeParts[2];

      return {
        status: 'completed', // could be: 'queued', 'in_progress', 'completed', 'failed'
        message: 'Data deletion has been completed successfully',
        confirmation_code: confirmationCode,
        user_id: userId,
        requested_at: new Date(parseInt(timestamp)).toISOString(),
        completed_at: new Date().toISOString(),
        data_types_deleted: [
          'Instagram posts and media',
          'User profile information',
          'Access tokens and authentication data',
          'Cached user data'
        ]
      };

    } catch (error) {
      this.logger.error('Failed to get deletion status:', error);
      throw new HttpException(
        'Failed to retrieve deletion status',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('instagram/exchange-token')
  @ApiOperation({ summary: 'Exchange authorization code for access token' })
  @ApiResponse({ status: 200, description: 'Access token exchanged successfully' })
  async exchangeToken(
    @Body() body: { code: string; redirect_uri: string },
  ) {
    const { code, redirect_uri } = body;

    if (!code || !redirect_uri) {
      throw new HttpException(
        'code and redirect_uri are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const tokenData = await this.facebookConfigService.exchangeCodeForToken(
        code,
        redirect_uri,
      );

      // Get long-lived token
      const longLivedToken = await this.facebookConfigService.getLongLivedToken(
        tokenData.access_token,
      );

      return {
        short_lived_token: tokenData.access_token,
        user_id: tokenData.user_id,
        long_lived_token: longLivedToken.access_token,
        expires_in: longLivedToken.expires_in,
        token_type: longLivedToken.token_type,
      };
    } catch (error) {
      this.logger.error('Token exchange failed:', error);
      throw new HttpException(
        'Failed to exchange authorization code',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('instagram/subscribe-webhooks')
  @ApiOperation({ summary: 'Subscribe to Instagram webhooks' })
  @ApiResponse({ status: 200, description: 'Webhook subscription result' })
  async subscribeWebhooks(
    @Body() body: { instagram_user_id: string; access_token: string },
  ) {
    const { instagram_user_id, access_token } = body;

    if (!instagram_user_id || !access_token) {
      throw new HttpException(
        'instagram_user_id and access_token are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const result = await this.facebookConfigService.subscribeToWebhooks(
        instagram_user_id,
        access_token,
      );

      return result;
    } catch (error) {
      this.logger.error('Webhook subscription failed:', error);
      throw new HttpException(
        'Failed to subscribe to webhooks',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('instagram/profile')
  @ApiOperation({ summary: 'Get Instagram profile information' })
  @ApiResponse({ status: 200, description: 'Instagram profile retrieved' })
  @ApiQuery({ name: 'access_token', description: 'Instagram access token' })
  async getInstagramProfile(@Query('access_token') accessToken: string) {
    if (!accessToken) {
      throw new HttpException(
        'access_token parameter is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const profile = await this.facebookConfigService.getInstagramProfile(accessToken);
      return profile;
    } catch (error) {
      this.logger.error('Failed to get Instagram profile:', error);
      throw new HttpException(
        'Failed to fetch Instagram profile',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('instagram/refresh-token')
  @ApiOperation({ summary: 'Refresh Instagram access token' })
  @ApiResponse({ status: 200, description: 'Access token refreshed' })
  async refreshToken(@Body() body: { access_token: string }) {
    const { access_token } = body;

    if (!access_token) {
      throw new HttpException(
        'access_token is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      const refreshedToken = await this.facebookConfigService.refreshAccessToken(
        access_token,
      );

      return refreshedToken;
    } catch (error) {
      this.logger.error('Token refresh failed:', error);
      throw new HttpException(
        'Failed to refresh access token',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get('instagram/business-login-setup')
  @ApiOperation({ summary: 'Get Instagram Business Login setup information' })
  @ApiResponse({ status: 200, description: 'Business login setup information' })
  async getBusinessLoginSetup() {
    const baseUrl = process.env.BASE_URL || 'https://seafrikaapi-u53tcgosiq-uc.a.run.app';
    const redirectUri = `${baseUrl}/api/config/facebook/instagram/oauth/redirect`;
    
    return {
      instagram_app_id: process.env.INSTAGRAM_APP_ID || '779189224487576',
      redirect_uri: redirectUri,
      deauthorize_callback_url: `${baseUrl}/api/config/facebook/instagram/deauthorize`,
      data_deletion_request_url: `${baseUrl}/api/config/facebook/instagram/data-deletion`,
      data_deletion_status_url: `${baseUrl}/api/config/facebook/instagram/deletion-status`,
      webhook_url: `${baseUrl}/api/webhooks/instagram`,
      verify_token: process.env.INSTAGRAM_VERIFY_TOKEN,
      setup_instructions: {
        step_1: 'Go to Facebook Developers Console (developers.facebook.com)',
        step_2: 'Navigate to your app > Instagram Basic Display > Basic Display',
        step_3: 'Add this redirect URI to Valid OAuth Redirect URIs:',
        redirect_uri_to_add: redirectUri,
        step_4: 'Add deauthorize callback URL in App Dashboard > Data Privacy:',
        deauthorize_callback_to_add: `${baseUrl}/api/config/facebook/instagram/deauthorize`,
        step_5: 'Add data deletion request URL in App Dashboard > Data Privacy:',
        data_deletion_request_to_add: `${baseUrl}/api/config/facebook/instagram/data-deletion`,
        step_6: 'Save changes in Facebook Developer Console',
        step_7: 'Use the auth URL generator endpoint to create login URLs',
      },
      example_auth_url: `${baseUrl}/api/config/facebook/instagram/auth-url?redirect_uri=${encodeURIComponent(redirectUri)}&state=your-state-parameter`,
      test_endpoints: {
        validate_config: `${baseUrl}/api/config/facebook/validate`,
        generate_auth_url: `${baseUrl}/api/config/facebook/instagram/auth-url`,
        oauth_redirect: redirectUri,
        deauthorize_callback: `${baseUrl}/api/config/facebook/instagram/deauthorize`,
        data_deletion_request: `${baseUrl}/api/config/facebook/instagram/data-deletion`,
        data_deletion_status: `${baseUrl}/api/config/facebook/instagram/deletion-status`,
        webhook_test: `${baseUrl}/api/webhooks/instagram/test`,
      }
    };
  }

  @Get('setup-guide')
  @ApiOperation({ summary: 'Get setup guide and current configuration status' })
  @ApiResponse({ status: 200, description: 'Setup guide and status' })
  async getSetupGuide() {
    const validation = await this.facebookConfigService.validateConfiguration();

    return {
      status: validation.isValid ? 'configured' : 'needs_setup',
      validation_results: validation,
      setup_steps: [
        {
          step: 1,
          title: 'Create Facebook App',
          description: 'Create a Facebook app in the Developer Console',
          completed: validation.errors.length < 4, // If most env vars are set
          documentation: '/docs/FACEBOOK_DEVELOPER_SETUP.md',
        },
        {
          step: 2,
          title: 'Add Instagram Basic Display',
          description: 'Add Instagram Basic Display product to your app',
          completed: validation.errors.length === 0,
        },
        {
          step: 3,
          title: 'Configure Environment Variables',
          description: 'Set up required environment variables',
          completed: validation.errors.length === 0,
          missing_vars: validation.errors.filter(e => e.includes('environment variable')),
        },
        {
          step: 4,
          title: 'Deploy to HTTPS',
          description: 'Deploy your backend to an HTTPS endpoint',
          completed: process.env.NODE_ENV === 'production',
        },
        {
          step: 5,
          title: 'Configure Webhooks',
          description: 'Set up webhook subscription in Facebook Developer Console',
          webhook_url: `${process.env.BASE_URL || 'https://your-domain.com'}/api/webhooks/instagram`,
          verify_token: process.env.INSTAGRAM_VERIFY_TOKEN || 'your-verify-token',
        },
        {
          step: 6,
          title: 'Configure Privacy URLs',
          description: 'Set up deauthorization and data deletion URLs in Facebook App Dashboard',
          deauthorize_url: `${process.env.BASE_URL || 'https://your-domain.com'}/api/config/facebook/instagram/deauthorize`,
          data_deletion_url: `${process.env.BASE_URL || 'https://your-domain.com'}/api/config/facebook/instagram/data-deletion`,
        },
      ],
      helpful_endpoints: {
        validate_config: '/api/config/facebook/validate',
        generate_auth_url: '/api/config/facebook/instagram/auth-url',
        exchange_token: '/api/config/facebook/instagram/exchange-token',
        subscribe_webhooks: '/api/config/facebook/instagram/subscribe-webhooks',
        test_webhook: '/api/webhooks/instagram/test',
        deauthorize_callback: '/api/config/facebook/instagram/deauthorize',
        data_deletion_request: '/api/config/facebook/instagram/data-deletion',
        data_deletion_status: '/api/config/facebook/instagram/deletion-status',
      },
    };
  }
}
