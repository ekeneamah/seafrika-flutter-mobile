import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { MetaService, IntegrationCredentials } from '../../webhooks/meta/meta.service';
import { FirestoreService } from '../../firestore/firestore.service';
import axios from 'axios';

/**
 * Shared Meta Integration Service
 * 
 * This service provides common functionality for all Meta platforms:
 * - Facebook Pages
 * - Instagram Business
 * - Messenger
 * 
 * It leverages the unified MetaService from webhooks for authentication
 * and provides additional API operations for data retrieval and management.
 */

export interface FacebookPage {
  id: string;
  name: string;
  access_token?: string;
  category?: string;
  about?: string;
  followers_count?: number;
  fan_count?: number;
}

export interface FacebookPost {
  id: string;
  message?: string;
  story?: string;
  created_time: string;
  updated_time: string;
  permalink_url: string;
  status_type: string;
  type: string;
  attachments?: any;
  insights?: any;
}

export interface InstagramMedia {
  id: string;
  media_type: 'IMAGE' | 'VIDEO' | 'CAROUSEL_ALBUM';
  media_url: string;
  thumbnail_url?: string;
  permalink: string;
  caption?: string;
  timestamp: string;
  like_count?: number;
  comments_count?: number;
  insights?: any;
}

export interface InstagramComment {
  id: string;
  text: string;
  username: string;
  timestamp: string;
  like_count?: number;
  replies_count?: number;
}

export interface InstagramMediaResponse {
  data: InstagramMedia[];
  paging?: {
    cursors: {
      before?: string;
      after?: string;
    };
    next?: string;
    previous?: string;
  };
}

export interface IntegrationDocument {
  id: string;
  businessId: string;
  platformId: string;
  channel: string;
  status: string;
  credentials: {
    accessToken: string;         // Changed from access_token to accessToken
    expiresAt?: number;          // Changed from expires_in to expiresAt
    scopes?: string[];
    userId?: string;
    createdAt?: string;          // Changed from created_at to createdAt  
    pageInfo?: {
      pageId: string;
      pageName: string;
      accessToken: string;
      instagramBusinessAccount?: {
        id: string;
        username: string;
      };
    };
  };
  accountInfo?: any;
  createdAt: string;
  updatedAt: string;
}

export interface FacebookInsights {
  page_impressions?: number;
  page_reach?: number;
  page_engaged_users?: number;
  page_post_engagements?: number;
  page_fans?: number;
}

export interface InstagramInsights {
  reach?: number;
  impressions?: number;
  profile_views?: number;
  website_clicks?: number;
  follower_count?: number;
}

@Injectable()
export class MetaIntegrationService {
  private readonly logger = new Logger(MetaIntegrationService.name);

