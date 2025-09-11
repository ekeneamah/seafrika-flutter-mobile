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
  const clientId = this.configService.get('FACEBOOK_APP_ID');
  const baseUrl = 'https://www.facebook.com/v21.0/dialog/oauth';

  // Build scopes based on the features you plan to enable
  const scopes = [
    'pages_show_list',
    'pages_manage_metadata',
    'pages_read_engagement',
    'business_management',
    'instagram_basic',
    'instagram_content_publish',     // optional: publishing
    'instagram_manage_comments',     // optional: comments
    'instagram_manage_messages',     // optional: messaging
    'read_insights'                  // optional: insights
  ].join(',');

  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,          // must EXACTLY match the one in the app settings
    scope: scopes,
    response_type: 'code',
    display: 'popup',
    auth_type: 'rerequest',
    return_scopes: 'true'
  });

  if (state) params.append('state', state);

  const url = `${baseUrl}?${params.toString()}`;
  this.logger.log('Generated Facebook OAuth URL:', url);
  return url;
}


  /**
   * Generate Instagram Basic Display authorization URL (for personal accounts)
   */
  generateInstagramBasicAuthUrl(redirectUri: string, state?: string): string {
    const clientId = this.configService.get('INSTAGRAM_APP_ID') || this.configService.get('FACEBOOK_APP_ID');
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

    this.logger.log('Generated Instagram Basic OAuth URL:', `${baseUrl}?${params.toString()}`);
    return `${baseUrl}?${params.toString()}`;
  }

  /**
   * Exchange authorization code for access token (using Facebook Graph API)
   */
  async exchangeCodeForToken(code: string, redirectUri: string, businessId?: string): Promise<{
    access_token: string;
    user_id: string;
    token_type?: string;
    expires_in?: number;
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

      // Use Facebook Graph API token exchange endpoint with GET request
      const response = await axios.get('https://graph.facebook.com/v21.0/oauth/access_token', {
        params: {
          client_id: clientId,
          client_secret: clientSecret,
          grant_type: 'authorization_code',
          redirect_uri: redirectUri,
          code: code,
        },
      });

      // Get user information with the access token
      let userId = 'unknown';
      try {
        const userResponse = await axios.get('https://graph.facebook.com/v21.0/me', {
          params: {
            access_token: response.data.access_token,
            fields: 'id,name'
          }
        });
        userId = userResponse.data.id;
      } catch (userError) {
        this.logger.warn('Failed to get user info, using default user_id:', userError.message);
      }

      // Log successful token exchange
      if (businessId) {
        await this.logInstagramActivity(businessId, 'token_exchange_success', {
          user_id: userId,
          has_access_token: !!response.data.access_token,
          token_type: response.data.token_type,
          expires_in: response.data.expires_in,
        });
      }

      return {
        access_token: response.data.access_token,
        user_id: userId,
        token_type: response.data.token_type,
        expires_in: response.data.expires_in,
      };
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
  async subscribeToWebhooks(instagramUserId: string, accessToken: string) {
  try {
    const response = await axios.post(
      `https://graph.facebook.com/v21.0/${instagramUserId}/subscribed_apps`,
      { subscribed_fields: ['comments', 'mentions', 'messages'] },
      { params: { access_token: accessToken } }
    );
    return { success: true, message: 'Successfully subscribed to Instagram webhooks' };
  } catch (error: any) {
    this.logger.error('Failed to subscribe to webhooks:', error.response?.data || error.message);
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
    return await this.getInstagramBusinessProfile(accessToken);
  } catch (businessError) {
    this.logger.warn(
      'Instagram Business Account not found or improperly connected:',
      businessError.message,
    );
    throw new Error(
      'Instagram Business integration failed. Please ensure your Instagram account is a Business Account and linked to a Facebook Page.'
    );
  }
}
  async getInstagramProfileXX(accessToken: string): Promise<any> {
    // Strategy 1: Try Instagram Business Account via Facebook pages
    try {
      return await this.getInstagramBusinessProfile(accessToken);
    } catch (businessError) {
      this.logger.warn('Instagram Business Account not found, trying Basic Display:', businessError.message);
    }

    // Strategy 2: Try Instagram Basic Display API
    try {
      return await this.getInstagramBasicProfile(accessToken);
    } catch (basicError) {
      this.logger.warn('Instagram Basic Display failed:', basicError.message);
    }

    // Strategy 3: Get basic user info if Instagram-specific APIs fail
    try {
      this.logger.log('Attempting Facebook User Profile as fallback');
      return await this.getFacebookUserProfile(accessToken);
    } catch (userError) {
      this.logger.error('All profile strategies failed:', userError.message);
      throw new Error(`Unable to fetch any profile information. Business Account: not found, Basic Display: token incompatible, Facebook Profile: ${userError.message}`);
    }
  }

  /**
   * Get Instagram Business Account profile via Facebook pages
   */
private async getInstagramBusinessProfile(userToken: string): Promise<any> {
  // 1) Get all Pages (paginate)
  const pages: Array<{ id: string; name: string; access_token?: string }> = [];
  let nextUrl = 'https://graph.facebook.com/v21.0/me/accounts';
  let params: Record<string, any> = {
    fields: 'id,name,access_token',
    access_token: userToken,
    limit: 50,
  };

  while (nextUrl) {
    const resp = await axios.get(nextUrl, { params });
    const body = resp.data || {};
    if (Array.isArray(body.data)) pages.push(...body.data);
    nextUrl = body.paging?.next ?? null;
    params = {}; // 'next' already carries the token & cursor
  }

  this.logger.log(`Fetched ${pages.length} managed Pages`);

  if (pages.length === 0) {
    // Very common: missing scope pages_show_list OR user isn’t a Page Admin OR no Page granted in consent dialog
    throw new Error(
      'No Facebook Pages returned. Ensure the login requested "pages_show_list", the user is a Page Admin, and the Page was selected in the consent dialog.'
    );
  }

  // 2) For each Page, try to read connected IG using the PAGE token
  for (const p of pages) {
    const pageId = p.id;
    const pageName = p.name;
    const pageToken = p.access_token;

    if (!pageToken) {
      this.logger.warn(`Skipping Page ${pageId} (${pageName}) — no page access_token granted`);
      continue;
    }

    try {
      // IMPORTANT: use connected_instagram_account
      const linkResp = await axios.get(`https://graph.facebook.com/v21.0/${pageId}`, {
        params: {
          fields: 'connected_instagram_account{id}',
          access_token: pageToken,
        },
      });

      const igId = linkResp.data?.connected_instagram_account?.id;
      if (!igId) {
        this.logger.log(`Page ${pageId} (${pageName}) has no connected_instagram_account`);
        continue;
      }

      // 3) Fetch IG user details (page token is valid for this)
      const igResp = await axios.get(`https://graph.facebook.com/v21.0/${igId}`, {
        params: {
          // Add/remove fields to taste; some require additional permissions
          fields:
            'id,username,name,biography,followers_count,follows_count,media_count,profile_picture_url,website',
          access_token: pageToken,
        },
      });

      const profile = igResp.data || {};
      const result = {
        ...profile,
        instagram_user_id: profile.id,
        facebook_page_id: pageId,
        facebook_page_name: pageName,
        api_type: 'Instagram Graph API',
        // Don’t hardcode BUSINESS; Creator can also be linked
        account_type: profile.account_type ?? 'PROFESSIONAL',
        // Feature flags reflect what your app *can* do if you also requested/approved the scopes
        features: {
          view_profile: true,
          view_media: true,
          basic_insights: true,
          publish_content: true,      // needs instagram_content_publish + pages_manage_posts
          manage_comments: true,      // needs instagram_manage_comments
          advanced_analytics: true,   // needs read_insights
        },
      };

      this.logger.log('Resolved Instagram via Page linkage:', {
        pageId,
        pageName,
        instagram_user_id: igId,
        username: profile.username,
      });

      return result;
    } catch (err: any) {
      const msg = err?.response?.data?.error?.message || err?.message;
      const code = err?.response?.data?.error?.code;
      this.logger.warn(
        `Failed IG lookup for Page ${pageId} (${pageName}) — ${code ?? ''} ${msg}`
      );
      // continue to next Page
    }
  }

  // 4) Nothing found after checking all Pages
  this.logger.warn('No connected Instagram account found on any granted Page', {
    pages_checked: pages.length,
    pages_with_tokens: pages.filter(x => !!x.access_token).length,
  });

  throw new Error(
    'No connected Instagram account found. Link your Instagram Business/Creator account to a Facebook Page (Page Settings → Linked Accounts → Instagram), ensure you are Page Admin, and re-grant access selecting that Page in the consent dialog.'
  );
}


  /**
   * Get Instagram Basic Display profile
   */
  private async getInstagramBasicProfile(accessToken: string): Promise<any> {
    try {
      // Get basic Instagram user info via Basic Display API
      // Note: Basic Display API only provides: id, username, account_type, media_count
      const response = await axios.get('https://graph.instagram.com/me', {
        params: {
          fields: 'id,username,account_type,media_count',
          access_token: accessToken,
        },
      });

      this.logger.log('Instagram Basic Display response:', response.data);

      const result = {
        ...response.data,
        name: response.data.username, // Use username as name for basic accounts
        profile_picture_url: null, // Basic Display API doesn't provide profile picture
        biography: null, // Basic Display API doesn't provide biography
        followers_count: null, // Basic Display API doesn't provide follower count
        follows_count: null, // Basic Display API doesn't provide following count
        website: null, // Basic Display API doesn't provide website
        account_type: response.data.account_type || 'PERSONAL',
        api_type: 'Instagram Basic Display API',
        features: {
          view_profile: true,
          view_media: true,
          basic_insights: false,
          publish_content: false,
          manage_comments: false,
          advanced_analytics: false,
        },
      };

      this.logger.log('Instagram Basic Display result:', result);
      return result;
    } catch (error) {
      this.logger.error('Instagram Basic Display API error:', error.response?.data || error.message);
      throw new Error(`Instagram Basic Display API failed: ${error.response?.data?.error?.message || error.message}`);
    }
  }

  /**
   * Get Facebook user profile as fallback
   */
  private async getFacebookUserProfile(accessToken: string): Promise<any> {
    const response = await axios.get('https://graph.facebook.com/v21.0/me', {
      params: {
        fields: 'id,name,email,picture',
        access_token: accessToken,
      },
    });

    return {
      id: response.data.id,
      username: response.data.name?.replace(/\s+/g, '').toLowerCase() || `user_${response.data.id}`,
      name: response.data.name,
      email: response.data.email,
      profile_picture_url: response.data.picture?.data?.url,
      account_type: 'FACEBOOK_USER',
      api_type: 'Facebook Graph API',
      // Explicitly set Instagram fields to null since this is just a Facebook profile
      biography: null,
      followers_count: null,
      follows_count: null,
      media_count: null,
      website: null,
      facebook_page_id: null,
      facebook_page_name: null,
      features: {
        view_profile: true,
        view_media: false, // No Instagram media access
        basic_insights: false,
        publish_content: false,
        manage_comments: false,
        advanced_analytics: false,
      },
      // Add helpful message for users
      message: 'No Instagram Business Account found. Connect an Instagram Business Account to your Facebook Page for full Instagram features.',
    };
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
      const response = await axios.get(`https://graph.facebook.com/v21.0/${appId}`, {
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
        `https://graph.facebook.com/v21.0/${pageId}/subscribed_apps`,
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
   * Refresh Instagram Basic Display access token (only for Basic Display API)
   */
  async refreshBasicDisplayToken(accessToken: string): Promise<{
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
      this.logger.error('Failed to refresh Basic Display token:', error.response?.data);
      throw new Error('Failed to refresh Instagram Basic Display token');
    }
  }

  /**
   * Flag Graph API tokens that are expiring soon
   * Facebook Graph API tokens cannot be refreshed - users must re-authenticate
   */
  async flagGraphTokensExpiringSoon(): Promise<{
    expiring_tokens: Array<{
      businessId: string;
      integration_id: string;
      expires_at: string;
      days_until_expiry: number;
    }>;
    total_flagged: number;
  }> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const sevenDaysFromNow = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
      
      // Get all active Instagram integrations
      const integrationQuery = await integrationsCollection
        .where('platformId', '==', 'instagram')
        .where('status', '==', 'active')
        .get();

      const expiringTokens = [];
      
      for (const doc of integrationQuery.docs) {
        const integration = doc.data();
        const credentials = integration.credentials;
        
        if (credentials && credentials.expires_in && credentials.created_at) {
          const createdAt = new Date(credentials.created_at);
          const expiresAt = new Date(createdAt.getTime() + (credentials.expires_in * 1000));
          const now = new Date();
          const daysUntilExpiry = Math.ceil((expiresAt.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));
          
          // Flag if expires within 7 days
          if (daysUntilExpiry <= 7 && daysUntilExpiry > 0) {
            expiringTokens.push({
              businessId: integration.businessId,
              integration_id: doc.id,
              expires_at: expiresAt.toISOString(),
              days_until_expiry: daysUntilExpiry,
            });
            
            // Update integration status to indicate reconnection needed
            await doc.ref.update({
              status: 'reconnect_needed',
              reconnect_reason: `Token expires in ${daysUntilExpiry} day(s)`,
              flagged_at: new Date().toISOString(),
              updatedAt: new Date().toISOString(),
            });
            
            // Log the flagging
            await this.logInstagramActivity(integration.businessId, 'token_expiring_flagged', {
              integration_id: doc.id,
              expires_at: expiresAt.toISOString(),
              days_until_expiry: daysUntilExpiry,
            });
          }
        }
      }
      
      this.logger.log(`Flagged ${expiringTokens.length} expiring Graph API tokens`);
      
      return {
        expiring_tokens: expiringTokens,
        total_flagged: expiringTokens.length,
      };
    } catch (error) {
      this.logger.error('Failed to flag expiring tokens:', error);
      throw new Error('Failed to check for expiring tokens');
    }
  }

  /**
   * Store integration with error status when OAuth fails
   */
  async storeIntegrationError(businessId: string, platform: string, errorMessage: string): Promise<void> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const now = new Date().toISOString();
      
      // Check if incomplete integration already exists for this platform
      const existingQuery = await integrationsCollection
        .where('businessId', '==', businessId)
        .where('platformId', '==', platform)
        .where('status', 'in', ['incomplete', 'error'])
        .get();

      const integrationData: any = {
        businessId: businessId,
        platformId: platform,
        platformName: this.getPlatformDisplayName(platform),
        platformIcon: `assets/icons/${platform}.png`,
        status: 'incomplete',
        error_message: errorMessage,
        updatedAt: now,
        settings: {
          autoSync: false,
          syncInterval: 60,
          syncInventory: false,
          syncOrders: false,
          syncProducts: true,
        }
      };

      if (!existingQuery.empty) {
        // Update existing incomplete integration
        const existingDoc = existingQuery.docs[0];
        await existingDoc.ref.update({
          ...integrationData,
          id: existingDoc.id, // Include document ID
          createdAt: existingDoc.data().createdAt, // Keep original creation time
        });
      } else {
        // Create new incomplete integration
        integrationData.createdAt = now;
        const docRef = await integrationsCollection.add(integrationData);
        // Update the document to include its own ID
        await docRef.update({ id: docRef.id });
      }
      
      this.logger.log(`Integration error stored for ${platform} - Business: ${businessId}`);
    } catch (error) {
      this.logger.error(`Failed to store integration error for ${platform}:`, error);
    }
  }

  private getPlatformDisplayName(platform: string): string {
    const platformNames: Record<string, string> = {
      instagram: 'Instagram',
      shopify: 'Shopify',
      woocommerce: 'WooCommerce',
      square: 'Square',
      paypal: 'PayPal',
      stripe: 'Stripe'
    };
    return platformNames[platform.toLowerCase()] || platform;
  }

  /**
   * Store Instagram integration for a business
   */
  async storeInstagramCredentials(businessId: string, credentials: {
    access_token: string;
    user_id: string;
    expires_in?: number;
  }): Promise<void> {
    try {
      // Validate required fields
      if (!credentials.access_token || !credentials.user_id) {
        throw new Error('Access token and user_id are required');
      }

      // Check if Instagram integration already exists for this business
      const integrationsCollection = this.firestoreService.collection('integrations');
      const existingQuery = await integrationsCollection
        .where('businessId', '==', businessId)
        .where('platformId', '==', 'instagram')
        .where('status', '!=', 'deleted')
        .get();

      const now = new Date().toISOString();
      const integrationData = {
        businessId: businessId,
        platformId: 'instagram',
        platformName: 'Instagram',
        platformIcon: 'assets/icons/instagram.png',
        status: 'active',
        createdAt: now,
        updatedAt: now,
        settings: {
          autoSync: false,
          syncInterval: 60,
          syncInventory: false,
          syncOrders: false,
          syncProducts: true,
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        },
        credentials: {
          access_token: credentials.access_token,
          user_id: credentials.user_id,
          expires_in: credentials.expires_in || null,
          token_type: 'Bearer',
          created_at: now,
          updated_at: now,
        }
      };

      if (!existingQuery.empty) {
        // Update existing integration
        const existingDoc = existingQuery.docs[0];
        await existingDoc.ref.update({
          ...integrationData,
          id: existingDoc.id, // Include document ID
          createdAt: existingDoc.data().createdAt, // Keep original creation time
        });
        this.logger.log(`Instagram integration updated for business: ${businessId}`);
      } else {
        // Create new integration
        const docRef = await integrationsCollection.add(integrationData);
        // Update the document to include its own ID
        await docRef.update({ id: docRef.id });
        this.logger.log(`Instagram integration created for business: ${businessId}`);
      }
      
      // Log the activity
      await this.logInstagramActivity(businessId, 'integration_stored', {
        user_id: credentials.user_id,
        has_access_token: !!credentials.access_token,
        expires_in: credentials.expires_in || null,
        action: !existingQuery.empty ? 'updated' : 'created',
      });
      
    } catch (error) {
      // Log the error
      await this.logInstagramActivity(businessId, 'integration_store_error', {
        error: error.message,
        has_access_token: !!credentials?.access_token,
        has_user_id: !!credentials?.user_id,
      });
      this.logger.error('Failed to store Instagram integration:', error);
      throw new Error('Failed to store Instagram integration');
    }
  }

  /**
   * Get Instagram business profile using stored credentials
   */
  async getStoredInstagramProfile(businessId: string): Promise<any> {
    try {
      // Log the profile fetch attempt
      await this.logInstagramActivity(businessId, 'profile_fetch_attempt', {
        method: 'getInstagramBusinessProfile',
        using_facebook_graph_api: true,
      });

      // Get stored integration
      const integrationsCollection = this.firestoreService.collection('integrations');
      const integrationQuery = await integrationsCollection
        .where('businessId', '==', businessId)
        .where('platformId', '==', 'instagram')
        .where('status', '==', 'active')
        .limit(1)
        .get();
      
      if (integrationQuery.empty) {
        await this.logInstagramActivity(businessId, 'profile_fetch_no_credentials', {
          message: 'No active Instagram integration found in Firestore',
        });
        throw new Error('No Instagram integration found for this business');
      }

      const integrationDoc = integrationQuery.docs[0];
      const integration = integrationDoc.data();
      const credentials = integration.credentials;
      
      if (!credentials || !credentials.access_token) {
        await this.logInstagramActivity(businessId, 'profile_fetch_no_token', {
          message: 'Integration found but no access token available',
        });
        throw new Error('No valid access token found');
      }

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

      // Get integration data if business ID provided
      if (businessId) {
        try {
          const integrationsCollection = this.firestoreService.collection('integrations');
          const integrationQuery = await integrationsCollection
            .where('businessId', '==', businessId)
            .where('platformId', '==', 'instagram')
            .limit(1)
            .get();
            
          if (!integrationQuery.empty) {
            const integrationDoc = integrationQuery.docs[0];
            const integrationData = integrationDoc.data();
            logs.push({
              type: 'integration_stored',
              timestamp: integrationData.updatedAt || integrationData.createdAt,
              business_id: businessId,
              details: {
                user_id: integrationData.credentials?.user_id,
                has_access_token: !!integrationData.credentials?.access_token,
                expires_in: integrationData.credentials?.expires_in,
                platform_name: integrationData.platformName,
                status: integrationData.status,
                created_at: integrationData.createdAt,
                updated_at: integrationData.updatedAt,
              }
            });
          } else {
            logs.push({
              type: 'integration_missing',
              timestamp: new Date().toISOString(),
              business_id: businessId,
              details: {
                message: 'No Instagram integration found for this business ID'
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

  /**
   * Trigger authorization completion notification via Firestore
   */
  async triggerAuthorizationComplete(businessId: string, authData: {
    platform: string;
    status: 'success' | 'error';
    user_id?: string;
    error?: string;
    timestamp: string;
    integration_id: string;
  }): Promise<void> {
    try {
      // Clean the data to remove undefined values for Firestore
      const cleanNotificationData = {
        businessId,
        type: 'authorization_complete',
        platform: authData.platform,
        status: authData.status,
        timestamp: authData.timestamp,
        integration_id: authData.integration_id,
        read: false,
        expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(), // Expire in 5 minutes
      };

      // Only add optional fields if they have values
      if (authData.user_id !== undefined) {
        cleanNotificationData['user_id'] = authData.user_id;
      }
      if (authData.error !== undefined) {
        cleanNotificationData['error'] = authData.error;
      }

      // Add to authorization_notifications collection
      await this.firestoreService.collection('authorization_notifications').add(cleanNotificationData);

      // Also update a real-time status document that the app can watch
      const statusDocRef = this.firestoreService.collection('authorization_status').doc(businessId);
      const cleanStatusData = {
        platform: authData.platform,
        status: authData.status,
        timestamp: authData.timestamp,
        integration_id: authData.integration_id,
        last_updated: new Date().toISOString(),
      };

      // Only add optional fields if they have values
      if (authData.user_id !== undefined) {
        cleanStatusData['user_id'] = authData.user_id;
      }
      if (authData.error !== undefined) {
        cleanStatusData['error'] = authData.error;
      }

      await statusDocRef.set(cleanStatusData, { merge: true });

      this.logger.log(`Authorization completion triggered for business: ${businessId}, platform: ${authData.platform}`);
    } catch (error) {
      this.logger.error('Failed to trigger authorization completion:', error);
      // Don't throw error to avoid breaking the main OAuth flow
    }
  }

  async logInstagramActivity(businessId: string, activity: string, data: any): Promise<void> {
    try {
      // Clean the data object to remove undefined values
      const cleanedData = JSON.parse(JSON.stringify(data || {}));
      
      await this.firestoreService.collection('instagram_activity_logs').add({
        businessId,
        activity,
        data: cleanedData,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      this.logger.error('Failed to log Instagram activity:', error);
      // Don't throw error to avoid breaking main flow
    }
  }

  /**
   * Get all integrations for a business
   */
  async getIntegrationsForBusiness(businessId: string): Promise<any[]> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const snapshot = await integrationsCollection
        .where('businessId', '==', businessId)
        .where('status', '!=', 'deleted')
        .orderBy('createdAt', 'desc')
        .get();

      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
    } catch (error) {
      this.logger.error('Failed to get integrations for business:', error);
      throw new Error('Failed to fetch integrations');
    }
  }

  /**
   * Disconnect an integration (soft delete)
   */
  async disconnectIntegration(integrationId: string, businessId: string): Promise<void> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const integrationDoc = await integrationsCollection.doc(integrationId).get();
      
      if (!integrationDoc.exists) {
        throw new Error('Integration not found');
      }

      const integration = integrationDoc.data();
      if (integration.businessId !== businessId) {
        throw new Error('Integration does not belong to this business');
      }

      await integrationDoc.ref.update({
        status: 'disconnected',
        updatedAt: new Date().toISOString(),
        disconnectedAt: new Date().toISOString(),
      });

      // Log the disconnection
      await this.logInstagramActivity(businessId, 'integration_disconnected', {
        integration_id: integrationId,
        platform: integration.platformId,
        platform_name: integration.platformName,
      });

      this.logger.log(`Integration ${integrationId} disconnected for business: ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to disconnect integration:', error);
      throw new Error('Failed to disconnect integration');
    }
  }
}
