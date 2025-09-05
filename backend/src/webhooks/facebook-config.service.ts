import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

@Injectable()
export class FacebookConfigService {
  private readonly logger = new Logger(FacebookConfigService.name);

  constructor(private readonly configService: ConfigService) {}

  /**
   * Validate Facebook/Instagram configuration
   */
  async validateConfiguration(): Promise<{
    isValid: boolean;
    errors: string[];
    warnings: string[];
  }> {
    const errors: string[] = [];
    const warnings: string[] = [];

    // Check required environment variables
    const requiredVars = [
      'FACEBOOK_APP_ID',
      'FACEBOOK_APP_SECRET',
      'INSTAGRAM_APP_ID',
      'INSTAGRAM_APP_SECRET',
      'INSTAGRAM_VERIFY_TOKEN',
    ];

    for (const varName of requiredVars) {
      const value = this.configService.get(varName);
      if (!value) {
        errors.push(`Missing required environment variable: ${varName}`);
      }
    }

    // Check optional but recommended variables
    const recommendedVars = ['INSTAGRAM_ACCESS_TOKEN'];
    for (const varName of recommendedVars) {
      const value = this.configService.get(varName);
      if (!value) {
        warnings.push(`Missing recommended environment variable: ${varName}`);
      }
    }

    // Validate app configuration with Facebook API if credentials are available
    if (errors.length === 0) {
      try {
        await this.validateFacebookApp();
      } catch (error) {
        errors.push(`Facebook app validation failed: ${error.message}`);
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
      warnings,
    };
  }

  /**
   * Generate Instagram authorization URL
   */
  generateInstagramAuthUrl(redirectUri: string, state?: string): string {
    const clientId = this.configService.get('INSTAGRAM_APP_ID');
    const baseUrl = 'https://api.instagram.com/oauth/authorize';
    
    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      scope: 'user_profile,user_media',
      response_type: 'code',
    });

    if (state) {
      params.append('state', state);
    }

    return `${baseUrl}?${params.toString()}`;
  }

  /**
   * Exchange authorization code for access token
   */
  async exchangeCodeForToken(code: string, redirectUri: string): Promise<{
    access_token: string;
    user_id: string;
  }> {
    const clientId = this.configService.get('INSTAGRAM_APP_ID');
    const clientSecret = this.configService.get('INSTAGRAM_APP_SECRET');

    try {
      const response = await axios.post('https://api.instagram.com/oauth/access_token', {
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
        code: code,
      }, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      });

      return response.data;
    } catch (error) {
      this.logger.error('Failed to exchange code for token:', error.response?.data);
      throw new Error('Failed to exchange authorization code for access token');
    }
  }

  /**
   * Get long-lived access token
   */
  async getLongLivedToken(shortLivedToken: string): Promise<{
    access_token: string;
    token_type: string;
    expires_in: number;
  }> {
    const clientSecret = this.configService.get('INSTAGRAM_APP_SECRET');

    try {
      const response = await axios.get('https://graph.instagram.com/access_token', {
        params: {
          grant_type: 'ig_exchange_token',
          client_secret: clientSecret,
          access_token: shortLivedToken,
        },
      });

      return response.data;
    } catch (error) {
      this.logger.error('Failed to get long-lived token:', error.response?.data);
      throw new Error('Failed to exchange for long-lived token');
    }
  }

  /**
   * Subscribe to Instagram webhooks
   */
  async subscribeToWebhooks(instagramUserId: string, accessToken: string): Promise<{
    success: boolean;
    message: string;
  }> {
    try {
      const response = await axios.post(
        `https://graph.facebook.com/v18.0/${instagramUserId}/subscribed_apps`,
        {},
        {
          params: {
            access_token: accessToken,
          },
        },
      );

      return {
        success: true,
        message: 'Successfully subscribed to Instagram webhooks',
      };
    } catch (error) {
      this.logger.error('Failed to subscribe to webhooks:', error.response?.data);
      return {
        success: false,
        message: `Failed to subscribe: ${error.response?.data?.error?.message || error.message}`,
      };
    }
  }

  /**
   * Get Instagram user profile
   */
  async getInstagramProfile(accessToken: string): Promise<any> {
    try {
      const response = await axios.get('https://graph.instagram.com/me', {
        params: {
          fields: 'id,username,account_type,media_count',
          access_token: accessToken,
        },
      });

      return response.data;
    } catch (error) {
      this.logger.error('Failed to get Instagram profile:', error.response?.data);
      throw new Error('Failed to fetch Instagram profile');
    }
  }

  /**
   * Validate Facebook app with Graph API
   */
  private async validateFacebookApp(): Promise<void> {
    const appId = this.configService.get('FACEBOOK_APP_ID');
    const appSecret = this.configService.get('FACEBOOK_APP_SECRET');

    // Generate app access token
    const appAccessToken = `${appId}|${appSecret}`;

    try {
      const response = await axios.get(`https://graph.facebook.com/v18.0/${appId}`, {
        params: {
          access_token: appAccessToken,
          fields: 'id,name,category',
        },
      });

      this.logger.log(`Facebook app validated: ${response.data.name}`);
    } catch (error) {
      throw new Error(`Facebook app validation failed: ${error.response?.data?.error?.message || error.message}`);
    }
  }

  /**
   * Get webhook subscription status
   */
  async getWebhookSubscriptions(pageId: string, accessToken: string): Promise<any> {
    try {
      const response = await axios.get(
        `https://graph.facebook.com/v18.0/${pageId}/subscribed_apps`,
        {
          params: {
            access_token: accessToken,
          },
        },
      );

      return response.data;
    } catch (error) {
      this.logger.error('Failed to get webhook subscriptions:', error.response?.data);
      throw new Error('Failed to fetch webhook subscriptions');
    }
  }

  /**
   * Refresh Instagram access token
   */
  async refreshAccessToken(accessToken: string): Promise<{
    access_token: string;
    token_type: string;
    expires_in: number;
  }> {
    try {
      const response = await axios.get('https://graph.instagram.com/refresh_access_token', {
        params: {
          grant_type: 'ig_refresh_token',
          access_token: accessToken,
        },
      });

      return response.data;
    } catch (error) {
      this.logger.error('Failed to refresh access token:', error.response?.data);
      throw new Error('Failed to refresh access token');
    }
  }
}