  constructor(
    private readonly metaService: MetaService,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Get stored integrations and their credentials for a business
   */
  async getBusinessIntegrations(businessId: string) {
    try {
      const integrations = await this.metaService.getBusinessIntegrations(businessId);
      if (!integrations || integrations.length === 0) {
        throw new HttpException('No Meta integrations found for this business', HttpStatus.NOT_FOUND);
      }
      return integrations;
    } catch (error) {
      this.logger.error(`Failed to get integrations for business ${businessId}:`, error);
      throw new HttpException('Failed to retrieve Meta integrations', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Get integration by channel type (for backward compatibility)
   */
  async getIntegrationByChannel(businessId: string, channel: string) {
    const integrations = await this.getBusinessIntegrations(businessId);
    const integration = integrations.find(i => i.channel === channel);
    if (!integration) {
      throw new HttpException(`No ${channel} integration found for this business`, HttpStatus.NOT_FOUND);
    }
    return integration;
  }

  /**
   * Legacy method for backward compatibility - reconstructs old credential structure
   */
  async getCredentials(businessId: string) {
    const integrations = await this.getBusinessIntegrations(businessId);
    
    // Find a Facebook integration to get user-level info
    const facebookIntegration = integrations.find(i => 
      i.channel === 'facebook_pages' || i.channel === 'messenger'
    );
    
    if (!facebookIntegration) {
      throw new HttpException('No Facebook integration found for this business', HttpStatus.NOT_FOUND);
    }
    
    // Reconstruct pages array from integrations
    const pages = integrations
      .filter(i => i.credentials.pageInfo)
      .map(i => i.credentials.pageInfo);
      
    // Return structure compatible with old getCredentials
    return {
      accessToken: facebookIntegration.credentials.accessToken,
      expiresAt: facebookIntegration.credentials.expiresAt,
      scopes: facebookIntegration.credentials.scopes,
      userId: facebookIntegration.credentials.userId,
      pages: pages,
    };
  }

  /**
   * Make authenticated API call to Facebook Graph API
   */
  async makeGraphApiCall(endpoint: string, accessToken: string, params: any = {}): Promise<any> {
    try {
      const url = `https://graph.facebook.com/v21.0/${endpoint}`;
      const response = await axios.get(url, {
        params: {
          access_token: accessToken,
          ...params,
        },
      });
      return response.data;
    } catch (error) {
      this.logger.error(`Graph API call failed for endpoint ${endpoint}:`, error.response?.data || error.message);
      throw new HttpException(
        `Facebook API call failed: ${error.response?.data?.error?.message || error.message}`,
        HttpStatus.BAD_REQUEST
      );
    }
  }

  /**
   * Get Facebook Page information
   */
  async getPageInfo(integrationId: string, pageId?: string): Promise<FacebookPage> {
    // Get the specific integration by ID
    const integration = await this.getIntegrationDocument(integrationId);
    
    // Validate that this is a Facebook integration
    if (integration.channel !== 'facebook_pages' && integration.channel !== 'messenger') {
      throw new HttpException('Integration is not a Facebook Pages or Messenger integration', HttpStatus.BAD_REQUEST);
    }
    
    if (integration.status !== 'active') {
      throw new HttpException('Integration is not active', HttpStatus.BAD_REQUEST);
    }
    
    if (!integration.credentials?.pageInfo) {
      throw new HttpException('No page information available in integration', HttpStatus.BAD_REQUEST);
    }
    
    let targetPageId: string;
    let pageAccessToken: string;
    
    if (pageId) {
      // Verify the requested pageId matches this integration's page
      if (integration.credentials.pageInfo.pageId !== pageId) {
        throw new HttpException('Requested page ID does not match this integration', HttpStatus.NOT_FOUND);
      }
      targetPageId = integration.credentials.pageInfo.pageId;
      pageAccessToken = integration.credentials.pageInfo.accessToken;
    } else {
      // Use the integration's page info
      targetPageId = integration.credentials.pageInfo.pageId;
      pageAccessToken = integration.credentials.pageInfo.accessToken;
    }

    return this.makeGraphApiCall(`${targetPageId}`, pageAccessToken, {
      fields: 'id,name,username,about,category,fan_count,followers_count,picture,cover,website,location'
    });
  }

  /**
   * Get Facebook Page posts
   */
  async getPagePosts(businessId: string, pageId?: string, limit: number = 25): Promise<FacebookPost[]> {
    const credentials = await this.getCredentials(businessId);
    
    let targetPageId: string;
    let pageAccessToken: string;
    
    if (pageId) {
      const page = credentials.pages?.find(p => p.pageId === pageId);
      if (!page) {
        throw new HttpException('Page not found in integration', HttpStatus.NOT_FOUND);
      }
      targetPageId = page.pageId;
      pageAccessToken = page.accessToken;
    } else {
      if (!credentials.pages || credentials.pages.length === 0) {
        throw new HttpException('No pages available in integration', HttpStatus.BAD_REQUEST);
      }
      const page = credentials.pages[0];
      targetPageId = page.pageId;
      pageAccessToken = page.accessToken;
    }

    const data = await this.makeGraphApiCall(`${targetPageId}/posts`, pageAccessToken, {
      fields: 'id,message,story,created_time,updated_time,permalink_url,status_type,type,attachments,insights.metric(post_impressions,post_reach,post_engaged_users)',
      limit
    });

    this.logger.log(`Fetched ${data.data } posts for page ${targetPageId}`);

    return data.data || [];
  }

  /**
   * Get Facebook page posts by integration ID
   */
  async getPagePostsByIntegration(integrationId: string, pageId?: string, limit: number = 25): Promise<FacebookPost[]> {
    // Get the specific integration by ID
    const integration = await this.getIntegrationDocument(integrationId);
    
    // Validate that this is a Facebook integration
    if (integration.channel !== 'facebook_pages' && integration.channel !== 'messenger') {
      throw new HttpException('Integration is not a Facebook Pages or Messenger integration', HttpStatus.BAD_REQUEST);
    }
    
    if (integration.status !== 'active') {
      throw new HttpException('Integration is not active', HttpStatus.BAD_REQUEST);
    }
    
    if (!integration.credentials?.pageInfo) {
      throw new HttpException('No page information available in integration', HttpStatus.BAD_REQUEST);
    }
    
    let targetPageId: string;
    let pageAccessToken: string;
    
    if (pageId) {
      // Verify the requested pageId matches this integration's page
      if (integration.credentials.pageInfo.pageId !== pageId) {
        throw new HttpException('Requested page ID does not match this integration', HttpStatus.NOT_FOUND);
      }
      targetPageId = integration.credentials.pageInfo.pageId;
      pageAccessToken = integration.credentials.pageInfo.accessToken;
    } else {
      // Use the integration's page info
      targetPageId = integration.credentials.pageInfo.pageId;
      pageAccessToken = integration.credentials.pageInfo.accessToken;
    }

    const data = await this.makeGraphApiCall(`${targetPageId}/posts`, pageAccessToken, {
      fields: 'id,message,story,created_time,updated_time,permalink_url,status_type,type,attachments,insights.metric(post_impressions,post_reach,post_engaged_users)',
      limit
    });

    return data.data || [];
  }

  /**
   * Get Instagram Business Account media
   */
  async getInstagramMedia(businessId: string, instagramAccountId?: string, limit: number = 25): Promise<InstagramMedia[]> {
    const credentials = await this.getCredentials(businessId);
    
    let targetAccountId: string;
    
    if (instagramAccountId) {
      // Verify the Instagram account exists in our pages
      const pageWithInstagram = credentials.pages?.find(p => 
        p.instagramBusinessAccount?.id === instagramAccountId
      );
      if (!pageWithInstagram) {
        throw new HttpException('Instagram account not found in integration', HttpStatus.NOT_FOUND);
      }
      targetAccountId = instagramAccountId;
    } else {
      // Find the first page with an Instagram business account
      const pageWithInstagram = credentials.pages?.find(p => p.instagramBusinessAccount);
      if (!pageWithInstagram?.instagramBusinessAccount) {
        throw new HttpException('No Instagram business account available', HttpStatus.BAD_REQUEST);
      }
      targetAccountId = pageWithInstagram.instagramBusinessAccount.id;
    }

    const data = await this.makeGraphApiCall(`${targetAccountId}/media`, credentials.accessToken, {
      fields: 'id,media_type,media_url,thumbnail_url,permalink,caption,timestamp,like_count,comments_count,insights.metric(impressions,reach,engagement)',
      limit
    });

    return data.data || [];
  }

  /**
   * Get Facebook Page insights
   */
  async getPageInsights(businessId: string, pageId?: string, period: string = 'day'): Promise<FacebookInsights> {
    const credentials = await this.getCredentials(businessId);
    
    let targetPageId: string;
    let pageAccessToken: string;
    
    if (pageId) {
      const page = credentials.pages?.find(p => p.pageId === pageId);
      if (!page) {
        throw new HttpException('Page not found in integration', HttpStatus.NOT_FOUND);
      }
      targetPageId = page.pageId;
      pageAccessToken = page.accessToken;
    } else {
      if (!credentials.pages || credentials.pages.length === 0) {
        throw new HttpException('No pages available in integration', HttpStatus.BAD_REQUEST);
      }
      const page = credentials.pages[0];
      targetPageId = page.pageId;
      pageAccessToken = page.accessToken;
    }

    const metrics = [
      'page_impressions',
      'page_reach', 
      'page_engaged_users',
      'page_post_engagements',
      'page_fans'
    ];

    const data = await this.makeGraphApiCall(`${targetPageId}/insights`, pageAccessToken, {
      metric: metrics.join(','),
      period
    });

    // Transform the insights data into a more usable format
    const insights: FacebookInsights = {};
    data.data?.forEach((metric: any) => {
      const latestValue = metric.values?.[metric.values.length - 1]?.value;
      if (latestValue !== undefined) {
        insights[metric.name as keyof FacebookInsights] = latestValue;
      }
    });

    return insights;
  }

  /**
   * Get Instagram account insights
   */
  async getInstagramInsights(businessId: string, instagramAccountId?: string, period: string = 'day'): Promise<InstagramInsights> {
    const credentials = await this.getCredentials(businessId);
    
    let targetAccountId: string;
    
    if (instagramAccountId) {
      const pageWithInstagram = credentials.pages?.find(p => 
        p.instagramBusinessAccount?.id === instagramAccountId
      );
      if (!pageWithInstagram) {
        throw new HttpException('Instagram account not found in integration', HttpStatus.NOT_FOUND);
      }
      targetAccountId = instagramAccountId;
    } else {
      const pageWithInstagram = credentials.pages?.find(p => p.instagramBusinessAccount);
      if (!pageWithInstagram?.instagramBusinessAccount) {
        throw new HttpException('No Instagram business account available', HttpStatus.BAD_REQUEST);
      }
      targetAccountId = pageWithInstagram.instagramBusinessAccount.id;
    }

    const metrics = [
      'reach',
      'impressions',
      'profile_views',
      'website_clicks',
      'follower_count'
    ];

    const data = await this.makeGraphApiCall(`${targetAccountId}/insights`, credentials.accessToken, {
      metric: metrics.join(','),
      period
    });

    // Transform the insights data
    const insights: InstagramInsights = {};
    data.data?.forEach((metric: any) => {
      const latestValue = metric.values?.[metric.values.length - 1]?.value;
      if (latestValue !== undefined) {
        insights[metric.name as keyof InstagramInsights] = latestValue;
      }
    });

    return insights;
  }

  /**
   * Post to Facebook Page
   */
  async postToFacebookPage(businessId: string, message: string, pageId?: string, imageUrl?: string): Promise<any> {
    const credentials = await this.getCredentials(businessId);
    
    let targetPageId: string;
    let pageAccessToken: string;
    
    if (pageId) {
      const page = credentials.pages?.find(p => p.pageId === pageId);
      if (!page) {
        throw new HttpException('Page not found in integration', HttpStatus.NOT_FOUND);
      }
      targetPageId = page.pageId;
      pageAccessToken = page.accessToken;
    } else {
      if (!credentials.pages || credentials.pages.length === 0) {
        throw new HttpException('No pages available in integration', HttpStatus.BAD_REQUEST);
      }
      const page = credentials.pages[0];
      targetPageId = page.pageId;
      pageAccessToken = page.accessToken;
    }

    try {
      const url = `https://graph.facebook.com/v21.0/${targetPageId}/feed`;
      const postData: any = {
        message,
        access_token: pageAccessToken
      };

      if (imageUrl) {
        postData.link = imageUrl;
      }

      const response = await axios.post(url, postData);
      return response.data;
    } catch (error) {
      this.logger.error('Failed to post to Facebook page:', error.response?.data || error.message);
      throw new HttpException(
        `Failed to post to Facebook: ${error.response?.data?.error?.message || error.message}`,
        HttpStatus.BAD_REQUEST
      );
    }
  }

  /**
   * Check if credentials are still valid
   */
  async validateCredentials(businessId: string): Promise<boolean> {
    try {
      const credentials = await this.getCredentials(businessId);
      
      // Check if token is expired
      if (credentials.expiresAt && Date.now() > credentials.expiresAt) {
        return false;
      }

      // Test the token by making a simple API call
      await this.makeGraphApiCall('me', credentials.accessToken, { fields: 'id' });
      return true;
    } catch (error) {
      this.logger.warn(`Credentials validation failed for business ${businessId}:`, error.message);
      return false;
    }
  }

  /**
   * Post media to Instagram Business Account
   */
  async postToInstagram(businessId: string, imageUrl: string, caption: string, instagramAccountId?: string): Promise<any> {
    const credentials = await this.getCredentials(businessId);
    
    let targetAccountId: string;
    
    if (instagramAccountId) {
      const pageWithInstagram = credentials.pages?.find(p => 
        p.instagramBusinessAccount?.id === instagramAccountId
      );
      if (!pageWithInstagram) {
        throw new HttpException('Instagram account not found in integration', HttpStatus.NOT_FOUND);
      }
      targetAccountId = instagramAccountId;
    } else {
      const pageWithInstagram = credentials.pages?.find(p => p.instagramBusinessAccount);
      if (!pageWithInstagram?.instagramBusinessAccount) {
        throw new HttpException('No Instagram business account available', HttpStatus.BAD_REQUEST);
      }
      targetAccountId = pageWithInstagram.instagramBusinessAccount.id;
    }

    try {
      // Step 1: Create the media container
      const mediaContainerUrl = `https://graph.facebook.com/v21.0/${targetAccountId}/media`;
      const mediaContainerData = {
        image_url: imageUrl,
        caption,
        access_token: credentials.accessToken
      };

      const mediaContainerResponse = await axios.post(mediaContainerUrl, mediaContainerData);
      const mediaContainerId = mediaContainerResponse.data.id;

      // Step 2: Publish the media
      const publishUrl = `https://graph.facebook.com/v21.0/${targetAccountId}/media_publish`;
      const publishData = {
        creation_id: mediaContainerId,
        access_token: credentials.accessToken
      };

      const publishResponse = await axios.post(publishUrl, publishData);
      return publishResponse.data;
    } catch (error) {
      this.logger.error('Failed to post to Instagram:', error.response?.data || error.message);
      throw new HttpException(
        `Failed to post to Instagram: ${error.response?.data?.error?.message || error.message}`,
        HttpStatus.BAD_REQUEST
      );
    }
  }

  /**
   * Get available Facebook pages for a business
   */
  async getAvailablePages(businessId: string): Promise<any[]> {
    const credentials = await this.getCredentials(businessId);
    
    if (!credentials.pages || credentials.pages.length === 0) {
      return [];
    }

    // Return enriched page information
    const pages = [];
    for (const page of credentials.pages) {
      try {
        const pageInfo = await this.makeGraphApiCall(page.pageId, page.accessToken, {
          fields: 'id,name,username,category,picture,instagram_business_account{id,username,profile_picture_url}'
        });
        
        pages.push({
          ...pageInfo,
          accessToken: page.accessToken // Keep for internal use
        });
      } catch (error) {
        this.logger.warn(`Failed to get info for page ${page.pageId}:`, error.message);
        // Still include the basic page info even if we can't get extended details
        pages.push({
          id: page.pageId,
          name: `Page ${page.pageId}`,
          accessToken: page.accessToken
        });
      }
    }

    return pages;
  }

  /**
   * Get Instagram business accounts connected to pages
   */
  async getInstagramAccounts(businessId: string): Promise<any[]> {
    const credentials = await this.getCredentials(businessId);
    
    if (!credentials.pages || credentials.pages.length === 0) {
      return [];
    }

    const instagramAccounts = [];
    for (const page of credentials.pages) {
      if (page.instagramBusinessAccount) {
        try {
          const accountInfo = await this.makeGraphApiCall(page.instagramBusinessAccount.id, credentials.accessToken, {
            fields: 'id,username,name,profile_picture_url,followers_count,media_count,biography,website'
          });
          
          instagramAccounts.push({
            ...accountInfo,
            connectedPageId: page.pageId
          });
        } catch (error) {
          this.logger.warn(`Failed to get Instagram account info for ${page.instagramBusinessAccount.id}:`, error.message);
          // Still include basic info
          instagramAccounts.push({
            id: page.instagramBusinessAccount.id,
            username: page.instagramBusinessAccount.username || `Account ${page.instagramBusinessAccount.id}`,
            connectedPageId: page.pageId
          });
        }
      }
    }

    return instagramAccounts;
  }

  /**
   * Refresh access tokens if needed
   */
  async refreshTokens(businessId: string): Promise<void> {
    const credentials = await this.getCredentials(businessId);
    
    // Check if token is expiring soon (within 7 days)
    if (credentials.expiresAt) {
      const expirationTime = new Date(credentials.expiresAt);
      const now = new Date();
      const sevenDaysFromNow = new Date(now.getTime() + (7 * 24 * 60 * 60 * 1000));
      
      if (expirationTime <= sevenDaysFromNow) {
        this.logger.warn(`Token for business ${businessId} expires soon (${expirationTime}). Manual token refresh required.`);
        // Note: Automatic token refresh would require implementing long-lived token exchange
        // For now, we just warn about the expiration
      }
    }
  }

  // ========== ENHANCED INSTAGRAM FUNCTIONALITY ==========

  /**
   * Get Instagram media for a given integration using integration ID
   */
  async getInstagramMediaByIntegration(
    integrationId: string, 
    limit: number = 25,
    after?: string
  ): Promise<InstagramMediaResponse> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegrationDocument(integrationId);
    
    // 2. Validate integration
    this.validateIntegrationDocument(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { accessToken } = integration.credentials;
    const { igUserId, pageToken } = await this.resolveInstagramUserId(integration, this.metaService.decryptData(accessToken));
    
    // 4. Call Instagram Graph API with correct Instagram user ID and page token
    const mediaData = await this.fetchInstagramMediaFromAPI(igUserId, pageToken, limit, after);
    
    // 5. Normalize and return data
    return this.normalizeInstagramMediaResponse(mediaData);
  }

  /**
   * Get Instagram business account profile for a specific integration
   */
  async getInstagramProfileByIntegration(integrationId: string): Promise<any> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegrationDocument(integrationId);
    
    // 2. Validate integration
    this.validateIntegrationDocument(integration);

    // 2) Decrypt tokens you will use
  //    - Main credentials.accessToken is ENCRYPTED in your storeCredentials(); decrypt it.
  const userTokenPlain = this.metaService.decryptData(integration.credentials.accessToken);

  const pageTokenPlain = integration.credentials.pageInfo?.accessToken; 
    if (!pageTokenPlain) {
    this.logger.warn('No page token on integration; attempting to resolve via user token');
  }
// current code stored in plaintext
    
    // 3. Extract credentials and resolve Instagram user ID
    const { accessToken } = integration.credentials;
    const { igUserId, pageToken } = await this.resolveInstagramUserId(
    integration,
     userTokenPlain, // prefer page token, fallback to user token if your impl supports it
  );
  if (!igUserId) {
    throw new HttpException('No Instagram business account linked to this Page', HttpStatus.BAD_REQUEST);
  }
    // 4) Call IG Graph for profile with PAGE token + appsecret_proof
  const tokenForIg = pageToken; // IG profile reads require a Page token (or system user)
  const proof = this.metaService.appSecretProof(tokenForIg);
    // 4. Call Instagram Graph API to get profile information
    try {
        this.logger.log(`Fetching Instagram profile for IG user ${igUserId}`);
      const profileUrl = `https://graph.facebook.com/v21.0/${igUserId}`;
      const profileParams = {
        fields: 'id,username,name,biography,followers_count,follows_count,media_count,profile_picture_url,website',
        access_token: tokenForIg,
      };

      this.logger.log(`Fetching Instagram profile for user ID: ${igUserId}`);
      const profileResponse = await this.makeGraphApiCall(igUserId, tokenForIg, {
        fields: 'id,username,name,biography,followers_count,follows_count,media_count,profile_picture_url,website',
        appsecret_proof: proof,
      });

      // Add additional metadata
      const profileData = {
        ...profileResponse,
        account_type: 'BUSINESS',
        integration_id: integrationId,
      };

      this.logger.log(`Successfully retrieved Instagram profile for @${profileData.username}`);
      return profileData;
    } catch (error) {
      this.logger.error(`Failed to fetch Instagram profile for integration ${integrationId}:`, error);
      throw new HttpException(
        `Failed to fetch Instagram profile: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }

  /**
   * Get Instagram comments for a specific post
   */
  async getInstagramComments(
    integrationId: string,
    postId: string,
    limit: number = 25,
    after?: string
  ): Promise<InstagramComment[]> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegrationDocument(integrationId);
    
    // 2. Validate integration
    this.validateIntegrationDocument(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { accessToken } = integration.credentials;
    const { pageToken } = await this.resolveInstagramUserId(integration, this.metaService.decryptData(accessToken));
    
    // 4. Call Instagram Graph API to get comments
    const commentsData = await this.fetchInstagramCommentsFromAPI(postId, pageToken, limit, after);
    
    // 5. Return normalized comments data
    return commentsData.data || [];
  }

  /**
   * Reply to an Instagram comment
   */
  async replyToInstagramComment(
    integrationId: string,
    commentId: string,
    message: string
  ): Promise<any> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegrationDocument(integrationId);
    
    // 2. Validate integration
    this.validateIntegrationDocument(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { accessToken } = integration.credentials;
    const { pageToken } = await this.resolveInstagramUserId(integration, this.metaService.decryptData(accessToken));
    
    // 4. Call Instagram Graph API to reply to comment
    const replyData = await this.postCommentReplyToAPI(commentId, message, pageToken);
    
    // 5. Return reply data
    return replyData;
  }

  /**
   * Create a new Instagram post with advanced features
   */
  async createInstagramPost(
    integrationId: string,
    postData: {
      image_url?: string;
      video_url?: string;
      caption?: string;
      media_type?: 'IMAGE' | 'VIDEO' | 'CAROUSEL_ALBUM';
      children?: Array<{ media_url: string; media_type: 'IMAGE' | 'VIDEO' }>;
    }
  ): Promise<any> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegrationDocument(integrationId);
    
    // 2. Validate integration
    this.validateIntegrationDocument(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { accessToken } = integration.credentials;
    const { igUserId, pageToken } = await this.resolveInstagramUserId(integration, this.metaService.decryptData(accessToken));
    
    // 4. Create the post via Instagram Graph API
    const postResult = await this.createInstagramPostToAPI(igUserId, postData, pageToken);
    
    // 5. Return post data
    return postResult;
  }

  // ========== PRIVATE HELPER METHODS ==========

  /**
   * Get integration document from Firestore
   */
  private async getIntegrationDocument(integrationId: string): Promise<IntegrationDocument> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const integrationDoc = await integrationsCollection.doc(integrationId).get();
      
      if (!integrationDoc.exists) {
        this.logger.warn(`Integration not found: ${integrationId}`);
        throw new HttpException(
          'Integration not found',
          HttpStatus.NOT_FOUND,
        );
      }

      const integration = integrationDoc.data() as IntegrationDocument;
      integration.id = integrationDoc.id;
      
      this.logger.log(`Found integration: ${integrationId} for business: ${integration.businessId}`);
      return integration;
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      
      this.logger.error(`Failed to fetch integration ${integrationId}:`, error);
      throw new HttpException(
        'Failed to fetch integration data',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Validate integration document
   */
  private validateIntegrationDocument(integration: IntegrationDocument): void {
    // Check if this is an Instagram integration using the channel field
    if (integration.channel !== 'instagram') {
      this.logger.warn(`Invalid channel for integration ${integration.id}: ${integration.channel} (expected: instagram)`);
      throw new HttpException(
        'Integration is not an Instagram integration',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (integration.status !== 'active') {
      this.logger.warn(`Integration ${integration.id} is not active: ${integration.status}`);
      throw new HttpException(
        'Integration is not active',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (!integration.credentials?.accessToken) {
      this.logger.warn(`Missing access token for integration ${integration.id}`);
      throw new HttpException(
        'Integration credentials are missing or invalid',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Check if token is expired (if expiry info is available)
    if (integration.credentials.expiresAt) {
      const expiresAt = new Date(integration.credentials.expiresAt);
      
      if (new Date() > expiresAt) {
        this.logger.warn(`Access token expired for integration ${integration.id}`);
        throw new HttpException(
          'Access token has expired',
          HttpStatus.UNAUTHORIZED,
        );
      }
    }

    this.logger.log(`Integration validation passed for ${integration.id} (channel: ${integration.channel})`);
  }

  /**
   * Validate Facebook access token and its permissions
   */
  private async validateFacebookToken(accessToken: string): Promise<void> {
    try {
      // Check token validity by making a simple "me" call
      const meUrl = 'https://graph.facebook.com/v21.0/me';
      const meParams = {
        fields: 'id,name',
        access_token: accessToken,
      };

      this.logger.log('Validating Facebook token...');
      const meResponse = await axios.get(meUrl, { params: meParams });
      
      if (meResponse.status === 200 && meResponse.data?.id) {
        this.logger.log(`Facebook token validated successfully for user: ${meResponse.data.name || 'Unknown'}`);
      } else {
        throw new HttpException(
          'Facebook token validation failed - invalid response',
          HttpStatus.UNAUTHORIZED,
        );
      }
    } catch (error: any) {
      if (error instanceof HttpException) {
        throw error;
      }

      this.logger.error('Failed to validate Facebook token:', {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
      });

      // Provide specific error messages based on status code
      if (error.response?.status === 400) {
        throw new HttpException(
          'Facebook token is invalid or expired. Please reconnect your Instagram integration.',
          HttpStatus.UNAUTHORIZED,
        );
      } else if (error.response?.status === 403) {
        throw new HttpException(
          'Facebook token has insufficient permissions. Please reconnect your Instagram integration.',
          HttpStatus.FORBIDDEN,
        );
      } else {
        throw new HttpException(
          'Failed to validate Facebook token. Please reconnect your Instagram integration.',
          HttpStatus.UNAUTHORIZED,
        );
      }
    }
  }

  /**
   * Resolve Instagram user ID from Facebook pages
   */
  private async resolveInstagramUserId(
    integration: IntegrationDocument, 
    userToken: string
  ): Promise<{ igUserId: string; pageToken: string }> {
    try {
      // First validate the Facebook token
      await this.validateFacebookToken(userToken);
      const userProof = this.metaService.appSecretProof(userToken);
      // Check if we already have the IG user ID cached in pageInfo
      const cachedPageInfo = integration.credentials.pageInfo;
      const cachedIgUserId = cachedPageInfo?.instagramBusinessAccount?.id;
      const cachedPageId = cachedPageInfo?.pageId;
      
      this.logger.log(`Resolving Instagram user ID for integration ${integration.id}`);
      
      // Get Facebook pages that the user manages with USER token
      const pagesUrl = `https://graph.facebook.com/v21.0/me/accounts`;
      const pagesParams = {
        fields: 'id,name,access_token',
        access_token: userToken,
        appsecret_proof: userProof,
        limit: 50,
      };

      this.logger.log(`Fetching Facebook pages: ${pagesUrl}`);
      
      let pagesResponse;
      try {
        pagesResponse = await axios.get(pagesUrl, { params: pagesParams });
      } catch (apiError: any) {
        // Log detailed Facebook API error
        this.logger.error('Facebook API error when fetching pages:', {
          status: apiError.response?.status,
          statusText: apiError.response?.statusText,
          data: apiError.response?.data,
          url: pagesUrl,
          params: pagesParams
        });
        throw apiError;
      }
      
      const pages = pagesResponse.data?.data ?? [];

      if (!pages.length) {
        this.logger.warn('No Facebook pages found for user');
        throw new HttpException(
          'No Pages returned for this user. Check scopes and Page Admin role.',
          HttpStatus.BAD_REQUEST,
        );
      }

      this.logger.log(`Found ${pages.length} Facebook pages`);
const cached = integration.credentials.pageInfo;
      // If we have cached data, try to find that specific page first
      if (cachedIgUserId && cachedPageId) {
        const cachedPage = pages.find((page: any) => page.id === cachedPageId);
        if (cachedPage && cachedPage.access_token) {
          this.logger.log(`Using cached Instagram user ID: ${cachedIgUserId} for page: ${cachedPage.name}`);
          return {
            igUserId: cachedIgUserId,
            pageToken: cachedPage.access_token,
          };
        } else {
          this.logger.warn(`Cached page ${cachedPageId} not found or has no token, will rediscover`);
        }
      }

      // Try to find a page with connected Instagram account
      for (const page of pages) {
        if (!page.access_token) {
          this.logger.warn(`Page ${page.id} has no access token, skipping`);
          continue;
        }

        try {
            const pageProof = this.metaService.appSecretProof(page.access_token);
          // Check if this page has a connected Instagram account using PAGE token
          const pageUrl = `https://graph.facebook.com/v21.0/${page.id}`;
          const pageParams = {
            fields: 'instagram_business_account{id,username}',
            access_token: page.access_token,
            appsecret_proof: pageProof,
          };

          this.logger.log(`Checking Instagram connection for page ${page.id}: ${page.name}`);
          const pageResponse = await axios.get(pageUrl, { params: pageParams });
          const igUserId = pageResponse.data?.instagram_business_account?.id;

          if (igUserId) {
            this.logger.log(`Found Instagram user ID: ${igUserId} for page: ${page.name}`);
            
            // Cache the Instagram user ID and page info for future requests
            await this.updateIntegrationCredentials(integration.id, {
              ig_user_id: igUserId,
              facebook_page_id: page.id,
              facebook_page_name: page.name,
            });

            return {
              igUserId,
              pageToken: page.access_token,
            };
          } else {
            this.logger.log(`Page ${page.name} has no connected Instagram account`);
          }
        } catch (pageError: any) {
          this.logger.warn(`Failed to check Instagram connection for page ${page.id}:`, pageError.message);
          continue;
        }
      }

      // If we get here, no pages had connected Instagram accounts
      throw new HttpException(
        'No connected Instagram account found on any granted Page. Please connect an Instagram Business Account to your Facebook Page.',
        HttpStatus.BAD_REQUEST,
      );
    } catch (error: any) {
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Log detailed error information for debugging
      this.logger.error('Failed to resolve Instagram user ID:', {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        stack: error.stack
      });
      
      throw new HttpException(
        'Failed to resolve Instagram account information',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Update integration credentials with Instagram user info
   */
  private async updateIntegrationCredentials(
    integrationId: string, 
    updates: { ig_user_id: string; facebook_page_id: string; facebook_page_name: string }
  ): Promise<void> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      
      // Update the pageInfo structure to include Instagram account info
      await integrationsCollection.doc(integrationId).update({
        'credentials.pageInfo.pageId': updates.facebook_page_id,
        'credentials.pageInfo.pageName': updates.facebook_page_name,
        'credentials.pageInfo.instagramBusinessAccount.id': updates.ig_user_id,
        updatedAt: new Date().toISOString(),
      });
      
      this.logger.log(`Updated integration ${integrationId} with Instagram user ID: ${updates.ig_user_id}`);
    } catch (error) {
      this.logger.error(`Failed to update integration credentials:`, error);
      // Don't throw here - the main flow can continue even if caching fails
    }
  }

  /**
   * Fetch media from Instagram Graph API using Instagram user ID and page token
   */
  private async fetchInstagramMediaFromAPI(
    igUserId: string, 
    pageToken: string, 
    limit: number, 
    after?: string
  ): Promise<any> {
    try {
      // Build the API URL for Instagram user media
      const url = `https://graph.facebook.com/v21.0/${igUserId}/media`;
      
      // Define the fields we want to fetch
      const fields = [
        'id',
        'caption',
        'media_type',
        'media_url',
        'thumbnail_url',
        'permalink',
        'timestamp',
      ];

      const params: any = {
        fields: fields.join(','),
        access_token: pageToken,
        limit: limit,
      };

      if (after) {
        params.after = after;
      }

      this.logger.log(`Fetching Instagram media for user: ${igUserId}, limit: ${limit}, after: ${after || 'none'}`);
      
      const response = await axios.get(url, { params });
      
      this.logger.log(`Instagram API response: ${response.status}, items: ${response.data.data?.length || 0}`);
      
      return response.data;
    } catch (error: any) {
      this.logger.error('Instagram API call failed:', error.response?.data || error.message);
      
      if (error.response) {
        const { status, data } = error.response;
        
        if (status === 400) {
          const errorMessage = data.error?.message || 'Bad request';
          if (errorMessage.includes('nonexisting field')) {
            throw new HttpException(
              'Invalid Instagram user ID or insufficient permissions for media access',
              HttpStatus.BAD_REQUEST,
            );
          }
          throw new HttpException(
            `Instagram API error: ${errorMessage}`,
            HttpStatus.BAD_REQUEST,
          );
        }
        
        if (status === 401) {
          throw new HttpException(
            'Instagram access token is invalid or expired',
            HttpStatus.UNAUTHORIZED,
          );
        }
        
        if (status === 403) {
          throw new HttpException(
            'Insufficient permissions for Instagram API',
            HttpStatus.FORBIDDEN,
          );
        }
        
        if (status === 429) {
          throw new HttpException(
            'Instagram API rate limit exceeded',
            HttpStatus.TOO_MANY_REQUESTS,
          );
        }
      }
      
      throw new HttpException(
        'Failed to fetch data from Instagram API',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Normalize Instagram API response to match our expected format
   */
  private normalizeInstagramMediaResponse(apiResponse: any): InstagramMediaResponse {
    const normalizedData: InstagramMedia[] = (apiResponse.data || []).map((item: any) => {
      return {
        id: item.id,
        media_type: item.media_type || 'IMAGE',
        media_url: item.media_url || '',
        thumbnail_url: item.thumbnail_url || undefined,
        caption: item.caption || '',
        timestamp: item.timestamp || new Date().toISOString(),
        permalink: item.permalink || '',
        // Set default values for metrics that might not be available
        like_count: 0,
        comments_count: 0,
      };
    });

    const result: InstagramMediaResponse = {
      data: normalizedData,
    };

    // Include paging information if available
    if (apiResponse.paging) {
      result.paging = {
        cursors: apiResponse.paging.cursors,
        next: apiResponse.paging.next,
        previous: apiResponse.paging.previous,
      };
    }

    return result;
  }

  /**
   * Fetch Instagram comments from Graph API
   */
  private async fetchInstagramCommentsFromAPI(
    postId: string,
    accessToken: string,
    limit: number,
    after?: string
  ): Promise<any> {
    try {
      const url = `https://graph.facebook.com/v21.0/${postId}/comments`;
      const params: any = {
        fields: 'id,text,username,timestamp,like_count,replies_count',
        access_token: accessToken,
        limit: limit,
      };

      if (after) {
        params.after = after;
      }

      this.logger.log(`Fetching comments from: ${url}`);
      this.logger.log(`Parameters:`, { ...params, access_token: '[REDACTED]' });

      const response = await axios.get(url, { params });

      this.logger.log(`Instagram Comments API response status: ${response.status}`);
      this.logger.log(`Retrieved ${response.data?.data?.length || 0} comments`);

      return response.data;
    } catch (error: any) {
      this.logger.error(`Instagram Comments API error:`, {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        postId: postId,
      });

      if (error.response?.status === 400) {
        const errorData = error.response.data;
        if (errorData?.error?.message?.includes('Unsupported get request') || 
            errorData?.error?.code === 100) {
          throw new HttpException(
            `Comments not available for this post. The post may not support comments or you may not have permission to view them.`,
            HttpStatus.BAD_REQUEST
          );
        }
        throw new HttpException(
          `Invalid request to Instagram API: ${errorData?.error?.message || 'Bad request'}`,
          HttpStatus.BAD_REQUEST
        );
      }

      if (error.response?.status === 403) {
        throw new HttpException(
          'Insufficient permissions to access Instagram comments. Please ensure you have granted all required permissions.',
          HttpStatus.FORBIDDEN
        );
      }

      if (error.response?.status === 404) {
        throw new HttpException(
          `Post not found or comments are not accessible for post ID: ${postId}`,
          HttpStatus.NOT_FOUND
        );
      }

      if (error.response?.status === 429) {
        throw new HttpException(
          'Instagram API rate limit exceeded. Please try again later.',
          HttpStatus.TOO_MANY_REQUESTS
        );
      }

      throw new HttpException(
        `Failed to fetch Instagram comments: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }

  /**
   * Post a reply to Instagram comment via Graph API
   */
  private async postCommentReplyToAPI(
    commentId: string,
    message: string,
    accessToken: string
  ): Promise<any> {
    try {
      const url = `https://graph.facebook.com/v21.0/${commentId}/replies`;
      const data = {
        message: message,
        access_token: accessToken,
      };

      this.logger.log(`Posting reply to comment: ${commentId}`);
      this.logger.log(`Reply message length: ${message.length}`);

      const response = await axios.post(url, data);

      this.logger.log(`Instagram Reply API response status: ${response.status}`);
      this.logger.log(`Reply posted with ID: ${response.data?.id}`);

      return {
        id: response.data.id,
        message: 'Reply posted successfully'
      };
    } catch (error: any) {
      this.logger.error(`Instagram Reply API error:`, {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        commentId: commentId,
      });

      if (error.response?.status === 400) {
        const errorData = error.response.data;
        if (errorData?.error?.message?.includes('comment')) {
          throw new HttpException(
            `Cannot reply to this comment: ${errorData?.error?.message || 'Comment may not exist or replies may not be allowed'}`,
            HttpStatus.BAD_REQUEST
          );
        }
        throw new HttpException(
          `Invalid reply request: ${errorData?.error?.message || 'Bad request'}`,
          HttpStatus.BAD_REQUEST
        );
      }

      if (error.response?.status === 403) {
        throw new HttpException(
          'Insufficient permissions to reply to Instagram comments. Please ensure you have granted comment management permissions.',
          HttpStatus.FORBIDDEN
        );
      }

      if (error.response?.status === 404) {
        throw new HttpException(
          `Comment not found or not accessible: ${commentId}`,
          HttpStatus.NOT_FOUND
        );
      }

      if (error.response?.status === 429) {
        throw new HttpException(
          'Instagram API rate limit exceeded. Please try again later.',
          HttpStatus.TOO_MANY_REQUESTS
        );
      }

      throw new HttpException(
        `Failed to post reply to Instagram comment: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }

  /**
   * Create Instagram post via Graph API
   */
  private async createInstagramPostToAPI(
    igUserId: string,
    postData: {
      image_url?: string;
      video_url?: string;
      caption?: string;
      media_type?: 'IMAGE' | 'VIDEO' | 'CAROUSEL_ALBUM';
      children?: Array<{ media_url: string; media_type: 'IMAGE' | 'VIDEO' }>;
    },
    accessToken: string
  ): Promise<any> {
    try {
      // Step 1: Create media container
      const containerData = await this.createMediaContainer(igUserId, postData, accessToken);
      
      // Step 2: Publish the media container
      const publishData = await this.publishMediaContainer(igUserId, containerData.id, accessToken);
      
      return {
        id: publishData.id,
        permalink: `https://www.instagram.com/p/${publishData.id}/`,
        message: 'Post created successfully'
      };
    } catch (error: any) {
      this.logger.error(`Instagram Post Creation error:`, {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        igUserId: igUserId,
      });

      if (error.response?.status === 400) {
        const errorData = error.response.data;
        if (errorData?.error?.message?.includes('media')) {
          throw new HttpException(
            `Invalid media: ${errorData?.error?.message || 'Media URL may be invalid or unsupported format'}`,
            HttpStatus.BAD_REQUEST
          );
        }
        throw new HttpException(
          `Invalid post data: ${errorData?.error?.message || 'Bad request'}`,
          HttpStatus.BAD_REQUEST
        );
      }

      if (error.response?.status === 403) {
        throw new HttpException(
          'Insufficient permissions to create Instagram posts. Please ensure you have granted content publishing permissions.',
          HttpStatus.FORBIDDEN
        );
      }

      if (error.response?.status === 429) {
        throw new HttpException(
          'Instagram API rate limit exceeded. Please try again later.',
          HttpStatus.TOO_MANY_REQUESTS
        );
      }

      throw new HttpException(
        `Failed to create Instagram post: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }

  /**
   * Create media container for Instagram post
   */
  private async createMediaContainer(
    igUserId: string,
    postData: {
      image_url?: string;
      video_url?: string;
      caption?: string;
      media_type?: 'IMAGE' | 'VIDEO' | 'CAROUSEL_ALBUM';
      children?: Array<{ media_url: string; media_type: 'IMAGE' | 'VIDEO' }>;
    },
    accessToken: string
  ): Promise<any> {
    const url = `https://graph.facebook.com/v21.0/${igUserId}/media`;
    
    const data: any = {
      access_token: accessToken,
    };

    // Handle different media types
    if (postData.children && postData.children.length > 0) {
      // Carousel post
      data.media_type = 'CAROUSEL_ALBUM';
      if (postData.caption) {
        data.caption = postData.caption;
      }
      
      // Create child media containers first
      const childrenIds = [];
      for (const child of postData.children) {
        const childContainer = await this.createChildMediaContainer(igUserId, child, accessToken);
        childrenIds.push(childContainer.id);
      }
      data.children = childrenIds.join(',');
    } else if (postData.video_url) {
      // Video post
      data.media_type = 'VIDEO';
      data.video_url = postData.video_url;
      if (postData.caption) {
        data.caption = postData.caption;
      }
    } else if (postData.image_url) {
      // Image post
      data.media_type = 'IMAGE';
      data.image_url = postData.image_url;
      if (postData.caption) {
        data.caption = postData.caption;
      }
    } else {
      throw new HttpException('No media URL provided', HttpStatus.BAD_REQUEST);
    }

    this.logger.log(`Creating media container for user: ${igUserId}`);
    const response = await axios.post(url, data);
    
    this.logger.log(`Media container created: ${response.data.id}`);
    return response.data;
  }

  /**
   * Create child media container for carousel posts
   */
  private async createChildMediaContainer(
    igUserId: string,
    childData: { media_url: string; media_type: 'IMAGE' | 'VIDEO' },
    accessToken: string
  ): Promise<any> {
    const url = `https://graph.facebook.com/v21.0/${igUserId}/media`;
    
    const data: any = {
      access_token: accessToken,
      media_type: childData.media_type,
      is_carousel_item: true,
    };

    if (childData.media_type === 'IMAGE') {
      data.image_url = childData.media_url;
    } else {
      data.video_url = childData.media_url;
    }

    const response = await axios.post(url, data);
    return response.data;
  }

  /**
   * Publish media container
   */
  private async publishMediaContainer(
    igUserId: string,
    containerId: string,
    accessToken: string
  ): Promise<any> {
    const url = `https://graph.facebook.com/v21.0/${igUserId}/media_publish`;
    
    const data = {
      creation_id: containerId,
      access_token: accessToken,
    };

    this.logger.log(`Publishing media container: ${containerId}`);
    const response = await axios.post(url, data);
    
    this.logger.log(`Media published: ${response.data.id}`);
    return response.data;
  }
}