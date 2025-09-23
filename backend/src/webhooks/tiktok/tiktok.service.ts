import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { FirestoreService } from '../../firestore/firestore.service';
import axios from 'axios';
import * as crypto from 'crypto';
import { ConfigService } from '@nestjs/config';

/**
 * TikTok Integration Service
 * 
 * Comprehensive service for TikTok Business API integration following TikTok best practices.
 * 
 * Features:
 * - OAuth 2.0 authentication with TikTok Login Kit
 * - Secure token management and refresh
 * - Business account management
 * - Webhook event handling
 * - Content management through Creator API
 * 
 * Supported Scopes:
 * - user.info.basic: Basic user information
 * - user.info.profile: User profile information  
 * - video.list: Access user's video list
 * - video.upload: Upload videos to user's account
 * - business.auth: Business account authentication
 */

export interface TikTokCredentials {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  refreshExpiresAt: number;
  scopes: string[];
  userId: string;
  userInfo?: TikTokUserInfo;
}

export interface TikTokUserInfo {
  openId: string;
  unionId: string;
  displayName: string;
  username: string;
  avatarUrl?: string;
  profileDeepLink?: string;
  isVerified: boolean;
  followerCount?: number;
  followingCount?: number;
  likesCount?: number;
  videoCount?: number;
}

export interface TikTokOAuthParams {
  scopes: string[];
  redirectUri: string;
  state?: string;
  responseType?: 'code';
}

export interface TikTokWebhookEvent {
  type: string;
  timestamp: number;
  data: any;
  signature?: string;
}

@Injectable()
export class TikTokService {
  private readonly logger = new Logger(TikTokService.name);

  // TikTok API Configuration
  private readonly clientKey = this.configService.get<string>('TIKTOK_CLIENT_KEY');
  private readonly clientSecret = this.configService.get<string>('TIKTOK_CLIENT_SECRET');
  private readonly apiVersion = this.configService.get<string>('TIKTOK_API_VERSION', 'v2');
  private readonly baseUrl = `https://business-api.tiktok.com/${this.apiVersion}`;
  private readonly authUrl = 'https://www.tiktok.com/v2/auth/authorize';
  private readonly tokenUrl = 'https://business-api.tiktok.com/open_api/v1.3/oauth2/access_token';

  // Supported scopes with descriptions
  private readonly availableScopes = {
    'user.info.basic': 'Basic user information (open_id, union_id)',
    'user.info.profile': 'User profile information (display_name, avatar_url, etc.)',
    'video.list': 'Access to user\'s video list',
    'video.upload': 'Upload videos to user\'s account',
    'business.auth': 'Business account authentication and management',
    'ad_management': 'Manage advertising campaigns',
    'reporting': 'Access to analytics and reporting data'
  };

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {
    this.validateConfiguration();
  }

  /**
   * Validate TikTok API configuration
   */
  private validateConfiguration(): void {
    if (!this.clientKey || !this.clientSecret) {
      throw new Error('TikTok API configuration missing. Please set TIKTOK_CLIENT_KEY and TIKTOK_CLIENT_SECRET');
    }
    this.logger.log(`TikTok service initialized with client key: ${this.clientKey}`);
  }

  /**
   * Generate OAuth authorization URL
   */
  generateAuthUrl(params: TikTokOAuthParams): {
    authUrl: string;
    redirectUri: string;
    scopes: string[];
    clientKey: string;
    state: string;
    codeChallenge?: string;
  } {
    // Check if required credentials are available
    if (!this.clientKey) {
      this.logger.error('TikTok client key is not configured');
      throw new BadRequestException('TikTok integration is not properly configured - missing client key');
    }

    const { scopes, redirectUri, state, responseType = 'code' } = params;

    // Validate scopes
    const invalidScopes = scopes.filter(scope => !this.availableScopes[scope]);
    if (invalidScopes.length > 0) {
      throw new BadRequestException(`Invalid TikTok scopes: ${invalidScopes.join(', ')}`);
    }

    // Generate state if not provided
    const authState = state || crypto.randomBytes(16).toString('hex');

    // Build authorization URL
    const authParams = new URLSearchParams({
      client_key: this.clientKey,
      scope: scopes.join(','),
      response_type: responseType,
      redirect_uri: redirectUri,
      state: authState,
    });

    const authUrl = `${this.authUrl}?${authParams.toString()}`;

    this.logger.log(`Generated TikTok OAuth URL for scopes: ${scopes.join(', ')}`);

    return {
      authUrl,
      redirectUri,
      scopes,
      clientKey: this.clientKey,
      state: authState,
    };
  }

