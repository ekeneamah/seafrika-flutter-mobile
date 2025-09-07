import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../firestore/firestore.service';
import axios from 'axios';

/**
 * Facebook Configuration Service
 * 
 * This service handles Instagram Business integrations using Facebook Graph API.
 * 
 * IMPORTANT: We use Facebook Graph API (not Instagram Basic Display API) because:
 * - Instagram Basic Display API is for personal accounts and basic features
 * - Facebook Graph API provides access to Instagram Business features:
 *   * Business insights and analytics
 *   * Content publishing
 *   * Comments management
 *   * Direct messaging
 *   * Advanced media management
 * 
 * Authentication Flow:
 * 1. User authorizes via Facebook OAuth (https://www.facebook.com/v21.0/dialog/oauth)
 * 2. We get access to their Facebook pages
 * 3. We find pages connected to Instagram Business Accounts
 * 4. We use the Facebook access token to manage Instagram Business features
 * 
 * Required Permissions:
 * - pages_show_list: See Facebook pages
 * - pages_manage_metadata: Manage page information
 * - instagram_basic: Basic Instagram account access
 * - instagram_content_publish: Publish content
 * - instagram_manage_comments: Manage comments
 * - instagram_manage_insights: Access analytics
 * - instagram_manage_messages: Manage direct messages
 */

