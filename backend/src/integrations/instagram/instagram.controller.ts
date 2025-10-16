import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Body,
  Headers,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery, ApiBody, ApiBearerAuth } from '@nestjs/swagger';
import { MetaIntegrationService } from '../shared/meta-integration.service';
import { FacebookService } from '../facebook/facebook.service';
import { FirestoreService } from '../../firebase/firestore.service';

@ApiTags('Instagram Integration')
@Controller('integrations/instagram')
@ApiBearerAuth()
export class InstagramController {
  private readonly logger = new Logger(InstagramController.name);

  constructor(
    private readonly metaIntegrationService: MetaIntegrationService,
    private readonly facebookService: FacebookService,
    private readonly firestoreService: FirestoreService,
  ) {}

  @Get(':integrationId/media')
  @ApiOperation({ 
    summary: 'Get Instagram media for an integration',
    description: 'Fetch Instagram posts/media for a given integration using the stored access token'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiQuery({ 
    name: 'limit', 
    required: false, 
    description: 'Number of media items to return (default: 25, max: 50)',
    type: Number
  })
  @ApiQuery({ 
    name: 'after', 
    required: false, 
    description: 'Pagination cursor for getting next page of results',
    type: String
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Media retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        data: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              media_type: { type: 'string', enum: ['IMAGE', 'VIDEO', 'CAROUSEL_ALBUM'] },
              media_url: { type: 'string' },
              thumbnail_url: { type: 'string' },
              caption: { type: 'string' },
              timestamp: { type: 'string' },
              permalink: { type: 'string' },
              like_count: { type: 'number' },
              comments_count: { type: 'number' }
            }
          }
        },
        paging: {
          type: 'object',
          properties: {
            cursors: {
              type: 'object',
              properties: {
                after: { type: 'string' }
              }
            },
            next: { type: 'string' }
          }
        }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 403, description: 'Forbidden - insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Integration not found or inactive' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async getInstagramMedia(
    @Param('integrationId') integrationId: string,
    @Query('limit') limit?: number,
    @Query('after') after?: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // TODO: Add proper JWT auth guard when implemented
    // For now, we'll validate the auth header exists
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!integrationId) {
      throw new HttpException(
        'Integration ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate limit parameter
    const parsedLimit = limit ? Math.min(Math.max(parseInt(String(limit)), 1), 50) : 25;

    try {
      this.logger.log(`Fetching Instagram media for integration: ${integrationId}`);
      
      const result = await this.metaIntegrationService.getInstagramMediaByIntegration(
        integrationId,
        parsedLimit,
        after
      );

      this.logger.log(`Successfully fetched ${result.data.length} media items`);
      
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch Instagram media: ${error.message}`, error.stack);
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Map common error types
      if (error.message.includes('not found')) {
        throw new HttpException(
          'Integration not found or inactive',
          HttpStatus.NOT_FOUND,
        );
      }
      
      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired Instagram access token',
          HttpStatus.UNAUTHORIZED,
        );
      }
      
      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Instagram API rate limit exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      
      throw new HttpException(
        'Failed to fetch Instagram media',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':integrationId/media/:postId/comments')
  @ApiOperation({ 
    summary: 'Get Instagram comments for a specific post',
    description: 'Fetch comments for a specific Instagram post using the stored access token'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiParam({ 
    name: 'postId', 
    description: 'The Instagram media/post ID' 
  })
  @ApiQuery({ 
    name: 'limit', 
    required: false, 
    description: 'Number of comments to return (default: 25, max: 50)',
    type: Number
  })
  @ApiQuery({ 
    name: 'after', 
    required: false, 
    description: 'Pagination cursor for getting next page of results',
    type: String
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Comments retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        data: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              text: { type: 'string' },
              username: { type: 'string' },
              timestamp: { type: 'string' },
              like_count: { type: 'number' },
              replies_count: { type: 'number' }
            }
          }
        },
        paging: {
          type: 'object',
          properties: {
            cursors: {
              type: 'object',
              properties: {
                after: { type: 'string' }
              }
            },
            next: { type: 'string' }
          }
        }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 403, description: 'Forbidden - insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Post not found or no comments available' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async getInstagramComments(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
    @Query('limit') limit?: number,
    @Query('after') after?: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!integrationId) {
      throw new HttpException(
        'Integration ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (!postId) {
      throw new HttpException(
        'Post ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate limit parameter
    const parsedLimit = limit ? Math.min(Math.max(parseInt(String(limit)), 1), 50) : 25;

    try {
      this.logger.log(`Fetching Instagram comments for post: ${postId} in integration: ${integrationId}`);
      
      const result = await this.metaIntegrationService.getInstagramComments(
        integrationId,
        postId,
        parsedLimit,
        after
      );

      this.logger.log(`Successfully fetched ${result.length} comments`);
      
      return {
        data: result,
        postId: postId
      };
    } catch (error) {
      this.logger.error(`Failed to fetch Instagram comments: ${error.message}`, error.stack);
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Map common error types
      if (error.message.includes('not found')) {
        throw new HttpException(
          'Post not found or no comments available',
          HttpStatus.NOT_FOUND,
        );
      }
      
      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired Instagram access token',
          HttpStatus.UNAUTHORIZED,
        );
      }
      
      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Instagram API rate limit exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      
      throw new HttpException(
        'Failed to fetch Instagram comments',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post(':integrationId/media/:postId/comments/:commentId/replies')
  @ApiOperation({ 
    summary: 'Reply to an Instagram comment',
    description: 'Post a reply to a specific Instagram comment using the stored access token'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiParam({ 
    name: 'postId', 
    description: 'The Instagram media/post ID' 
  })
  @ApiParam({ 
    name: 'commentId', 
    description: 'The comment ID to reply to' 
  })
  @ApiResponse({ 
    status: 201, 
    description: 'Reply posted successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        message: { type: 'string' }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters or message' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 403, description: 'Forbidden - insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Comment not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async replyToComment(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
    @Param('commentId') commentId: string,
    @Body() body: { message: string },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!integrationId || !postId || !commentId) {
      throw new HttpException(
        'Integration ID, Post ID, and Comment ID are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (!body.message || body.message.trim().length === 0) {
      throw new HttpException(
        'Reply message is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (body.message.length > 1000) {
      throw new HttpException(
        'Reply message cannot exceed 1000 characters',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      this.logger.log(`Replying to comment ${commentId} on post ${postId} in integration: ${integrationId}`);
      
      const result = await this.metaIntegrationService.replyToInstagramComment(
        integrationId,
        commentId,
        body.message.trim()
      );

      this.logger.log(`Successfully posted reply to comment ${commentId}`);
      
      return result;
    } catch (error) {
      this.logger.error(`Failed to reply to comment: ${error.message}`, error.stack);
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Map common error types
      if (error.message.includes('not found')) {
        throw new HttpException(
          'Comment not found or cannot be replied to',
          HttpStatus.NOT_FOUND,
        );
      }
      
      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired Instagram access token',
          HttpStatus.UNAUTHORIZED,
        );
      }
      
      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Instagram API rate limit exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      
      throw new HttpException(
        'Failed to reply to comment',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post(':integrationId/media')
  @ApiOperation({ 
    summary: 'Create a new Instagram post',
    description: 'Create a new Instagram media post (image or video) using the stored access token'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiResponse({ 
    status: 201, 
    description: 'Post created successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        permalink: { type: 'string' },
        message: { type: 'string' }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters or media' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 403, description: 'Forbidden - insufficient permissions' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async createInstagramPost(
    @Param('integrationId') integrationId: string,
    @Body() body: { 
      image_url?: string;
      video_url?: string;
      caption?: string;
      media_type?: 'IMAGE' | 'VIDEO' | 'CAROUSEL_ALBUM';
      children?: Array<{ media_url: string; media_type: 'IMAGE' | 'VIDEO' }>;
    },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!integrationId) {
      throw new HttpException(
        'Integration ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate media requirements
    if (!body.image_url && !body.video_url && !body.children) {
      throw new HttpException(
        'Either image_url, video_url, or children (for carousel) must be provided',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate caption length
    if (body.caption && body.caption.length > 2200) {
      throw new HttpException(
        'Caption cannot exceed 2200 characters',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      this.logger.log(`Creating Instagram post for integration: ${integrationId}`);
      
      // Use the enhanced createInstagramPost method that supports more media types
      const result = await this.metaIntegrationService.createInstagramPost(
        integrationId,
        {
          image_url: body.image_url,
          video_url: body.video_url,
          caption: body.caption,
          media_type: body.media_type,
          children: body.children
        }
      );

      this.logger.log(`Successfully created post with ID: ${result.id}`);
      
      return result;
    } catch (error) {
      this.logger.error(`Failed to create Instagram post: ${error.message}`, error.stack);
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Map common error types
      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired Instagram access token',
          HttpStatus.UNAUTHORIZED,
        );
      }
      
      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Instagram API rate limit exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      
      if (error.message.includes('media')) {
        throw new HttpException(
          'Invalid media URL or unsupported media format',
          HttpStatus.BAD_REQUEST,
        );
      }
      
      throw new HttpException(
        'Failed to create Instagram post',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':integrationId/profile')
  @ApiOperation({ 
    summary: 'Get Instagram profile information for an integration',
    description: 'Fetch Instagram business account profile data for a given integration'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Profile retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        username: { type: 'string' },
        name: { type: 'string' },
        biography: { type: 'string' },
        followers_count: { type: 'number' },
        follows_count: { type: 'number' },
        media_count: { type: 'number' },
        profile_picture_url: { type: 'string' },
        website: { type: 'string' },
        account_type: { type: 'string' }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 403, description: 'Forbidden - insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Integration not found or inactive' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async getInstagramProfile(
    @Param('integrationId') integrationId: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    this.logger.log(`Received request to fetch Instagram profile for integration: ${integrationId}`);
    this.logger.debug(`Authorization header: ${authHeader}`);
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      this.logger.error('XXX Missing or invalid Authorization header');
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!integrationId) {
      throw new HttpException(
        'Integration ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      this.logger.log(`Fetching Instagram profile for integration: ${integrationId}`);
      
      const result = await this.metaIntegrationService.getInstagramProfileByIntegration(integrationId);
      
      this.logger.log(`Successfully retrieved Instagram profile for integration: ${integrationId}`);
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch Instagram profile: ${error.message}`, error.stack);
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Map common error types
      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired Instagram access token',
          HttpStatus.UNAUTHORIZED,
        );
      }
      
      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Instagram API rate limit exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      
      throw new HttpException(
        'Failed to fetch Instagram profile',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
  /**
   * Send a direct message via Instagram
   * Sends a message to a recipient on Instagram and updates Firestore with the sent status
   */
  @Post(':integrationId/send-message')
  @ApiOperation({ 
    summary: 'Send Instagram direct message',
    description: 'Send a direct message to a recipient on Instagram. Supports text, images, and videos. Uses the same Facebook Graph API endpoint.'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiBody({
    description: 'Message data to send',
    schema: {
      type: 'object',
      required: ['messageId', 'conversationId', 'recipientId', 'message'],
      properties: {
        messageId: { 
          type: 'string', 
          description: 'The Firestore message document ID',
          example: 'msg_abc123'
        },
        conversationId: { 
          type: 'string', 
          description: 'The Firestore conversation ID',
          example: 'conv_xyz789'
        },
        recipientId: { 
          type: 'string', 
          description: 'The recipient\'s Instagram Scoped ID (IGSID)',
          example: '1234567890'
        },
        message: { 
          type: 'string', 
          description: 'The message text content',
          example: 'Hello! How can I help you today?'
        },
        messageType: { 
          type: 'string', 
          enum: ['text', 'image', 'video'],
          default: 'text',
          description: 'Type of message being sent'
        },
        attachmentUrl: { 
          type: 'string', 
          description: 'URL of attachment (required for non-text messages)',
          example: 'https://example.com/image.jpg'
        }
      }
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Message sent successfully',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message_id: { type: 'string', description: 'Platform message ID from Instagram' },
        recipient_id: { type: 'string', description: 'Recipient IGSID' },
        messageId: { type: 'string', description: 'Firestore message ID' }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - missing required fields' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 404, description: 'Integration not found' })
  @ApiResponse({ status: 500, description: 'Failed to send message' })
  async sendDirectMessage(
    @Param('integrationId') integrationId: string,
    @Body() body: {
      messageId: string;
      conversationId: string;
      recipientId: string;
      message: string;
      messageType?: 'text' | 'image' | 'video';
      attachmentUrl?: string;
    },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    // Validate required fields
    if (!integrationId || !body.messageId || !body.conversationId || !body.recipientId || !body.message) {
      throw new HttpException(
        'Missing required fields: integrationId, messageId, conversationId, recipientId, and message are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate attachment URL for non-text messages
    if (body.messageType && body.messageType !== 'text' && !body.attachmentUrl) {
      throw new HttpException(
        'attachmentUrl is required for non-text messages',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      this.logger.log(`Sending Instagram DM for integration: ${integrationId}, recipient: ${body.recipientId}`);

      // 1. Call FacebookService to send message via Meta Graph API
      // Instagram uses the same /me/messages endpoint as Messenger
      const result = await this.facebookService.sendMessage(
        integrationId,
        body.recipientId,
        body.message,
        body.messageType || 'text',
        body.attachmentUrl
      );

      this.logger.log(`Instagram DM sent successfully. Platform message_id: ${result.message_id}`);

      // 2. Update Firestore with sent status and platform message ID
      try {
        await this.firestoreService.updateDocument(
          'messages',
          body.messageId,
          {
            'metadata.status': 'sent',
            'metadata.platformMessageId': result.message_id,
            'metadata.sentAt': new Date(),
          }
        );
        this.logger.log(`Firestore updated for message: ${body.messageId}`);
      } catch (firestoreError) {
        // Log but don't fail the request if Firestore update fails
        this.logger.error(`Failed to update Firestore for message ${body.messageId}:`, firestoreError.message);
      }

      // 3. Return success response
      return {
        success: true,
        message_id: result.message_id,
        recipient_id: result.recipient_id,
        messageId: body.messageId,
      };

    } catch (error) {
      this.logger.error(`Failed to send Instagram DM: ${error.message}`, error.stack);

      // Update Firestore with failed status
      try {
        await this.firestoreService.updateDocument(
          'messages',
          body.messageId,
          {
            'metadata.status': 'failed',
            'metadata.error': error.message,
            'metadata.failedAt': new Date(),
          }
        );
      } catch (firestoreError) {
        this.logger.error(`Failed to update Firestore with error status:`, firestoreError.message);
      }

      if (error instanceof HttpException) {
        throw error;
      }

      // Map common Instagram/Facebook API errors
      if (error.message.includes('not found')) {
        throw new HttpException(
          'Integration or recipient not found',
          HttpStatus.NOT_FOUND,
        );
      }

      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired access token',
          HttpStatus.UNAUTHORIZED,
        );
      }

      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Instagram API rate limit exceeded. Please try again later.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      throw new HttpException(
        `Failed to send Instagram DM: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

