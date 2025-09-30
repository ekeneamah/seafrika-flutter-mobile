import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../../firestore/firestore.service';
import { v4 as uuidv4 } from 'uuid';
import * as https from 'https';
import * as querystring from 'querystring';
import * as crypto from 'crypto';

/**
 * YouTube Auth URL Response Interface
 */
export interface YouTubeAuthUrlResponse {
  authUrl: string;
  state: string;
  codeVerifier: string;
  codeChallenge: string;
}

/**
 * YouTube User Info Interface
 */
export interface YouTubeUserInfo {
  channelId: string;
  title: string;
  description: string;
  customUrl?: string;
  publishedAt: string;
  thumbnails: {
    default?: { url: string; width: number; height: number };
    medium?: { url: string; width: number; height: number };
    high?: { url: string; width: number; height: number };
  };
  country?: string;
  viewCount: number;
  subscriberCount: number;
  videoCount: number;
  hiddenSubscriberCount: boolean;
}

/**
 * YouTube Credentials Interface
 */
export interface YouTubeCredentials {
  accessToken: string;
  refreshToken?: string;
  expiresAt: Date;
  tokenType: string;
  scopes: string[];
  userInfo?: YouTubeUserInfo;
}

/**
 * YouTube Service
 * Handles OAuth 2.0 authentication and API interactions for YouTube Data API v3
 */
@Injectable()
export class YouTubeService {
  private readonly logger = new Logger(YouTubeService.name);
  private readonly clientId: string;
  private readonly clientSecret: string;
  private readonly redirectUri: string;
  
  // YouTube API scopes base URL for consistency
  private readonly YOUTUBE_SCOPE_BASE_URL = 'https://www.googleapis.com/auth';

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {
    this.clientId = this.configService.get<string>('YOUTUBE_CLIENT_ID');
    this.clientSecret = this.configService.get<string>('YOUTUBE_CLIENT_SECRET');
    this.redirectUri = this.configService.get<string>('YOUTUBE_REDIRECT_URI');

    if (!this.clientId || !this.clientSecret || !this.redirectUri) {
      this.logger.error('YouTube OAuth configuration missing. Please set YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, and YOUTUBE_REDIRECT_URI environment variables.');
    }
  }