@Injectable()
export class FacebookConfigService {
  private readonly logger = new Logger(FacebookConfigService.name);

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Validate Facebook/Instagram configuration (now using Facebook Graph API)
   */
  async validateConfiguration(): Promise<{
    isValid: boolean;
    errors: string[];
    warnings: string[];
  }> {
    const errors: string[] = [];
    const warnings: string[] = [];

    // Check required environment variables for Facebook Graph API
    const requiredVars = [
      'FACEBOOK_APP_ID',
      'FACEBOOK_APP_SECRET',
    ];

    for (const varName of requiredVars) {
      const value = this.configService.get(varName);
      if (!value) {
        errors.push(`Missing required environment variable: ${varName}`);
      }
    }

    // Check optional Instagram Basic Display variables (if still using for some features)
    const optionalVars = [
      'INSTAGRAM_APP_ID',
      'INSTAGRAM_APP_SECRET',
      'INSTAGRAM_VERIFY_TOKEN',
    ];
    
    for (const varName of optionalVars) {
      const value = this.configService.get(varName);
      if (!value) {
        warnings.push(`Missing optional Instagram Basic Display variable: ${varName} (only needed for Basic Display features)`);
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
   * Generate Instagram authorization URL (using Facebook Graph API for Business features)
   */
  generateInstagramAuthUrl(redirectUri: string, state?: string): string {
    const clientId = this.configService.get('FACEBOOK_APP_ID'); // Use Facebook App ID for Graph API
    const baseUrl = 'https://www.facebook.com/v21.0/dialog/oauth'; // Facebook Graph OAuth URL
    
    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      scope: 'pages_show_list,pages_manage_metadata,instagram_basic,instagram_content_publish,instagram_manage_comments,instagram_manage_insights,instagram_manage_messages',
      response_type: 'code',
    });

    if (state) {
      params.append('state', state);
    }

    return `${baseUrl}?${params.toString()}`;
  }

  /**
   * Exchange authorization code for access token (using Facebook Graph API)
   */
  async exchangeCodeForToken(code: string, redirectUri: string, businessId?: string): Promise<{
    access_token: string;
    user_id: string;
  }> {
    const clientId = this.configService.get('FACEBOOK_APP_ID'); // Use Facebook App ID
    const clientSecret = this.configService.get('FACEBOOK_APP_SECRET'); // Use Facebook App Secret

    try {
      // Log the token exchange attempt
      if (businessId) {
        await this.logInstagramActivity(businessId, 'token_exchange_attempt', {
          code_provided: !!code,
          code_length: code?.length,
          redirect_uri: redirectUri,
          using_facebook_graph_api: true,
        });
      }

      // Use Facebook Graph API token exchange endpoint
      const response = await axios.post('https://graph.facebook.com/v21.0/oauth/access_token', {
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

      // Log successful token exchange
      if (businessId) {
        await this.logInstagramActivity(businessId, 'token_exchange_success', {
          user_id: response.data.user_id,
          has_access_token: !!response.data.access_token,
          token_type: response.data.token_type,
          expires_in: response.data.expires_in,
        });
      }

      return response.data;
    } catch (error) {
      // Log the error
      if (businessId) {
        await this.logInstagramActivity(businessId, 'token_exchange_error', {
          error: error.message,
          response_status: error.response?.status,
          response_data: error.response?.data,
          using_facebook_graph_api: true,
        });
      }
      
      this.logger.error('Failed to exchange code for token:', error.response?.data);
      throw new Error('Failed to exchange authorization code for access token');
    }
  }

  /**
   * Get long-lived access token (Facebook Graph API)
   */
  async getLongLivedToken(shortLivedToken: string): Promise<{
    access_token: string;
    token_type: string;
    expires_in: number;
  }> {
    const clientId = this.configService.get('FACEBOOK_APP_ID'); // Use Facebook App ID
    const clientSecret = this.configService.get('FACEBOOK_APP_SECRET'); // Use Facebook App Secret

    try {
      // For Facebook Graph API, exchange short-lived token for long-lived token
      const response = await axios.get('https://graph.facebook.com/v21.0/oauth/access_token', {
        params: {
          grant_type: 'fb_exchange_token',
          client_id: clientId,
          client_secret: clientSecret,
          fb_exchange_token: shortLivedToken,
        },
      });

      return {
        access_token: response.data.access_token,
        token_type: response.data.token_type || 'bearer',
        expires_in: response.data.expires_in || 5183944, // ~60 days default for Facebook
      };
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
   * Get Instagram Business Account via Facebook Graph API
   */
  async getInstagramProfile(accessToken: string): Promise<any> {
    try {
      // First, get the user's Facebook pages
      const pagesResponse = await axios.get('https://graph.facebook.com/v21.0/me/accounts', {
        params: {
          fields: 'id,name,instagram_business_account',
          access_token: accessToken,
        },
      });

      this.logger.log('Facebook pages response:', pagesResponse.data);

      // Find a page with an Instagram Business Account
      const pageWithInstagram = pagesResponse.data.data.find(
        (page: any) => page.instagram_business_account
      );

      if (!pageWithInstagram) {
        throw new Error('No Instagram Business Account found connected to Facebook pages');
      }

      const instagramAccountId = pageWithInstagram.instagram_business_account.id;

      // Get Instagram Business Account details
      const instagramResponse = await axios.get(`https://graph.facebook.com/v21.0/${instagramAccountId}`, {
        params: {
          fields: 'id,username,name,biography,followers_count,follows_count,media_count,profile_picture_url,website',
          access_token: accessToken,
        },
      });

      return {
        ...instagramResponse.data,
        facebook_page_id: pageWithInstagram.id,
        facebook_page_name: pageWithInstagram.name,
        account_type: 'BUSINESS', // Instagram Business Account
      };
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

  /**
   * Store Instagram credentials for a business
   */
  async storeInstagramCredentials(businessId: string, credentials: {
    access_token: string;
    user_id: string;
    expires_in?: number;
  }): Promise<void> {
    try {
      const docRef = this.firestoreService.collection('instagram_credentials').doc(businessId);
      await docRef.set({
        ...credentials,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
      
      // Log the activity
      await this.logInstagramActivity(businessId, 'credentials_stored', {
        user_id: credentials.user_id,
        has_access_token: !!credentials.access_token,
        expires_in: credentials.expires_in,
      });
      
      this.logger.log(`Instagram credentials stored for business: ${businessId}`);
    } catch (error) {
      // Log the error
      await this.logInstagramActivity(businessId, 'credentials_store_error', {
        error: error.message,
      });
      this.logger.error('Failed to store Instagram credentials:', error);
      throw new Error('Failed to store Instagram credentials');
    }
  }

  /**
   * Get Instagram business profile using stored credentials
   */
  async getInstagramBusinessProfile(businessId: string): Promise<any> {
    try {
      // Log the profile fetch attempt
      await this.logInstagramActivity(businessId, 'profile_fetch_attempt', {
        method: 'getInstagramBusinessProfile',
        using_facebook_graph_api: true,
      });

      // Get stored credentials
      const credDoc = await this.firestoreService.collection('instagram_credentials').doc(businessId).get();
      
      if (!credDoc.exists) {
        await this.logInstagramActivity(businessId, 'profile_fetch_no_credentials', {
          message: 'No credentials found in Firestore',
        });
        throw new Error('No Instagram credentials found for this business');
      }

      const credentials = credDoc.data();
      const accessToken = credentials.access_token;

      if (!accessToken) {
        await this.logInstagramActivity(businessId, 'profile_fetch_no_token', {
          message: 'Credentials exist but no access_token',
        });
        throw new Error('No access token found in credentials');
      }

      // Get profile using Facebook Graph API (which gets Instagram Business Account)
      const profile = await this.getInstagramProfile(accessToken);
      
      // Log successful profile fetch
      await this.logInstagramActivity(businessId, 'profile_fetch_success', {
        username: profile.username,
        account_type: profile.account_type,
        media_count: profile.media_count,
        followers_count: profile.followers_count,
        facebook_page_id: profile.facebook_page_id,
        facebook_page_name: profile.facebook_page_name,
      });
      
      // Add stored credentials info to response
      return {
        ...profile,
        access_token: accessToken,
        user_id: credentials.user_id,
        expires_in: credentials.expires_in,
        stored_at: credentials.created_at,
      };
    } catch (error) {
      // Log the error
      await this.logInstagramActivity(businessId, 'profile_fetch_error', {
        error: error.message,
        error_type: error.constructor.name,
        using_facebook_graph_api: true,
      });
      
      this.logger.error('Failed to get Instagram business profile:', error);
      throw new Error('Failed to fetch Instagram business profile');
    }
  }

  /**
   * Get Instagram integration logs for debugging
   */
  async getInstagramIntegrationLogs(businessId?: string, userId?: string): Promise<any[]> {
    try {
      const logs: any[] = [];

      // Get credentials data if business ID provided
      if (businessId) {
        try {
          const credDoc = await this.firestoreService.collection('instagram_credentials').doc(businessId).get();
          if (credDoc.exists) {
            const credData = credDoc.data();
            logs.push({
              type: 'credentials_stored',
              timestamp: credData.created_at || credData.updated_at,
              business_id: businessId,
              details: {
                user_id: credData.user_id,
                has_access_token: !!credData.access_token,
                expires_in: credData.expires_in,
                created_at: credData.created_at,
                updated_at: credData.updated_at,
              }
            });
          } else {
            logs.push({
              type: 'credentials_missing',
              timestamp: new Date().toISOString(),
              business_id: businessId,
              details: {
                message: 'No credentials found for this business ID'
              }
            });
          }
        } catch (error) {
          logs.push({
            type: 'credentials_error',
            timestamp: new Date().toISOString(),
            business_id: businessId,
            details: {
              error: error.message
            }
          });
        }
      }

      // Get integration records from Firestore (if available)
      if (businessId) {
        try {
          const integrationQuery = await this.firestoreService
            .collection('integrations')
            .where('platformId', '==', 'instagram')
            .get();

          integrationQuery.forEach((doc) => {
            const data = doc.data();
            if (data.businessId === businessId || !businessId) {
              logs.push({
                type: 'integration_record',
                timestamp: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
                business_id: data.businessId || businessId,
                details: {
                  integration_id: doc.id,
                  status: data.status,
                  platform_id: data.platformId,
                  platform_name: data.platformName,
                  has_credentials: !!data.credentials,
                  credentials_keys: data.credentials ? Object.keys(data.credentials) : [],
                  created_at: data.createdAt?.toDate?.()?.toISOString(),
                }
              });
            }
          });
        } catch (error) {
          logs.push({
            type: 'integration_query_error',
            timestamp: new Date().toISOString(),
            business_id: businessId,
            details: {
              error: error.message
            }
          });
        }
      }

      // Add current environment status
      logs.push({
        type: 'environment_status',
        timestamp: new Date().toISOString(),
        details: {
          // Primary (required) - Facebook Graph API credentials
          has_facebook_app_id: !!this.configService.get('FACEBOOK_APP_ID'),
          has_facebook_app_secret: !!this.configService.get('FACEBOOK_APP_SECRET'),
          // Secondary (optional) - Instagram Basic Display (for legacy features)
          has_instagram_app_id: !!this.configService.get('INSTAGRAM_APP_ID'),
          has_instagram_app_secret: !!this.configService.get('INSTAGRAM_APP_SECRET'),
          // Environment info
          base_url: this.configService.get('BASE_URL') || 'not_set',
          node_env: this.configService.get('NODE_ENV') || 'not_set',
          auth_flow: 'facebook_graph_api', // Indicate we're using Facebook Graph API
        }
      });

      // Sort logs by timestamp (newest first)
      logs.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

      return logs;
    } catch (error) {
      this.logger.error('Failed to get Instagram integration logs:', error);
      throw new Error('Failed to fetch Instagram integration logs');
    }
  }

  async logInstagramActivity(businessId: string, activity: string, data: any): Promise<void> {
    try {
      await this.firestoreService.collection('instagram_activity_logs').add({
        businessId,
        activity,
        data,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      this.logger.error('Failed to log Instagram activity:', error);
      // Don't throw error to avoid breaking main flow
    }
  }
}
