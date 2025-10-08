import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { FirestoreService } from '../../firestore/firestore.service';
import axios from 'axios';
import * as crypto from 'crypto';
import { ConfigService } from '@nestjs/config';

/**
 * TikTok Integ    try {
      /    try {
      // Step 1: Exchange code for tokens
      // Using TikTok OAuth v2 API (https://open.tiktokapis.com/v2/oauth/token/)
      const tokenRequestBody: any = {
        client_key: this.clientKey,
        client_secret: this.clientSecret,
        code: code,
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
      }; Exchange code for tokens
      // Using TikTok OAuth v2 API (https://open.tiktokapis.com/v2/oauth/token/)
       async refreshAccessToken(refreshToken: string): Promise<TikTokCredentials> {
    try {
      const response = await axios.post(
        this.tokenUrl,
        {
          client_key: this.clientKey,
          client_secret: this.clientSecret,
          grant_type: 'refresh_token',
          refresh_token: refreshToken,
        },enRequestBody: any = {
        client_key: this.clientKey,
        client_secret: this.clientSecret,
        code: code,
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
      };rvice
 * 
 * Comprehensive service for TikTok Business API integration following TikTok best practices.
 * 
 * Fe    try {
      const response = await axios.post(
        this.tokenUrl,
        {
          app_id: this.appId || this.clientKey,
          secret: this.clientSecret,
          grant_type: 'refresh_token',
          refresh_token: refreshToken,
        }, * - OAuth 2.0 authentication with TikTok Login Kit
 * - Secure token management and refresh
 * - Business account management
 * - Webhook event handling
 * - Content management through Creator API
 * 
 * Supported Scopes:
 * - user.info.basic: Basic user information (open_id, union_id)
 * - user.info.profile: User profile information (display_name, avatar_url, etc.)
 * - user.info.stats: User statistics (follower_count, following_count, likes_count, video_count)
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
  private readonly appId = this.configService.get<string>('TIKTOK_APP_ID');
  private readonly apiVersion = this.configService.get<string>('TIKTOK_API_VERSION', 'v2');
  private readonly baseUrl = `https://business-api.tiktok.com/${this.apiVersion}`;
  private readonly authUrl = 'https://www.tiktok.com/v2/auth/authorize';
  private readonly tokenUrl = 'https://open.tiktokapis.com/v2/oauth/token/';

  // Supported scopes with descriptions
  private readonly availableScopes = {
    'user.info.basic': 'Basic user information (open_id, union_id)',
    'user.info.profile': 'User profile information (display_name, avatar_url, etc.)',
    'user.info.stats': 'User statistics (follower_count, following_count, likes_count, video_count)',
    'video.list': 'Access to user\'s video list',
    'video.upload': 'Upload videos to user\'s account',
    'business.auth': 'Business account authentication and management',
    'ad_management': 'Manage advertising campaigns',
    'reporting': 'Access to analytics and reporting data'
  };

  // Field mappings based on scopes
  private readonly scopeFieldMappings = {
    'user.info.basic': ['open_id', 'union_id'],
    'user.info.profile': ['display_name', 'avatar_url', 'username', 'profile_deep_link', 'is_verified'],
    'user.info.stats': ['follower_count', 'following_count', 'likes_count', 'video_count'],
    'video.list': [], // Enables access to user's video list via separate API endpoints
    'video.upload': [] // Enables video upload capabilities via separate API endpoints
  };

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {
    this.validateConfiguration();
  }

  /**
   * Get available fields based on granted scopes
   */
  private getAvailableFields(grantedScopes: string[]): string[] {
    const availableFields: string[] = [];
    
    grantedScopes.forEach(scope => {
      if (this.scopeFieldMappings[scope]) {
        availableFields.push(...this.scopeFieldMappings[scope]);
      }
    });
    
    // Remove duplicates and ensure we always have basic fields
    const uniqueFields = [...new Set(availableFields)];
    
    // Always include basic fields if we have user.info.basic scope
    if (grantedScopes.includes('user.info.basic') && !uniqueFields.includes('open_id')) {
      uniqueFields.unshift('open_id', 'union_id');
    }
    
    this.logger.log(`Available fields for scopes [${grantedScopes.join(', ')}]: ${uniqueFields.join(', ')}`);
    return uniqueFields;
  }

  /**
   * Validate TikTok API configuration
   */
  private validateConfiguration(): void {
    if (!this.clientKey || !this.clientSecret) {
      throw new Error('TikTok API configuration missing. Please set TIKTOK_CLIENT_KEY and TIKTOK_CLIENT_SECRET');
    }
    this.logger.log(`TikTok service initialized with client key: ${this.clientKey}`);
    
    if (this.appId) {
      this.logger.log(`TikTok App ID configured: ${this.appId}`);
    } else {
      this.logger.warn('TIKTOK_APP_ID not configured - using client_key for token exchange');
    }
  }

  /**
   * Generate OAuth authorization URL with PKCE support
   */
  generateAuthUrl(params: TikTokOAuthParams): {
    authUrl: string;
    redirectUri: string;
    scopes: string[];
    clientKey: string;
    state: string;
    codeVerifier: string;
    codeChallenge: string;
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

    // Generate PKCE parameters (required for mobile flows)
    const codeVerifier = this.generateCodeVerifier();
    const codeChallenge = this.generateCodeChallenge(codeVerifier);

    // Build authorization URL with PKCE and web-only parameters to prevent deep link redirects
    const authParams = new URLSearchParams({
      client_key: this.clientKey,
      scope: scopes.join(','),
      response_type: responseType,
      redirect_uri: redirectUri,
      state: authState,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
      // Force web-only flow to prevent deep link redirects
      disable_redirect_fallback: '1',
      web_view: '1',
      // Add platform hint to force web behavior
      platform: 'web'
     // device_platform: 'web',
    });

    const authUrl = `${this.authUrl}?${authParams.toString()}`;

    this.logger.log(`Generated TikTok OAuth URL with PKCE for scopes: ${scopes.join(', ')}`);
    this.logger.log(`Code challenge: ${codeChallenge}`);

    return {
      authUrl,
      redirectUri,
      scopes,
      clientKey: this.clientKey,
      state: authState,
      codeVerifier,
      codeChallenge,
    };
  }

  /**
   * Generate PKCE code verifier (RFC 7636)
   * A cryptographically random string using the characters [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"
   * with a minimum length of 43 characters and a maximum length of 128 characters.
   */
  private generateCodeVerifier(): string {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Buffer.from(array)
      .toString('base64url'); // base64url encoding (no padding, URL-safe)
  }

  /**
   * Generate PKCE code challenge (RFC 7636)
   * BASE64URL(SHA256(code_verifier))
   */
  private generateCodeChallenge(codeVerifier: string): string {
    const hash = crypto.createHash('sha256').update(codeVerifier).digest();
    return Buffer.from(hash).toString('base64url');
  }

  /**
   * Store PKCE code verifier in Firestore temporarily
   */
  async storePKCEVerifier(state: string, codeVerifier: string): Promise<void> {
    try {
      await this.firestoreService.createDocument(
        'tiktok_pkce_verifiers',
        {
          codeVerifier,
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 minutes expiry
        },
        state  // Pass state as the document ID
      );
      this.logger.log(`Stored PKCE verifier for state: ${state}`);
    } catch (error) {
      this.logger.error('Failed to store PKCE verifier:', error);
      throw new BadRequestException('Failed to store PKCE verifier');
    }
  }

  /**
   * Retrieve and delete PKCE code verifier from Firestore
   */
  async retrieveAndDeletePKCEVerifier(state: string): Promise<string> {
    try {
      this.logger.log(`Attempting to retrieve PKCE verifier for state: ${state}`);
      const doc = await this.firestoreService.getDocument('tiktok_pkce_verifiers', state);
      
      this.logger.log(`Retrieved document:`, doc);
      
      if (!doc || !(doc as any).codeVerifier) {
        this.logger.error(`PKCE verifier not found for state: ${state}`);
        throw new BadRequestException('PKCE verifier not found or expired');
      }

      // Check if expired - handle Firestore timestamp format
      let expiresAt: Date;
      const expiresAtData = (doc as any).expiresAt;
      
      if (expiresAtData && expiresAtData._seconds) {
        // Firestore timestamp format
        expiresAt = new Date(expiresAtData._seconds * 1000 + (expiresAtData._nanoseconds || 0) / 1000000);
      } else if (expiresAtData instanceof Date) {
        // Regular Date object
        expiresAt = expiresAtData;
      } else {
        // Fallback to current time to allow processing
        expiresAt = new Date();
      }
      
      this.logger.log(`Verifier expires at: ${expiresAt}, current time: ${new Date()}`);
      
      if (expiresAt && expiresAt < new Date()) {
        // Clean up expired verifier
        await this.firestoreService.deleteDocument('tiktok_pkce_verifiers', state);
        this.logger.error(`PKCE verifier expired for state: ${state}`);
        throw new BadRequestException('PKCE verifier has expired');
      }

      // Delete the verifier after retrieval (one-time use)
      await this.firestoreService.deleteDocument('tiktok_pkce_verifiers', state);
      
      this.logger.log(`Retrieved and deleted PKCE verifier for state: ${state}`);
      return (doc as any).codeVerifier;
    } catch (error) {
      this.logger.error('Failed to retrieve PKCE verifier:', error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to retrieve PKCE verifier');
    }
  }

  /**
   * Exchange authorization code for access token with PKCE
   */
  async exchangeCodeForTokens(
    code: string,
    redirectUri: string,
    codeVerifier: string,
    scopes: string[],
  ): Promise<{
    credentials: TikTokCredentials;
    userInfo: TikTokUserInfo;
  }> {
    this.logger.log('Exchanging TikTok authorization code for tokens with PKCE');
    this.logger.log(`Using code verifier: ${codeVerifier}`);
    this.logger.log(`Requested scopes: ${scopes.join(', ')}`);
    this.logger.log(`Redirect URI: ${redirectUri}`);
    this.logger.log(`Client Key: ${this.clientKey}`);

    try {
      // Step 1: Exchange code for tokens
      // Based on TikTok OAuth v2 documentation
      const tokenRequestParams = new URLSearchParams();
      tokenRequestParams.append('client_key', this.clientKey);
      tokenRequestParams.append('client_secret', this.clientSecret);
      tokenRequestParams.append('code', code);
      tokenRequestParams.append('grant_type', 'authorization_code');
      tokenRequestParams.append('redirect_uri', redirectUri);

      // Only add code_verifier if provided (for PKCE flows)
      if (codeVerifier && codeVerifier.trim()) {
        tokenRequestParams.append('code_verifier', codeVerifier);
        this.logger.log('Using PKCE flow with code verifier');
      } else {
        this.logger.log('Using OAuth flow without PKCE');
      }

      this.logger.log('TikTok token exchange request body:', tokenRequestParams.toString());

      const tokenResponse = await axios.post(
        this.tokenUrl,
        tokenRequestParams,
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      this.logger.log('TikTok token exchange raw response:', JSON.stringify(tokenResponse.data, null, 2));

      // OAuth v2 response format - data is at root level, not nested in .data
      const tokenData = tokenResponse.data;
      
      if (!tokenData.access_token) {
        const errorMsg = tokenData.error_description || tokenData.error || 'Unknown error';
        throw new Error(`Token exchange failed: ${errorMsg}`);
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
      const userInfo = await this.fetchUserInfo(access_token, grantedScopes.split(','));

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
      this.logger.error('TikTok token exchange failed:');
      this.logger.error('Error message:', error.message);
      this.logger.error('Raw TikTok response:', JSON.stringify(error.response?.data, null, 2));
      this.logger.error('Response status:', error.response?.status);
      this.logger.error('Response headers:', JSON.stringify(error.response?.headers, null, 2));
      
      const errorMsg = error.response?.data?.error_description || error.response?.data?.error || error.message;
      throw new BadRequestException(`Failed to exchange authorization code for tokens: ${errorMsg}`);
    }
  }

  /**
   * Get user information from TikTok Display API
   */
  private async fetchUserInfo(accessToken: string, grantedScopes?: string[]): Promise<TikTokUserInfo> {
    try {
      // Determine available fields based on granted scopes
      const defaultScopes = ['user.info.basic']; // Fallback to basic scope
      const scopes = grantedScopes && grantedScopes.length > 0 ? grantedScopes : defaultScopes;
      const availableFields = this.getAvailableFields(scopes);
      
      const response = await axios.get(
        'https://open.tiktokapis.com/v2/user/info/',
        {
          params: {
            // Request fields based on available scopes
            fields: availableFields.join(',')
          },
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log('TikTok user info response:', JSON.stringify(response.data, null, 2));

      // TikTok Display API response format
      const userData = response.data?.data?.user;
      if (!userData || !userData.open_id) {
        throw new Error('Invalid user data received from TikTok');
      }
      
      // Filter out undefined values to avoid Firestore errors
      const userInfo: any = {
        openId: userData.open_id,
        unionId: userData.union_id || '',
        displayName: userData.display_name || '',
        username: userData.username || '',
        isVerified: userData.is_verified || false,
      };

      // Only add optional fields if they are defined
      if (userData.avatar_url !== undefined) {
        userInfo.avatarUrl = userData.avatar_url;
      }
      if (userData.profile_deep_link !== undefined) {
        userInfo.profileDeepLink = userData.profile_deep_link;
      }
      if (userData.follower_count !== undefined) {
        userInfo.followerCount = userData.follower_count;
      }
      if (userData.following_count !== undefined) {
        userInfo.followingCount = userData.following_count;
      }
      if (userData.likes_count !== undefined) {
        userInfo.likesCount = userData.likes_count;
      }
      if (userData.video_count !== undefined) {
        userInfo.videoCount = userData.video_count;
      }

      return userInfo as TikTokUserInfo;
    } catch (error) {
      this.logger.error('Failed to get TikTok user info:');
      this.logger.error('Error message:', error.message);
      this.logger.error('Response data:', JSON.stringify(error.response?.data, null, 2));
      this.logger.error('Response status:', error.response?.status);
      
      // On 401 (unauthorized), throw error instead of fallback
      if (error.response?.status === 401) {
        this.logger.error('TikTok user info request failed with 401 - unauthorized access token or insufficient scopes');
        throw new BadRequestException('Failed to fetch user information: unauthorized access token or insufficient scopes');
      }
      
      // For other errors, return minimal user info to allow OAuth flow to complete
      this.logger.warn('TikTok user info request failed, returning minimal user data');
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
      const refreshRequestParams = new URLSearchParams();
      refreshRequestParams.append('client_key', this.clientKey);
      refreshRequestParams.append('client_secret', this.clientSecret);
      refreshRequestParams.append('grant_type', 'refresh_token');
      refreshRequestParams.append('refresh_token', refreshToken);

      const response = await axios.post(
        this.tokenUrl,
        refreshRequestParams,
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      this.logger.log('TikTok refresh token response:', JSON.stringify(response.data, null, 2));

      // OAuth v2 response format - data is at root level
      const tokenData = response.data;
      
      if (!tokenData.access_token) {
        const errorMsg = tokenData.error_description || tokenData.error || 'Unknown error';
        throw new Error(`Token refresh failed: ${errorMsg}`);
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
      this.logger.error('TikTok token refresh failed:');
      this.logger.error('Error message:', error.message);
      this.logger.error('Raw TikTok response:', JSON.stringify(error.response?.data, null, 2));
      this.logger.error('Response status:', error.response?.status);
      
      throw new BadRequestException('Failed to refresh access token');
    }
  }

  /**
   * Store credentials securely in Firestore as integration document (matching Meta structure)
   */
  async storeCredentials(
    businessId: string,
    credentials: TikTokCredentials,
  ): Promise<{ id: string }> {
    try {
      // Prepare account info with structure matching Meta integrations exactly
      const accountInfo: any = {
        openId: credentials.userInfo?.openId || '',
        displayName: credentials.userInfo?.displayName || '',
        username: credentials.userInfo?.username || '',
        isVerified: credentials.userInfo?.isVerified || false,
        avatarUrl: credentials.userInfo?.avatarUrl || '',
        profileDeepLink: credentials.userInfo?.profileDeepLink || '',
        followerCount: credentials.userInfo?.followerCount || 0,
        followingCount: credentials.userInfo?.followingCount || 0,
        likesCount: credentials.userInfo?.likesCount || 0,
        videoCount: credentials.userInfo?.videoCount || 0,
      };

      // Prepare credentials object
      const integrationCredentials = {
        access_token: credentials.accessToken,
        refresh_token: credentials.refreshToken,
        user_id: credentials.userId,
        scopes: credentials.scopes,
        expires_at: credentials.expiresAt,
        refresh_expires_at: credentials.refreshExpiresAt,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      // Check if TikTok integration already exists (search by specific user's openId)
      const existingDocs = await this.firestoreService.getDocuments('integrations', [
        { field: 'businessId', operator: '==', value: businessId },
        { field: 'channel', operator: '==', value: 'tiktok_business' },
        { field: 'platformId', operator: '==', value: credentials.userInfo?.openId || credentials.userId }
      ]);

      let integrationId: string;
      
      if (existingDocs.length > 0) {
        // Update existing TikTok integration with new credentials
        integrationId = existingDocs[0].id;
        const existingIntegration = existingDocs[0];
        
        this.logger.log(`Updating existing TikTok integration ${integrationId} for business ${businessId}`);
        
        await this.firestoreService.updateDocument('integrations', integrationId, {
          platformName: 'TikTok',
          platformIcon: this.getPlatformIcon('tiktok_business'),
          accountInfo,
          credentials: integrationCredentials,
          status: 'active',
          // Preserve existing settings, only set defaults if none exist
          settings: existingIntegration.settings || this.getDefaultTikTokSettings(),
          lastSyncAt: new Date(),
          updatedAt: new Date(),
        });
        
        this.logger.log(`Updated existing TikTok integration ${integrationId} for business ${businessId} with new credentials`);
      } else {
        // Create new TikTok integration with structure matching Meta integrations exactly
        this.logger.log(`Creating new TikTok integration for business ${businessId}`);
        
        const integrationDoc = await this.firestoreService.createDocument('integrations', {
          businessId,
          platformId: credentials.userInfo?.openId || credentials.userId, // Use TikTok user's openId like Meta uses pageId/instagramId
          platformName: 'TikTok',
          platformIcon: this.getPlatformIcon('tiktok_business'),
          channel: 'tiktok_business',
          accountInfo,
          credentials: integrationCredentials,
          status: 'active',
          settings: this.getDefaultTikTokSettings(),
          connectedAt: new Date(),
          lastSyncAt: new Date(),
          createdAt: new Date(),
          updatedAt: new Date(),
        });
        
        integrationId = integrationDoc.id;
        this.logger.log(`Created new TikTok integration ${integrationId} for business ${businessId}`);
      }

      this.logger.log(`TikTok integration stored successfully for business ${businessId} with ID ${integrationId}`);
      return { id: integrationId };
    } catch (error) {
      this.logger.error('Failed to store TikTok integration:', error);
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
      const integrationErrorsCollection = this.firestoreService.collection('integration_errors');
      const now = new Date().toISOString();
      
      const errorData: any = {
        businessId: businessId,
        platformId: platform,
        platformName: platform === 'tiktok' ? 'TikTok' : platform,
        errorMessage: errorMessage,
        errorType: 'oauth_failed',
        timestamp: now,
        createdAt: now,
        resolved: false,
        retryCount: 0,
      };

      const docRef = await integrationErrorsCollection.add(errorData);
      await docRef.update({ id: docRef.id });
      
      this.logger.log(`OAuth error stored in integration_errors for ${platform} - Business: ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to store integration error:', error);
    }
  }

  /**
   * Retrieve integration errors for a business
   */
  async getIntegrationErrors(businessId: string, platformId?: string): Promise<any[]> {
    try {
      const integrationErrorsCollection = this.firestoreService.collection('integration_errors');
      const filters = [
        { field: 'businessId', operator: '==', value: businessId },
        { field: 'resolved', operator: '==', value: false }
      ];

      if (platformId) {
        filters.push({ field: 'platformId', operator: '==', value: platformId });
      }

      const errors = await this.firestoreService.getDocuments('integration_errors', filters);
      
      this.logger.log(`Retrieved ${errors.length} integration errors for business ${businessId}`);
      return errors;
    } catch (error) {
      this.logger.error('Failed to retrieve integration errors:', error);
      return [];
    }
  }

  /**
   * Mark an integration error as resolved
   */
  async markErrorAsResolved(errorId: string): Promise<void> {
    try {
      await this.firestoreService.updateDocument('integration_errors', errorId, {
        resolved: true,
        resolvedAt: new Date().toISOString(),
      });
      
      this.logger.log(`Marked integration error ${errorId} as resolved`);
    } catch (error) {
      this.logger.error('Failed to mark error as resolved:', error);
    }
  }

  /**
   * Cleanup method to migrate existing incomplete integrations to integration_errors collection
   */
  async cleanupIncompleteIntegrations(): Promise<void> {
    try {
      this.logger.log('Starting cleanup of incomplete integrations...');
      
      // Find all incomplete integrations
      const incompleteIntegrations = await this.firestoreService.getDocuments('integrations', [
        { field: 'status', operator: '==', value: 'incomplete' }
      ]);

      this.logger.log(`Found ${incompleteIntegrations.length} incomplete integrations to migrate`);

      for (const integration of incompleteIntegrations) {
        try {
          // Create error record in integration_errors collection
          const errorData = {
            businessId: integration.businessId,
            platformId: integration.platformId || 'unknown',
            platformName: integration.platformName || 'Unknown',
            errorMessage: integration.errorMessage || 'Unknown error during OAuth process',
            errorType: 'oauth_failed',
            timestamp: integration.createdAt || new Date().toISOString(),
            createdAt: integration.createdAt || new Date().toISOString(),
            resolved: false,
            retryCount: 0,
            migratedFrom: integration.id, // Keep reference to original
          };

          const integrationErrorsCollection = this.firestoreService.collection('integration_errors');
          const docRef = await integrationErrorsCollection.add(errorData);
          await docRef.update({ id: docRef.id });

          // Delete the incomplete integration
          await this.firestoreService.deleteDocument('integrations', integration.id);

          this.logger.log(`Migrated incomplete integration ${integration.id} to integration_errors`);
        } catch (error) {
          this.logger.error(`Failed to migrate integration ${integration.id}:`, error);
        }
      }

      this.logger.log('Cleanup completed');
    } catch (error) {
      this.logger.error('Failed to cleanup incomplete integrations:', error);
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
        .where('channel', '==', 'tiktok_business')
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
   * Find business integration from platform ID
   * Uses the same Firestore collection structure as Meta integration
   */
  async findBusinessIntegrationFromPlatformId(platformId: string, platform: string = 'tiktok'): Promise<{ businessId: string; integrationId: string } | null> {
    try {
      // Query the integrations collection (same as Meta uses)
      const integrationsCollection = this.firestoreService.collection('integrations');
      const query = await integrationsCollection
        .where('platformId', '==', platformId)
        .where('platform', '==', platform)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      if (query.empty) {
        this.logger.warn(`No active integration found for TikTok platform ID: ${platformId}`);
        return null;
      }

      const integrationDoc = query.docs[0];
      const integrationData = integrationDoc.data();

      return {
        businessId: integrationData.businessId,
        integrationId: integrationDoc.id,
      };
    } catch (error) {
      this.logger.error('Failed to find business integration from platform ID:', error);
      return null;
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

  /**
   * Filter undefined values from an object to prevent Firestore errors
   */
  private filterUndefinedValues(obj: any): any {
    if (!obj || typeof obj !== 'object') {
      return obj;
    }

    const filtered: any = {};
    for (const [key, value] of Object.entries(obj)) {
      if (value !== undefined) {
        filtered[key] = value;
      }
    }
    return filtered;
  }

  /**
   * Get default settings for TikTok integration to match Meta integration structure
   */
  private getDefaultTikTokSettings(): Record<string, any> {
    return {
      autoSync: true,
      syncInterval: 3600, // 1 hour in seconds
      syncInventory: false,
      syncOrders: false,
      syncProducts: false,
      syncReviews: false,
      syncRatings: false,
      autoRespondReviews: false,
      notifyNewReviews: true,
      syncCustomerFeedback: false,
    };
  }

  /**
   * Get platform icon path for TikTok integration to match Meta integration structure
   */
  private getPlatformIcon(channel: string): string {
    const iconMap: Record<string, string> = {
      'tiktok_business': 'assets/icons/tiktok.png',
      'tiktok': 'assets/icons/tiktok.png',
    };
    return iconMap[channel] || 'assets/icons/tiktok.png';
  }
}