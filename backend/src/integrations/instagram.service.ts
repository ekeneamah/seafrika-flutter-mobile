import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../firestore/firestore.service';
import axios, { AxiosResponse } from 'axios';
import { 
  InstagramMediaItem, 
  InstagramMediaResponse, 
  IntegrationDocument,
  IntegrationCredentials 
} from './types/instagram.types';

@Injectable()
export class InstagramService {
  private readonly logger = new Logger(InstagramService.name);
  private readonly GRAPH_API_BASE_URL = 'https://graph.facebook.com/v21.0';

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Get Instagram media for a given integration
   */
  async getInstagramMedia(
    integrationId: string, 
    limit: number = 25, 
    after?: string
  ): Promise<InstagramMediaResponse> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegration(integrationId);
    
    // 2. Validate integration
    this.validateIntegration(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { access_token } = integration.credentials;
    const { igUserId, pageToken } = await this.resolveInstagramUserId(integration, access_token);
    
    // 4. Call Instagram Graph API with correct Instagram user ID and page token
    const mediaData = await this.fetchInstagramMediaFromAPI(igUserId, pageToken, limit, after);
    
    // 5. Normalize and return data
    return this.normalizeInstagramMediaResponse(mediaData);
  }

  /**
   * Get integration document from Firestore
   */
  private async getIntegration(integrationId: string): Promise<IntegrationDocument> {
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
  private validateIntegration(integration: IntegrationDocument): void {
    if (integration.platformId !== 'instagram') {
      this.logger.warn(`Invalid platform for integration ${integration.id}: ${integration.platformId}`);
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

    if (!integration.credentials?.access_token) {
      this.logger.warn(`Missing access token for integration ${integration.id}`);
      throw new HttpException(
        'Integration credentials are missing or invalid',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Check if token is expired (if expiry info is available)
    if (integration.credentials.expires_in && integration.credentials.created_at) {
      const createdAt = new Date(integration.credentials.created_at);
      const expiresAt = new Date(createdAt.getTime() + (integration.credentials.expires_in * 1000));
      
      if (new Date() > expiresAt) {
        this.logger.warn(`Access token expired for integration ${integration.id}`);
        throw new HttpException(
          'Access token has expired',
          HttpStatus.UNAUTHORIZED,
        );
      }
    }

    // Note: We no longer require user_id to be an Instagram ID at this stage
    // We'll discover it from the Facebook pages if needed
  }

  /**
   * Resolve Instagram user ID from Facebook pages
   * This discovers the Instagram Business Account ID that we need for /media calls
   */
  private async resolveInstagramUserId(
    integration: IntegrationDocument, 
    userToken: string
  ): Promise<{ igUserId: string; pageToken: string }> {
    try {
      // Check if we already have the IG user ID cached
      const cachedIgUserId = integration.credentials.ig_user_id;
      const cachedPageId = integration.credentials.facebook_page_id;
      
      this.logger.log(`Resolving Instagram user ID for integration ${integration.id}`);
      
      // Get Facebook pages that the user manages with USER token
      const pagesUrl = `${this.GRAPH_API_BASE_URL}/me/accounts`;
      const pagesParams = {
        fields: 'id,name,access_token',
        access_token: userToken,
        limit: 50,
      };

      this.logger.log(`Fetching Facebook pages: ${pagesUrl}`);
      const pagesResponse = await axios.get(pagesUrl, { params: pagesParams });
      const pages = pagesResponse.data?.data ?? [];

      if (!pages.length) {
        this.logger.warn('No Facebook pages found for user');
        throw new HttpException(
          'No Pages returned for this user. Check scopes and Page Admin role.',
          HttpStatus.BAD_REQUEST,
        );
      }

      this.logger.log(`Found ${pages.length} Facebook pages`);

      // If we have cached data, try to find that specific page first
      if (cachedIgUserId && cachedPageId) {
        const cachedPage = pages.find(p => p.id === cachedPageId);
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
          // Check if this page has a connected Instagram account using PAGE token
          const pageUrl = `${this.GRAPH_API_BASE_URL}/${page.id}`;
          const pageParams = {
            fields: 'connected_instagram_account{id}',
            access_token: page.access_token,
          };

          this.logger.log(`Checking Instagram connection for page ${page.id}: ${page.name}`);
          const pageResponse = await axios.get(pageUrl, { params: pageParams });
          const igUserId = pageResponse.data?.connected_instagram_account?.id;

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
        } catch (pageError) {
          this.logger.warn(`Failed to check Instagram connection for page ${page.id}:`, pageError.message);
          continue;
        }
      }

      // If we get here, no pages had connected Instagram accounts
      throw new HttpException(
        'No connected Instagram account found on any granted Page. Please connect an Instagram Business Account to your Facebook Page.',
        HttpStatus.BAD_REQUEST,
      );

    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      
      this.logger.error('Failed to resolve Instagram user ID:', error);
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
      await integrationsCollection.doc(integrationId).update({
        'credentials.ig_user_id': updates.ig_user_id,
        'credentials.facebook_page_id': updates.facebook_page_id,
        'credentials.facebook_page_name': updates.facebook_page_name,
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
      const url = `${this.GRAPH_API_BASE_URL}/${igUserId}/media`;
      
      // Define the fields we want to fetch
      const fields = [
        'id',
        'caption',
        'media_type',
        'media_url',
        'thumbnail_url',
        'permalink',
        'timestamp',
        // Note: like_count and comments_count require additional permissions
        // and may need separate API calls or may not be available
        // We'll handle this gracefully by setting default values
      ].join(',');

      const params: any = {
        fields,
        limit,
        access_token: pageToken, // Use PAGE token, not USER token
      };

      if (after) {
        params.after = after;
      }

      this.logger.log(`Calling Instagram API: ${url} with IG user ID: ${igUserId}, limit: ${limit}, after: ${after || 'none'}`);
      
      const response: AxiosResponse = await axios.get(url, { params });
      
      this.logger.log(`Instagram API response: ${response.status}, items: ${response.data.data?.length || 0}`);
      
      return response.data;
    } catch (error) {
      this.logger.error('Instagram API call failed:', error.response?.data || error.message);
      
      if (error.response) {
        const { status, data } = error.response;
        
        if (status === 400) {
          // Check for specific error messages
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
    const normalizedData: InstagramMediaItem[] = (apiResponse.data || []).map((item: any) => {
      return {
        id: item.id,
        media_type: item.media_type || 'IMAGE',
        media_url: item.media_url || '',
        thumbnail_url: item.thumbnail_url || undefined,
        caption: item.caption || '',
        timestamp: item.timestamp || new Date().toISOString(),
        permalink: item.permalink || '',
        // Set default values for metrics that might not be available
        // Note: These require additional API permissions and calls
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
   * Get Instagram comments for a specific post
   */
  async getInstagramComments(
    integrationId: string,
    postId: string,
    limit: number = 25,
    after?: string
  ): Promise<any> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegration(integrationId);
    
    // 2. Validate integration
    this.validateIntegration(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { access_token } = integration.credentials;
    const { pageToken } = await this.resolveInstagramUserId(integration, access_token);
    
    // 4. Call Instagram Graph API to get comments
    const commentsData = await this.fetchInstagramCommentsFromAPI(postId, pageToken, limit, after);
    
    // 5. Return normalized comments data
    return commentsData;
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
      const url = `${this.GRAPH_API_BASE_URL}/${postId}/comments`;
      const params: any = {
        fields: 'id,text,username,timestamp,like_count,replies_count',
        access_token: accessToken,
        limit: limit,
      };

      if (after) {
        params.after = after;
      }

      this.logger.log(`🔍 Fetching comments from: ${url}`);
      this.logger.log(`📊 Parameters:`, { ...params, access_token: '[REDACTED]' });

      const response: AxiosResponse = await axios.get(url, { params });

      this.logger.log(`✅ Instagram Comments API response status: ${response.status}`);
      this.logger.log(`📱 Retrieved ${response.data?.data?.length || 0} comments`);

      return response.data;
    } catch (error) {
      this.logger.error(`❌ Instagram Comments API error:`, {
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
          throw new Error(`Comments not available for this post. The post may not support comments or you may not have permission to view them.`);
        }
        throw new Error(`Invalid request to Instagram API: ${errorData?.error?.message || 'Bad request'}`);
      }

      if (error.response?.status === 403) {
        throw new Error('Insufficient permissions to access Instagram comments. Please ensure you have granted all required permissions.');
      }

      if (error.response?.status === 404) {
        throw new Error(`Post not found or comments are not accessible for post ID: ${postId}`);
      }

      if (error.response?.status === 429) {
        throw new Error('Instagram API rate limit exceeded. Please try again later.');
      }

      throw new Error(`Failed to fetch Instagram comments: ${error.message}`);
    }
  }

  /**
   * Reply to an Instagram comment
   */
  async replyToComment(
    integrationId: string,
    commentId: string,
    message: string
  ): Promise<any> {
    // 1. Look up the integration by ID
    const integration = await this.getIntegration(integrationId);
    
    // 2. Validate integration
    this.validateIntegration(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { access_token } = integration.credentials;
    const { pageToken } = await this.resolveInstagramUserId(integration, access_token);
    
    // 4. Call Instagram Graph API to reply to comment
    const replyData = await this.postCommentReplyToAPI(commentId, message, pageToken);
    
    // 5. Return reply data
    return replyData;
  }

  /**
   * Create a new Instagram post
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
    const integration = await this.getIntegration(integrationId);
    
    // 2. Validate integration
    this.validateIntegration(integration);
    
    // 3. Extract credentials and resolve Instagram user ID
    const { access_token } = integration.credentials;
    const { igUserId, pageToken } = await this.resolveInstagramUserId(integration, access_token);
    
    // 4. Create the post via Instagram Graph API
    const postResult = await this.createInstagramPostToAPI(igUserId, postData, pageToken);
    
    // 5. Return post data
    return postResult;
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
      const url = `${this.GRAPH_API_BASE_URL}/${commentId}/replies`;
      const data = {
        message: message,
        access_token: accessToken,
      };

      this.logger.log(`🔍 Posting reply to comment: ${commentId}`);
      this.logger.log(`📊 Reply message length: ${message.length}`);

      const response: AxiosResponse = await axios.post(url, data);

      this.logger.log(`✅ Instagram Reply API response status: ${response.status}`);
      this.logger.log(`📱 Reply posted with ID: ${response.data?.id}`);

      return {
        id: response.data.id,
        message: 'Reply posted successfully'
      };
    } catch (error) {
      this.logger.error(`❌ Instagram Reply API error:`, {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        commentId: commentId,
      });

      if (error.response?.status === 400) {
        const errorData = error.response.data;
        if (errorData?.error?.message?.includes('comment')) {
          throw new Error(`Cannot reply to this comment: ${errorData?.error?.message || 'Comment may not exist or replies may not be allowed'}`);
        }
        throw new Error(`Invalid reply request: ${errorData?.error?.message || 'Bad request'}`);
      }

      if (error.response?.status === 403) {
        throw new Error('Insufficient permissions to reply to Instagram comments. Please ensure you have granted comment management permissions.');
      }

      if (error.response?.status === 404) {
        throw new Error(`Comment not found or not accessible: ${commentId}`);
      }

      if (error.response?.status === 429) {
        throw new Error('Instagram API rate limit exceeded. Please try again later.');
      }

      throw new Error(`Failed to post reply to Instagram comment: ${error.message}`);
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
    } catch (error) {
      this.logger.error(`❌ Instagram Post Creation error:`, {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        igUserId: igUserId,
      });

      if (error.response?.status === 400) {
        const errorData = error.response.data;
        if (errorData?.error?.message?.includes('media')) {
          throw new Error(`Invalid media: ${errorData?.error?.message || 'Media URL may be invalid or unsupported format'}`);
        }
        throw new Error(`Invalid post data: ${errorData?.error?.message || 'Bad request'}`);
      }

      if (error.response?.status === 403) {
        throw new Error('Insufficient permissions to create Instagram posts. Please ensure you have granted content publishing permissions.');
      }

      if (error.response?.status === 429) {
        throw new Error('Instagram API rate limit exceeded. Please try again later.');
      }

      throw new Error(`Failed to create Instagram post: ${error.message}`);
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
    const url = `${this.GRAPH_API_BASE_URL}/${igUserId}/media`;
    
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
      const childContainers = [];
      for (const child of postData.children) {
        const childData = {
          access_token: accessToken,
          media_url: child.media_url,
          is_carousel_item: true,
        };
        
        const childResponse = await axios.post(url, childData);
        childContainers.push(childResponse.data.id);
      }
      
      data.children = childContainers.join(',');
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
    }

    this.logger.log(`🔍 Creating media container for IG user: ${igUserId}`);
    this.logger.log(`📊 Media type: ${data.media_type}`);

    const response: AxiosResponse = await axios.post(url, data);

    this.logger.log(`✅ Media container created with ID: ${response.data.id}`);
    
    return response.data;
  }

  /**
   * Publish media container to Instagram
   */
  private async publishMediaContainer(
    igUserId: string,
    containerId: string,
    accessToken: string
  ): Promise<any> {
    const url = `${this.GRAPH_API_BASE_URL}/${igUserId}/media_publish`;
    const data = {
      creation_id: containerId,
      access_token: accessToken,
    };

    this.logger.log(`🔍 Publishing media container: ${containerId}`);

    const response: AxiosResponse = await axios.post(url, data);

    this.logger.log(`✅ Media published with ID: ${response.data.id}`);
    
    return response.data;
  }

  /**
   * TODO: Enhanced method to get media with engagement metrics
   * This would require additional API calls for each media item
   * to get insights/metrics, which needs instagram_manage_insights permission
   */
  private async getMediaInsights(mediaId: string, accessToken: string): Promise<{ like_count: number; comments_count: number }> {
    try {
      // This requires instagram_manage_insights permission
      const url = `${this.GRAPH_API_BASE_URL}/${mediaId}/insights`;
      const params = {
        metric: 'engagement,impressions,reach,saves',
        access_token: accessToken,
      };

      const response = await axios.get(url, { params });
      
      // Process insights data and extract like_count, comments_count if available
      // For now, return default values
      return { like_count: 0, comments_count: 0 };
    } catch (error) {
      this.logger.warn(`Failed to get insights for media ${mediaId}:`, error.message);
      return { like_count: 0, comments_count: 0 };
    }
  }
}