  /**
   * Exchange authorization code for access token
   */
  async exchangeCodeForTokens(
    code: string,
    redirectUri: string,
    scopes: string[],
  ): Promise<{
    credentials: TikTokCredentials;
    userInfo: TikTokUserInfo;
  }> {
    this.logger.log('Exchanging TikTok authorization code for tokens');

    try {
      // Step 1: Exchange code for tokens
      const tokenResponse = await axios.post(
        this.tokenUrl,
        {
          client_key: this.clientKey,
          client_secret: this.clientSecret,
          code,
          grant_type: 'authorization_code',
          redirect_uri: redirectUri,
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      const tokenData = tokenResponse.data.data;
      
      if (!tokenData || tokenResponse.data.code !== 0) {
        throw new Error(`Token exchange failed: ${tokenResponse.data.message}`);
      }

      const {
        access_token,
        refresh_token,
        expires_in,
        refresh_expires_in,
        open_id,
        scope: grantedScopes,
      } = tokenData;

      // Calculate expiration times
      const now = Date.now();
      const expiresAt = now + (expires_in * 1000);
      const refreshExpiresAt = now + (refresh_expires_in * 1000);

      // Step 2: Get user information
      const userInfo = await this.fetchUserInfo(access_token);

      // Step 3: Create credentials object
      const credentials: TikTokCredentials = {
        accessToken: access_token,
        refreshToken: refresh_token,
        expiresAt,
        refreshExpiresAt,
        scopes: grantedScopes.split(','),
        userId: open_id,
        userInfo,
      };

      this.logger.log(`Successfully exchanged tokens for TikTok user: ${userInfo.displayName} (${open_id})`);

      return { credentials, userInfo };
    } catch (error) {
      this.logger.error('TikTok token exchange failed:', error.response?.data || error.message);
      throw new BadRequestException('Failed to exchange authorization code for tokens');
    }
  }

  /**
   * Get user information from TikTok API
   */
  private async fetchUserInfo(accessToken: string): Promise<TikTokUserInfo> {
    try {
      const response = await axios.post(
        `${this.baseUrl}/user/info/`,
        {
          access_token: accessToken,
          fields: [
            'open_id',
            'union_id', 
            'display_name',
            'username',
            'avatar_url',
            'profile_deep_link',
            'is_verified',
            'follower_count',
            'following_count',
            'likes_count',
            'video_count'
          ],
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      const userData = response.data.data.user;
      
      return {
        openId: userData.open_id,
        unionId: userData.union_id,
        displayName: userData.display_name,
        username: userData.username,
        avatarUrl: userData.avatar_url,
        profileDeepLink: userData.profile_deep_link,
        isVerified: userData.is_verified,
        followerCount: userData.follower_count,
        followingCount: userData.following_count,
        likesCount: userData.likes_count,
        videoCount: userData.video_count,
      };
    } catch (error) {
      this.logger.error('Failed to get TikTok user info:', error.response?.data || error.message);
      // Return minimal user info if detailed fetch fails
      return {
        openId: '',
        unionId: '',
        displayName: 'TikTok User',
        username: '',
        isVerified: false,
      };
    }
  }

  /**
   * Refresh access token using refresh token
   */
  async refreshAccessToken(refreshToken: string): Promise<TikTokCredentials> {
    try {
      const response = await axios.post(
        this.tokenUrl,
        {
          client_key: this.clientKey,
          client_secret: this.clientSecret,
          grant_type: 'refresh_token',
          refresh_token: refreshToken,
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      const tokenData = response.data.data;
      
      if (!tokenData || response.data.code !== 0) {
        throw new Error(`Token refresh failed: ${response.data.message}`);
      }

      const {
        access_token,
        refresh_token: newRefreshToken,
        expires_in,
        refresh_expires_in,
        open_id,
        scope,
      } = tokenData;

      const now = Date.now();
      const expiresAt = now + (expires_in * 1000);
      const refreshExpiresAt = now + (refresh_expires_in * 1000);

      const credentials: TikTokCredentials = {
        accessToken: access_token,
        refreshToken: newRefreshToken,
        expiresAt,
        refreshExpiresAt,
        scopes: scope.split(','),
        userId: open_id,
      };

      this.logger.log(`Successfully refreshed TikTok tokens for user: ${open_id}`);
      return credentials;
    } catch (error) {
      this.logger.error('TikTok token refresh failed:', error.response?.data || error.message);
      throw new BadRequestException('Failed to refresh access token');
    }
  }

  /**
   * Store credentials securely in Firestore
   */
  async storeCredentials(
    businessId: string,
    credentials: TikTokCredentials,
  ): Promise<void> {
    try {
      // Encrypt sensitive data
      const encryptedAccessToken = this.encryptData(credentials.accessToken);
      const encryptedRefreshToken = this.encryptData(credentials.refreshToken);

      // Store TikTok credentials
      await this.firestoreService.createDocument('tiktok_credentials', {
        businessId,
        userId: credentials.userId,
        accessToken: encryptedAccessToken,
        refreshToken: encryptedRefreshToken,
        expiresAt: credentials.expiresAt,
        refreshExpiresAt: credentials.refreshExpiresAt,
        scopes: credentials.scopes,
        userInfo: credentials.userInfo,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      // Store integration record
      await this.firestoreService.createDocument('integrations', {
        businessId,
        platformId: 'tiktok',
        platformName: 'TikTok',
        channel: 'tiktok_business',
        accountInfo: {
          openId: credentials.userId,
          displayName: credentials.userInfo?.displayName,
          username: credentials.userInfo?.username,
          isVerified: credentials.userInfo?.isVerified,
          followerCount: credentials.userInfo?.followerCount,
        },
        status: 'active',
        connectedAt: new Date(),
        lastSyncAt: new Date(),
      });

      this.logger.log(`Stored TikTok credentials for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to store TikTok credentials:', error);
      throw error;
    }
  }

  /**
   * Get stored credentials for a business
   */
  async getCredentials(businessId: string): Promise<TikTokCredentials | null> {
    try {
      const docs = await this.firestoreService.getDocuments('tiktok_credentials', [
        { field: 'businessId', operator: '==', value: businessId }
      ]);
      if (docs.length === 0) return null;

      const credentialDoc = docs[0];
      
      // Decrypt sensitive data
      const decryptedAccessToken = this.decryptData(credentialDoc.accessToken);
      const decryptedRefreshToken = this.decryptData(credentialDoc.refreshToken);

      return {
        accessToken: decryptedAccessToken,
        refreshToken: decryptedRefreshToken,
        expiresAt: credentialDoc.expiresAt,
        refreshExpiresAt: credentialDoc.refreshExpiresAt,
        scopes: credentialDoc.scopes,
        userId: credentialDoc.userId,
        userInfo: credentialDoc.userInfo,
      };
    } catch (error) {
      this.logger.error('Failed to get TikTok credentials:', error);
      return null;
    }
  }

  /**
   * Verify webhook signature using TikTok's verification method
   */
  verifyWebhookSignature(payload: string, signature: string, timestamp: string): boolean {
    try {
      const webhookSecret = this.configService.get('TIKTOK_WEBHOOK_SECRET');
      if (!webhookSecret) {
        this.logger.warn('TikTok webhook secret not configured');
        return false;
      }

      // TikTok webhook signature verification
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(timestamp + payload)
        .digest('hex');

      return crypto.timingSafeEqual(
        Buffer.from(signature, 'hex'),
        Buffer.from(expectedSignature, 'hex')
      );
    } catch (error) {
      this.logger.error('TikTok webhook signature verification failed:', error);
      return false;
    }
  }

  /**
   * Process TikTok webhook events
   */
  async processWebhookEvent(event: TikTokWebhookEvent): Promise<void> {
    this.logger.log(`Processing TikTok webhook event: ${event.type}`);

    try {
      switch (event.type) {
        case 'video_publish':
          await this.handleVideoPublish(event.data);
          break;
        case 'video_delete':
          await this.handleVideoDelete(event.data);
          break;
        case 'comment_create':
          await this.handleCommentCreate(event.data);
          break;
        case 'user_follow':
          await this.handleUserFollow(event.data);
          break;
        case 'user_unfollow':
          await this.handleUserUnfollow(event.data);
          break;
        default:
          this.logger.warn(`Unknown TikTok webhook event type: ${event.type}`);
      }
    } catch (error) {
      this.logger.error(`Failed to process TikTok webhook event ${event.type}:`, error);
      throw error;
    }
  }

  /**
   * Handle video publish webhook event
   */
  private async handleVideoPublish(data: any): Promise<void> {
    this.logger.log(`Video published: ${data.video_id}`);
    // Implement video publish handling logic
  }

  /**
   * Handle video delete webhook event
   */
  private async handleVideoDelete(data: any): Promise<void> {
    this.logger.log(`Video deleted: ${data.video_id}`);
    // Implement video delete handling logic
  }

  /**
   * Handle comment create webhook event
   */
  private async handleCommentCreate(data: any): Promise<void> {
    this.logger.log(`Comment created on video: ${data.video_id}`);
    // Implement comment handling logic
  }

  /**
   * Handle user follow webhook event
   */
  private async handleUserFollow(data: any): Promise<void> {
    this.logger.log(`New follower: ${data.follower_id}`);
    // Implement follower handling logic
  }

  /**
   * Handle user unfollow webhook event
   */
  private async handleUserUnfollow(data: any): Promise<void> {
    this.logger.log(`User unfollowed: ${data.follower_id}`);
    // Implement unfollow handling logic
  }

  /**
   * Get available scopes with descriptions
   */
  getAvailableScopes(): Record<string, string> {
    return this.availableScopes;
  }

  /**
   * Encrypt sensitive data
   */
  private encryptData(data: string): string {
    const cipher = crypto.createCipher('aes-256-cbc', this.clientSecret);
    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return encrypted;
  }

  /**
   * Decrypt sensitive data
   */
  private decryptData(encryptedData: string): string {
    const decipher = crypto.createDecipher('aes-256-cbc', this.clientSecret);
    let decrypted = decipher.update(encryptedData, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }

  /**
   * Store integration error when OAuth fails
   */
  async storeIntegrationError(businessId: string, platform: string, errorMessage: string): Promise<void> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const now = new Date().toISOString();
      
      const integrationData: any = {
        businessId: businessId,
        platformId: platform,
        platformName: platform === 'tiktok' ? 'TikTok' : platform,
        platformIcon: `assets/icons/${platform}.png`,
        status: 'incomplete',
        errorMessage: errorMessage,
        updatedAt: now,
        createdAt: now,
        settings: {
          autoSync: false,
          syncInterval: 60,
          syncInventory: false,
          syncOrders: false,
          syncProducts: true,
        }
      };

      const docRef = await integrationsCollection.add(integrationData);
      await docRef.update({ id: docRef.id });
      
      this.logger.log(`Integration error stored for ${platform} - Business: ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to store integration error:', error);
    }
  }

  /**
   * Get stored user profile for a business
   */
  async getStoredUserProfile(businessId: string): Promise<any> {
    try {
      const integration = await this.getIntegrationForBusiness(businessId);
      if (!integration || !integration.credentials) {
        throw new Error('No TikTok integration found for this business');
      }

      const { access_token } = integration.credentials;
      if (!access_token) {
        throw new Error('No valid access token found');
      }

      // Get user info from TikTok API
      const userInfo = await this.fetchUserInfo(access_token);
      return userInfo;
    } catch (error) {
      this.logger.error('Failed to get stored user profile:', error);
      throw error;
    }
  }

  /**
   * Get user info with statistics
   */
  async getUserInfo(businessId: string): Promise<any> {
    const integration = await this.getIntegrationForBusiness(businessId);
    if (!integration || !integration.credentials) {
      throw new Error('No TikTok integration found for this business');
    }

    const { access_token } = integration.credentials;
    return await this.fetchUserInfo(access_token);
  }

  /**
   * Get integration for a business
   */
  async getIntegrationForBusiness(businessId: string): Promise<any> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const integrationQuery = await integrationsCollection
        .where('businessId', '==', businessId)
        .where('platformId', '==', 'tiktok')
        .where('status', '==', 'active')
        .limit(1)
        .get();
      
      if (integrationQuery.empty) {
        return null;
      }

      const integrationDoc = integrationQuery.docs[0];
      return {
        id: integrationDoc.id,
        ...integrationDoc.data(),
      };
    } catch (error) {
      this.logger.error('Failed to get integration for business:', error);
      throw error;
    }
  }

  /**
   * Update integration settings
   */
  async updateIntegrationSettings(businessId: string, settings: any): Promise<void> {
    try {
      const integration = await this.getIntegrationForBusiness(businessId);
      if (!integration) {
        throw new Error('No TikTok integration found for this business');
      }

      await this.firestoreService.collection('integrations').doc(integration.id).update({
        settings: {
          ...integration.settings,
          ...settings,
        },
        updatedAt: new Date().toISOString(),
      });
    } catch (error) {
      this.logger.error('Failed to update integration settings:', error);
      throw error;
    }
  }

  /**
   * Sync user data
   */
  async syncUserData(businessId: string): Promise<void> {
    try {
      const integration = await this.getIntegrationForBusiness(businessId);
      if (!integration) {
        throw new Error('No TikTok integration found for this business');
      }

      const { access_token } = integration.credentials;
      
      // Fetch latest user info
      const userInfo = await this.fetchUserInfo(access_token);
      
      // Update last sync time
      await this.firestoreService.collection('integrations').doc(integration.id).update({
        userInfo,
        lastSyncAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      this.logger.log(`Data sync completed for business: ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to sync user data:', error);
      throw error;
    }
  }

  /**
   * Disconnect integration
   */
  async disconnectIntegration(businessId: string): Promise<void> {
    try {
      const integration = await this.getIntegrationForBusiness(businessId);
      if (!integration) {
        throw new Error('No TikTok integration found for this business');
      }

      // Update integration status to disconnected
      await this.firestoreService.collection('integrations').doc(integration.id).update({
        status: 'disconnected',
        disconnectedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      this.logger.log(`TikTok integration disconnected for business: ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to disconnect integration:', error);
      throw error;
    }
  }

  /**
   * Get integration logs
   */
  async getIntegrationLogs(businessId: string, limit: number = 50): Promise<any[]> {
    try {
      const logsCollection = this.firestoreService.collection('tiktok_integration_logs');
      const logsQuery = await logsCollection
        .where('businessId', '==', businessId)
        .orderBy('timestamp', 'desc')
        .limit(limit)
        .get();

      return logsQuery.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));
    } catch (error) {
      this.logger.error('Failed to get integration logs:', error);
      return [];
    }
  }

  /**
   * Trigger authorization completion notification
   */
  async triggerAuthorizationComplete(businessId: string, authData: any): Promise<void> {
    try {
      await this.firestoreService.collection('tiktok_auth_notifications').add({
        businessId,
        ...authData,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      this.logger.error('Failed to trigger authorization complete notification:', error);
    }
  }
}