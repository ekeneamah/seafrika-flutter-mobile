import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../firestore/firestore.service';
import axios, { AxiosResponse } from 'axios';
import { 
  FacebookPage,
  FacebookPost,
  FacebookPageInsights,
  FacebookComment,
  FacebookMediaUpload,
  FacebookCredentials,
  FacebookIntegrationDocument
} from './types/facebook.types';

@Injectable()
export class FacebookService {
  private readonly logger = new Logger(FacebookService.name);
  private readonly FACEBOOK_API_BASE_URL = 'https://graph.facebook.com/v21.0';

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Get Facebook page information
   */
  async getPageInfo(integrationId: string): Promise<FacebookPage> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token, page_id } = integration.credentials;

    try {
      const response = await axios.get(
        `${this.FACEBOOK_API_BASE_URL}/${page_id}`,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
          },
          params: {
            fields: 'id,name,category,category_list,about,description,website,phone,email,location,cover,picture,fan_count,followers_count,link,username,verification_status,is_published,is_verified,tasks,instagram_business_account',
          },
        }
      );

      this.logger.log(`Retrieved Facebook page info for ${page_id}`);
      return response.data;
    } catch (error) {
      this.logger.error('Failed to get Facebook page info:', error.response?.data || error);
      throw new HttpException(
        `Failed to get Facebook page info: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get Facebook page posts
   */
  async getPagePosts(
    integrationId: string,
    limit: number = 25,
    after?: string
  ): Promise<{ data: FacebookPost[]; paging?: any }> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token, page_id } = integration.credentials;

    try {
      const response = await axios.get(
        `${this.FACEBOOK_API_BASE_URL}/${page_id}/posts`,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
          },
          params: {
            fields: 'id,message,story,created_time,updated_time,type,status_type,permalink_url,full_picture,picture,source,description,name,caption,link,object_id,parent_id,place,privacy,shares,reactions.summary(total_count),comments.summary(total_count),likes.summary(total_count)',
            limit,
            after,
          },
        }
      );

      this.logger.log(`Retrieved ${response.data.data.length} Facebook posts`);
      return response.data;
    } catch (error) {
      this.logger.error('Failed to get Facebook posts:', error.response?.data || error);
      throw new HttpException(
        `Failed to get Facebook posts: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Create a Facebook post
   */
  async createPost(
    integrationId: string,
    message?: string,
    link?: string,
    mediaIds?: string[],
    scheduledPublishTime?: number
  ): Promise<{ id: string; post_id: string }> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token, page_id } = integration.credentials;

    try {
      const payload: any = {};
      
      if (message) {
        payload.message = message;
      }
      
      if (link) {
        payload.link = link;
      }
      
      if (mediaIds && mediaIds.length > 0) {
        if (mediaIds.length === 1) {
          payload.object_attachment = mediaIds[0];
        } else {
          // Multiple media items - create carousel
          payload.child_attachments = mediaIds.map(id => ({ media_fbid: id }));
        }
      }
      
      if (scheduledPublishTime) {
        payload.scheduled_publish_time = scheduledPublishTime;
        payload.published = false;
      }

      const response = await axios.post(
        `${this.FACEBOOK_API_BASE_URL}/${page_id}/feed`,
        payload,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log(`Created Facebook post: ${response.data.id}`);
      return response.data;
    } catch (error) {
      this.logger.error('Failed to create Facebook post:', error.response?.data || error);
      throw new HttpException(
        `Failed to create Facebook post: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get post comments
   */
  async getPostComments(
    integrationId: string,
    postId: string,
    limit: number = 25,
    after?: string
  ): Promise<{ data: FacebookComment[]; paging?: any }> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token } = integration.credentials;

    try {
      const response = await axios.get(
        `${this.FACEBOOK_API_BASE_URL}/${postId}/comments`,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
          },
          params: {
            fields: 'id,message,created_time,from,like_count,comment_count,parent,attachment,can_comment,can_remove,can_hide,can_like,can_reply_privately',
            limit,
            after,
            order: 'reverse_chronological',
          },
        }
      );

      this.logger.log(`Retrieved ${response.data.data.length} comments for post ${postId}`);
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to get comments for post ${postId}:`, error.response?.data || error);
      throw new HttpException(
        `Failed to get post comments: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Reply to a comment
   */
  async replyToComment(
    integrationId: string,
    commentId: string,
    message: string
  ): Promise<{ id: string }> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token } = integration.credentials;

    try {
      const response = await axios.post(
        `${this.FACEBOOK_API_BASE_URL}/${commentId}/comments`,
        {
          message,
        },
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log(`Replied to comment ${commentId}`);
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to reply to comment ${commentId}:`, error.response?.data || error);
      throw new HttpException(
        `Failed to reply to comment: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get page insights/analytics
   */
  async getPageInsights(
    integrationId: string,
    metrics: string[],
    period: 'day' | 'week' | 'days_28' | 'month' | 'lifetime',
    since?: string,
    until?: string
  ): Promise<FacebookPageInsights> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token, page_id } = integration.credentials;

    try {
      const params: any = {
        metric: metrics.join(','),
        period,
      };

      if (since) params.since = since;
      if (until) params.until = until;

      const response = await axios.get(
        `${this.FACEBOOK_API_BASE_URL}/${page_id}/insights`,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
          },
          params,
        }
      );

      this.logger.log(`Retrieved Facebook page insights for ${metrics.length} metrics`);
      return response.data;
    } catch (error) {
      this.logger.error('Failed to get Facebook page insights:', error.response?.data || error);
      throw new HttpException(
        `Failed to get page insights: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Upload media to Facebook
   */
  async uploadMedia(
    integrationId: string,
    mediaFile: Buffer,
    mimeType: string,
    filename?: string,
    published: boolean = false
  ): Promise<FacebookMediaUpload> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token, page_id } = integration.credentials;

    try {
      const formData = new FormData();
      // Convert Buffer to Uint8Array for proper Blob creation
      const bufferData = Buffer.isBuffer(mediaFile) ? mediaFile : Buffer.from(mediaFile);
      const uint8Array = new Uint8Array(bufferData);
      const blob = new Blob([uint8Array], { type: mimeType });
      formData.append('source', blob, filename);
      formData.append('published', published.toString());

      const endpoint = mimeType.startsWith('image/') ? 'photos' : 'videos';
      
      const response = await axios.post(
        `${this.FACEBOOK_API_BASE_URL}/${page_id}/${endpoint}`,
        formData,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
            'Content-Type': 'multipart/form-data',
          },
        }
      );

      this.logger.log(`Media uploaded to Facebook: ${response.data.id}`);
      return response.data;
    } catch (error) {
      this.logger.error('Failed to upload media to Facebook:', error.response?.data || error);
      throw new HttpException(
        `Failed to upload media to Facebook: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Delete a post
   */
  async deletePost(integrationId: string, postId: string): Promise<{ success: boolean }> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token } = integration.credentials;

    try {
      const response = await axios.delete(
        `${this.FACEBOOK_API_BASE_URL}/${postId}`,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
          },
        }
      );

      this.logger.log(`Deleted Facebook post: ${postId}`);
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to delete post ${postId}:`, error.response?.data || error);
      throw new HttpException(
        `Failed to delete post: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Hide/unhide a comment
   */
  async moderateComment(
    integrationId: string,
    commentId: string,
    hide: boolean
  ): Promise<{ success: boolean }> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token } = integration.credentials;

    try {
      const response = await axios.post(
        `${this.FACEBOOK_API_BASE_URL}/${commentId}`,
        {
          is_hidden: hide,
        },
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log(`${hide ? 'Hidden' : 'Unhidden'} comment: ${commentId}`);
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to moderate comment ${commentId}:`, error.response?.data || error);
      throw new HttpException(
        `Failed to moderate comment: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get page messages (if page messaging is enabled)
   */
  async getPageMessages(
    integrationId: string,
    limit: number = 25,
    after?: string
  ): Promise<any> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { page_access_token, page_id } = integration.credentials;

    try {
      const response = await axios.get(
        `${this.FACEBOOK_API_BASE_URL}/${page_id}/conversations`,
        {
          headers: {
            'Authorization': `Bearer ${page_access_token}`,
          },
          params: {
            fields: 'participants,senders,can_reply,message_count,updated_time,unread_count',
            limit,
            after,
          },
        }
      );

      this.logger.log(`Retrieved ${response.data.data.length} Facebook conversations`);
      return response.data;
    } catch (error) {
      this.logger.error('Failed to get Facebook page messages:', error.response?.data || error);
      throw new HttpException(
        `Failed to get page messages: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Private helper methods
   */
  private async getIntegration(integrationId: string): Promise<FacebookIntegrationDocument> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const integrationDoc = await integrationsCollection.doc(integrationId).get();
      
      if (!integrationDoc.exists) {
        this.logger.warn(`Integration not found: ${integrationId}`);
        throw new HttpException('Integration not found', HttpStatus.NOT_FOUND);
      }

      const integration = integrationDoc.data() as FacebookIntegrationDocument;
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

  private validateIntegration(integration: FacebookIntegrationDocument): void {
    if (integration.platformId !== 'facebook') {
      this.logger.warn(`Invalid platform for integration ${integration.id}: ${integration.platformId}`);
      throw new HttpException(
        'Integration is not a Facebook integration',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (integration.status !== 'active') {
      this.logger.warn(`Integration ${integration.id} is not active: ${integration.status}`);
      throw new HttpException('Integration is not active', HttpStatus.BAD_REQUEST);
    }

    if (!integration.credentials?.page_access_token || !integration.credentials?.page_id) {
      this.logger.warn(`Integration ${integration.id} missing required credentials`);
      throw new HttpException('Integration missing required credentials', HttpStatus.BAD_REQUEST);
    }
  }
}
