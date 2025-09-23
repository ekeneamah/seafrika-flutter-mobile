import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../firestore/firestore.service';
import { MetaService } from '../webhooks/meta/meta.service';
import axios from 'axios';

// Types for integration operations
interface FacebookPage {
  id: string;
  name: string;
  access_token?: string;
  category?: string;
  about?: string;
  followers_count?: number;
  fan_count?: number;
}

interface FacebookPost {
  id: string;
  message?: string;
  story?: string;
  created_time: string;
  updated_time?: string;
  likes?: number;
  comments?: number;
  shares?: number;
}

interface InstagramMedia {
  id: string;
  media_type: 'IMAGE' | 'VIDEO' | 'CAROUSEL_ALBUM';
  media_url?: string;
  thumbnail_url?: string;
  caption?: string;
  timestamp: string;
  like_count?: number;
  comments_count?: number;
}

interface InstagramAccount {
  id: string;
  username: string;
  name?: string;
  biography?: string;
  followers_count?: number;
  follows_count?: number;
  media_count?: number;
  profile_picture_url?: string;
}

@Injectable()
export class MetaIntegrationService {
  private readonly logger = new Logger(MetaIntegrationService.name);
  private readonly graphApiVersion = this.configService.get<string>('META_GRAPH_API_VERSION', 'v21.0');
  private readonly baseUrl = `https://graph.facebook.com/${this.graphApiVersion}`;

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
    private readonly metaService: MetaService, // Use the unified Meta service for auth
  ) {}

  // ===============================
  // FACEBOOK PAGE OPERATIONS
  // ===============================

  async getFacebookPageInfo(integrationId: string): Promise<FacebookPage> {
    const credentials = await this.getIntegrationCredentials(integrationId);
    const pageToken = await this.getPageAccessToken(credentials, integrationId);

    try {
      const response = await axios.get(`${this.baseUrl}/${credentials.pageId}`, {
        params: {
          access_token: pageToken,
          fields: 'id,name,category,about,followers_count,fan_count',
        },
      });

      return response.data;
    } catch (error) {
      this.logger.error(`Failed to get Facebook page info: ${error.message}`);
      throw new HttpException(
        'Failed to retrieve Facebook page information',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  async getFacebookPagePosts(
    integrationId: string,
    options: { limit?: number; after?: string } = {},
  ): Promise<{ data: FacebookPost[]; paging?: any }> {
    const credentials = await this.getIntegrationCredentials(integrationId);
    const pageToken = await this.getPageAccessToken(credentials, integrationId);

    try {
      const params: any = {
        access_token: pageToken,
        fields: 'id,message,story,created_time,updated_time,likes.summary(true),comments.summary(true),shares',
        limit: Math.min(options.limit || 25, 100),
      };

      if (options.after) {
        params.after = options.after;
      }

      const response = await axios.get(`${this.baseUrl}/${credentials.pageId}/posts`, { params });

      return {
        data: response.data.data,
        paging: response.data.paging,
      };
    } catch (error) {
      this.logger.error(`Failed to get Facebook posts: ${error.message}`);
      throw new HttpException(
        'Failed to retrieve Facebook posts',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  // ===============================
  // INSTAGRAM BUSINESS OPERATIONS
  // ===============================

  async getInstagramMedia(
    integrationId: string,
    options: { limit?: number; after?: string } = {},
  ): Promise<{ data: InstagramMedia[]; paging?: any }> {
    const credentials = await this.getIntegrationCredentials(integrationId);
    const instagramAccount = await this.getInstagramBusinessAccount(credentials);

    try {
      const params: any = {
        access_token: credentials.userAccessToken,
        fields: 'id,media_type,media_url,thumbnail_url,caption,timestamp,like_count,comments_count',
        limit: Math.min(options.limit || 25, 50),
      };

      if (options.after) {
        params.after = options.after;
      }

      const response = await axios.get(`${this.baseUrl}/${instagramAccount.id}/media`, { params });

      return {
        data: response.data.data,
        paging: response.data.paging,
      };
    } catch (error) {
      this.logger.error(`Failed to get Instagram media: ${error.message}`);
      throw new HttpException(
        'Failed to retrieve Instagram media',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  async getInstagramAccountInfo(integrationId: string): Promise<InstagramAccount> {
    const credentials = await this.getIntegrationCredentials(integrationId);
    const instagramAccount = await this.getInstagramBusinessAccount(credentials);

    try {
      const response = await axios.get(`${this.baseUrl}/${instagramAccount.id}`, {
        params: {
          access_token: credentials.userAccessToken,
          fields: 'id,username,name,biography,followers_count,follows_count,media_count,profile_picture_url',
        },
      });

      return response.data;
    } catch (error) {
      this.logger.error(`Failed to get Instagram account info: ${error.message}`);
      throw new HttpException(
        'Failed to retrieve Instagram account information',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  // ===============================
  // MESSENGER OPERATIONS
  // ===============================

  async getMessengerConversations(
    integrationId: string,
    options: { limit?: number } = {},
  ): Promise<{ data: any[]; paging?: any }> {
    const credentials = await this.getIntegrationCredentials(integrationId);
    const pageToken = await this.getPageAccessToken(credentials, integrationId);

    try {
      const params: any = {
        access_token: pageToken,
        fields: 'id,participants,senders,updated_time',
        limit: Math.min(options.limit || 25, 100),
      };

      const response = await axios.get(`${this.baseUrl}/${credentials.pageId}/conversations`, { params });

      return {
        data: response.data.data,
        paging: response.data.paging,
      };
    } catch (error) {
      this.logger.error(`Failed to get Messenger conversations: ${error.message}`);
      throw new HttpException(
        'Failed to retrieve Messenger conversations',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  // ===============================
  // UNIFIED STATUS & PERMISSIONS
  // ===============================

  async getIntegrationStatus(integrationId: string): Promise<any> {
    try {
      const credentials = await this.getIntegrationCredentials(integrationId);
      
      return {
        integrationId,
        status: 'active',
        connectedPlatforms: credentials.integrations.map(i => i.type),
        lastUpdated: credentials.updatedAt,
        expiresAt: credentials.expiresAt,
      };
    } catch (error) {
      this.logger.error(`Failed to get integration status: ${error.message}`);
      throw new HttpException(
        'Failed to retrieve integration status',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  async getGrantedPermissions(integrationId: string): Promise<any> {
    try {
      const credentials = await this.getIntegrationCredentials(integrationId);
      
      return {
        integrationId,
        scopes: credentials.scopes,
        platforms: credentials.integrations,
      };
    } catch (error) {
      this.logger.error(`Failed to get granted permissions: ${error.message}`);
      throw new HttpException(
        'Failed to retrieve granted permissions',
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  // ===============================
  // HELPER METHODS
  // ===============================

  private async getIntegrationCredentials(integrationId: string): Promise<any> {
    try {
      const doc = await this.firestoreService.doc(`integrations/${integrationId}`).get();
      
      if (!doc.exists) {
        throw new HttpException('Integration not found', HttpStatus.NOT_FOUND);
      }

      const data = doc.data();
      if (!data?.credentials) {
        throw new HttpException('Integration credentials not found', HttpStatus.BAD_REQUEST);
      }

      return data.credentials;
    } catch (error) {
      this.logger.error(`Failed to get integration credentials: ${error.message}`);
      throw error;
    }
  }

  private async getPageAccessToken(credentials: any, integrationId: string): Promise<string> {
    // Find the page access token from the credentials
    const pageIntegration = credentials.integrations?.find((i: any) => i.type === 'facebook_pages');
    
    if (!pageIntegration?.pageAccessToken) {
      throw new HttpException(
        'Facebook page access token not found for this integration',
        HttpStatus.BAD_REQUEST,
      );
    }

    return pageIntegration.pageAccessToken;
  }

  private async getInstagramBusinessAccount(credentials: any): Promise<{ id: string }> {
    // Find the Instagram business account from the credentials
    const instagramIntegration = credentials.integrations?.find((i: any) => i.type === 'instagram');
    
    if (!instagramIntegration?.accountId) {
      throw new HttpException(
        'Instagram business account not found for this integration',
        HttpStatus.BAD_REQUEST,
      );
    }

    return { id: instagramIntegration.accountId };
  }
}