  /**
   * Get YouTube OAuth 2.0 authorization URL with PKCE
   */
  getAuthorizationUrl(businessId?: string): YouTubeAuthUrlResponse {
    if (!this.clientId || !this.redirectUri) {
      throw new HttpException('YouTube OAuth not properly configured', HttpStatus.INTERNAL_SERVER_ERROR);
    }

    const scopes = [
      `${this.YOUTUBE_SCOPE_BASE_URL}/youtube.readonly`,
      `${this.YOUTUBE_SCOPE_BASE_URL}/youtube.upload`,
      `${this.YOUTUBE_SCOPE_BASE_URL}/youtube.force-ssl`,
      `${this.YOUTUBE_SCOPE_BASE_URL}/userinfo.email`,
      `${this.YOUTUBE_SCOPE_BASE_URL}/userinfo.profile`,
      `openid`
    ];

    // Generate state with business ID encoded like TikTok pattern
    const authState = businessId ? `mobile_${businessId}_${Date.now()}` : uuidv4();

    // Generate PKCE parameters for enhanced security
    const codeVerifier = this.generateCodeVerifier();
    const codeChallenge = this.generateCodeChallenge(codeVerifier);

    const params = {
      client_id: this.clientId,
      redirect_uri: this.redirectUri,
      response_type: 'code',
      scope: scopes.join(' '),
      access_type: 'offline',
      include_granted_scopes: 'true',
      state: authState,
      prompt: 'consent select_account',
      code_challenge: codeChallenge,
      code_challenge_method: 'S256'
    };

    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?${querystring.stringify(params)}`;
    this.logger.log(`Generated YouTube OAuth URL with PKCE: ${authUrl}`);
    
    return {
      authUrl,
      state: authState,
      codeVerifier,
      codeChallenge
    };
  }

  /**
   * Exchange authorization code for access tokens with PKCE support
   */
  async exchangeCodeForTokens(code: string, codeVerifier?: string): Promise<YouTubeCredentials> {
    if (!this.clientId || !this.clientSecret || !this.redirectUri) {
      throw new HttpException('YouTube OAuth not properly configured', HttpStatus.INTERNAL_SERVER_ERROR);
    }

    const tokenParams: any = {
      client_id: this.clientId,
      client_secret: this.clientSecret,
      code: code,
      grant_type: 'authorization_code',
      redirect_uri: this.redirectUri,
    };

    // Add PKCE code verifier if provided
    if (codeVerifier) {
      tokenParams.code_verifier = codeVerifier;
    }

    const tokenData = querystring.stringify(tokenParams);

    try {
      this.logger.log('Exchanging YouTube authorization code for tokens...');
      
      const tokenResponse = await this.makeHttpsRequest(
        'oauth2.googleapis.com',
        '/token',
        'POST',
        tokenData,
        { 'Content-Type': 'application/x-www-form-urlencoded' }
      );

      const tokenJson = JSON.parse(tokenResponse);

      if (tokenJson.error) {
        this.logger.error(`YouTube token exchange error: ${tokenJson.error_description || tokenJson.error}`);
        throw new HttpException(`YouTube authentication failed: ${tokenJson.error_description || tokenJson.error}`, HttpStatus.BAD_REQUEST);
      }

      const expiresAt = new Date();
      expiresAt.setSeconds(expiresAt.getSeconds() + (tokenJson.expires_in || 3600));

      // Fetch user info using the access token
      const userInfo = await this.fetchUserInfo(tokenJson.access_token);

      this.logger.log(`Successfully exchanged tokens for YouTube channel: ${userInfo.title} (${userInfo.channelId})`);

      return {
        accessToken: tokenJson.access_token,
        refreshToken: tokenJson.refresh_token,
        expiresAt,
        tokenType: tokenJson.token_type || 'Bearer',
        scopes: (tokenJson.scope || '').split(' '),
        userInfo,
      };
    } catch (error) {
      this.logger.error('YouTube token exchange failed:', error);
      throw new HttpException('Failed to exchange authorization code', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Fetch user channel information using access token
   */
  private async fetchUserInfo(accessToken: string): Promise<YouTubeUserInfo> {
    try {
      this.logger.log('Fetching YouTube channel information...');

      const channelResponse = await this.makeHttpsRequest(
        'www.googleapis.com',
        '/youtube/v3/channels?part=snippet,statistics&mine=true',
        'GET',
        null,
        { 
          'Authorization': `Bearer ${accessToken}`,
          'Accept': 'application/json'
        }
      );

      const channelData = JSON.parse(channelResponse);

      if (channelData.error) {
        this.logger.error(`YouTube API error: ${channelData.error.message}`);
        throw new HttpException(`YouTube API error: ${channelData.error.message}`, HttpStatus.BAD_REQUEST);
      }

      if (!channelData.items || channelData.items.length === 0) {
        this.logger.error('No YouTube channel found for user');
        throw new HttpException('No YouTube channel found for user', HttpStatus.NOT_FOUND);
      }

      const channel = channelData.items[0];
      const snippet = channel.snippet || {};
      const statistics = channel.statistics || {};

      const userInfo: YouTubeUserInfo = {
        channelId: channel.id,
        title: snippet.title || '',
        description: snippet.description || '',
        customUrl: snippet.customUrl,
        publishedAt: snippet.publishedAt || new Date().toISOString(),
        thumbnails: snippet.thumbnails || {},
        country: snippet.country,
        viewCount: parseInt(statistics.viewCount || '0', 10),
        subscriberCount: parseInt(statistics.subscriberCount || '0', 10),
        videoCount: parseInt(statistics.videoCount || '0', 10),
        hiddenSubscriberCount: statistics.hiddenSubscriberCount || false,
      };

      this.logger.log(`Successfully fetched YouTube channel info: ${userInfo.title} (${userInfo.channelId})`);
      return userInfo;
    } catch (error) {
      this.logger.error('Failed to fetch YouTube user info:', error);
      // Return minimal user info if API call fails
      return {
        channelId: '',
        title: 'YouTube Channel',
        description: '',
        publishedAt: new Date().toISOString(),
        thumbnails: {},
        viewCount: 0,
        subscriberCount: 0,
        videoCount: 0,
        hiddenSubscriberCount: false,
      };
    }
  }

  /**
   * Store credentials securely in Firestore as integration document (matching Meta/TikTok structure)
   */
  async storeCredentials(
    businessId: string,
    credentials: YouTubeCredentials,
  ): Promise<{ id: string }> {
    try {
      // Prepare account info with structure matching Meta/TikTok integrations exactly
      const accountInfo: any = {
        channelId: credentials.userInfo?.channelId || '',
        title: credentials.userInfo?.title || '',
        description: credentials.userInfo?.description || '',
        customUrl: credentials.userInfo?.customUrl || '',
        publishedAt: credentials.userInfo?.publishedAt || '',
        thumbnails: credentials.userInfo?.thumbnails || {},
        country: credentials.userInfo?.country || '',
        viewCount: credentials.userInfo?.viewCount || 0,
        subscriberCount: credentials.userInfo?.subscriberCount || 0,
        videoCount: credentials.userInfo?.videoCount || 0,
        hiddenSubscriberCount: credentials.userInfo?.hiddenSubscriberCount || false,
      };

      // Prepare credentials object
      const integrationCredentials = {
        access_token: credentials.accessToken,
        refresh_token: credentials.refreshToken,
        token_type: credentials.tokenType,
        scopes: credentials.scopes,
        expires_at: credentials.expiresAt,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      // Check if YouTube integration already exists (search by specific channel ID)
      const existingDocs = await this.firestoreService.getDocuments('integrations', [
        { field: 'businessId', operator: '==', value: businessId },
        { field: 'channel', operator: '==', value: 'youtube_channel' },
        { field: 'platformId', operator: '==', value: credentials.userInfo?.channelId || '' }
      ]);

      let integrationId: string;
      
      if (existingDocs.length > 0) {
        // Update existing YouTube integration with new credentials
        integrationId = existingDocs[0].id;
        const existingIntegration = existingDocs[0];
        
        this.logger.log(`Updating existing YouTube integration ${integrationId} for business ${businessId}`);
        
        await this.firestoreService.updateDocument('integrations', integrationId, {
          platformName: 'YouTube',
          platformIcon: this.getPlatformIcon('youtube_channel'),
          accountInfo,
          credentials: integrationCredentials,
          status: 'active',
          // Preserve existing settings, only set defaults if none exist
          settings: existingIntegration.settings || this.getDefaultYouTubeSettings(),
          lastSyncAt: new Date(),
          updatedAt: new Date(),
        });
      } else {
        // Create new YouTube integration
        integrationId = uuidv4();
        
        this.logger.log(`Creating new YouTube integration ${integrationId} for business ${businessId}`);
        
        const integrationDoc = await this.firestoreService.createDocument('integrations', {
          businessId,
          platformId: credentials.userInfo?.channelId || '',
          platformName: 'YouTube',
          platformIcon: this.getPlatformIcon('youtube_channel'),
          channel: 'youtube_channel',
          accountInfo,
          credentials: integrationCredentials,
          status: 'active',
          settings: this.getDefaultYouTubeSettings(),
          createdAt: new Date(),
          updatedAt: new Date(),
        });
        
        integrationId = integrationDoc.id;
      }

      this.logger.log(`Successfully stored YouTube credentials for business ${businessId}, integration ${integrationId}`);
      return { id: integrationId };
    } catch (error) {
      this.logger.error('Failed to store YouTube credentials:', error);
      throw error;
    }
  }

  /**
   * Get integration for a business
   */
  async getIntegrationForBusiness(businessId: string): Promise<any> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const integrationQuery = await integrationsCollection
        .where('businessId', '==', businessId)
        .where('channel', '==', 'youtube_channel')
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
   * Disconnect YouTube integration
   */
  async disconnectIntegration(businessId: string): Promise<void> {
    try {
      const integration = await this.getIntegrationForBusiness(businessId);
      
      if (!integration) {
        throw new HttpException('YouTube integration not found', HttpStatus.NOT_FOUND);
      }

      // Revoke access token if available
      if (integration.credentials?.access_token) {
        try {
          await this.revokeAccessToken(integration.credentials.access_token);
        } catch (error) {
          this.logger.warn('Failed to revoke YouTube access token:', error);
        }
      }

      // Update integration status to disconnected
      await this.firestoreService.updateDocument('integrations', integration.id, {
        status: 'disconnected',
        disconnectedAt: new Date(),
        updatedAt: new Date(),
      });

      this.logger.log(`Successfully disconnected YouTube integration for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to disconnect YouTube integration:', error);
      throw error;
    }
  }

  /**
   * Revoke YouTube access token
   */
  private async revokeAccessToken(accessToken: string): Promise<void> {
    try {
      await this.makeHttpsRequest(
        'oauth2.googleapis.com',
        `/revoke?token=${encodeURIComponent(accessToken)}`,
        'POST',
        null,
        { 'Content-Type': 'application/x-www-form-urlencoded' }
      );
      this.logger.log('Successfully revoked YouTube access token');
    } catch (error) {
      this.logger.error('Failed to revoke YouTube access token:', error);
      throw error;
    }
  }

  /**
   * Get default settings for YouTube integration to match Meta/TikTok integration structure
   */
  private getDefaultYouTubeSettings(): Record<string, any> {
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
      syncVideos: true,
      syncComments: true,
      syncAnalytics: true,
    };
  }

  /**
   * Get platform icon path for YouTube integration to match Meta/TikTok integration structure
   */
  private getPlatformIcon(channel: string): string {
    const iconMap: Record<string, string> = {
      'youtube_channel': 'assets/icons/youtube.png',
      'youtube': 'assets/icons/youtube.png',
    };
    return iconMap[channel] || 'assets/icons/youtube.png';
  }

  /**
   * Make HTTPS request helper
   */
  private makeHttpsRequest(
    hostname: string,
    path: string,
    method: string = 'GET',
    data?: string,
    headers?: Record<string, string>
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      const options = {
        hostname,
        path,
        method,
        headers: {
          'User-Agent': 'Seafrika-YouTube-Integration/1.0',
          ...headers,
        },
      };

      if (data && method !== 'GET') {
        options.headers['Content-Length'] = Buffer.byteLength(data);
      }

      const req = https.request(options, (res) => {
        let responseData = '';

        res.on('data', (chunk) => {
          responseData += chunk;
        });

        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(responseData);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
          }
        });
      });

      req.on('error', (error) => {
        reject(error);
      });

      if (data && method !== 'GET') {
        req.write(data);
      }

      req.end();
    });
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
        'youtube_pkce_verifiers',
        {
          codeVerifier,
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 minutes expiry
        },
        state  // Pass state as the document ID
      );
      this.logger.log(`Stored YouTube PKCE verifier for state: ${state}`);
    } catch (error) {
      this.logger.error('Failed to store YouTube PKCE verifier:', error);
      throw new HttpException('Failed to store PKCE verifier', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Retrieve and delete PKCE code verifier from Firestore
   */
  async retrieveAndDeletePKCEVerifier(state: string): Promise<string> {
    try {
      this.logger.log(`Attempting to retrieve YouTube PKCE verifier for state: ${state}`);
      const doc = await this.firestoreService.getDocument('youtube_pkce_verifiers', state);
      
      if (!doc || !(doc as any).codeVerifier) {
        this.logger.error(`YouTube PKCE verifier not found for state: ${state}`);
        throw new HttpException('PKCE verifier not found or expired', HttpStatus.BAD_REQUEST);
      }

      const codeVerifier = (doc as any).codeVerifier;
      
      // Delete the verifier document after retrieval (one-time use)
      await this.firestoreService.deleteDocument('youtube_pkce_verifiers', state);
      
      this.logger.log(`Successfully retrieved and deleted YouTube PKCE verifier for state: ${state}`);
      return codeVerifier;
    } catch (error) {
      this.logger.error('Failed to retrieve YouTube PKCE verifier:', error);
      throw new HttpException('Failed to retrieve PKCE verifier', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }
}