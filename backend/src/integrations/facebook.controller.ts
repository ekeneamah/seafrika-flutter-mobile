import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Query,
  Body,
  Headers,
  HttpException,
  HttpStatus,
  Logger,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { FacebookService } from './facebook.service';
import type { Express } from 'express';

declare global {
  namespace Express {
    namespace Multer {
      interface File {
        fieldname: string;
        originalname: string;
        encoding: string;
        mimetype: string;
        size: number;
        destination: string;
        filename: string;
        path: string;
        buffer: Buffer;
      }
    }
  }
}

@ApiTags('Facebook Integration')
@Controller('integrations/facebook')
@ApiBearerAuth()
export class FacebookController {
  private readonly logger = new Logger(FacebookController.name);

  constructor(private readonly facebookService: FacebookService) {}

  @Get(':integrationId/page-info')
  @ApiOperation({ 
    summary: 'Get Facebook page information',
    description: 'Retrieve detailed information about the connected Facebook page'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Page information retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        name: { type: 'string' },
        category: { type: 'string' },
        about: { type: 'string' },
        description: { type: 'string' },
        website: { type: 'string' },
        phone: { type: 'string' },
        email: { type: 'string' },
        fan_count: { type: 'number' },
        followers_count: { type: 'number' },
        link: { type: 'string' },
        username: { type: 'string' },
        is_verified: { type: 'boolean' }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 404, description: 'Integration not found or inactive' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async getPageInfo(
    @Param('integrationId') integrationId: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Retrieving Facebook page info for integration ${integrationId}`);
      
      const pageInfo = await this.facebookService.getPageInfo(integrationId);
      return pageInfo;
    } catch (error) {
      this.logger.error(`Failed to get Facebook page info:`, error);
      throw error;
    }
  }

  @Get(':integrationId/posts')
  @ApiOperation({ 
    summary: 'Get Facebook page posts',
    description: 'Retrieve posts from the connected Facebook page'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiQuery({ 
    name: 'limit', 
    required: false, 
    description: 'Number of posts to return (default: 25, max: 100)',
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
    description: 'Posts retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        data: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              message: { type: 'string' },
              created_time: { type: 'string' },
              type: { type: 'string' },
              permalink_url: { type: 'string' },
              full_picture: { type: 'string' },
              reactions: { type: 'object' },
              comments: { type: 'object' },
              likes: { type: 'object' }
            }
          }
        },
        paging: { type: 'object' }
      }
    }
  })
  async getPagePosts(
    @Param('integrationId') integrationId: string,
    @Query('limit') limit?: number,
    @Query('after') after?: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Retrieving Facebook posts for integration ${integrationId}`);
      
      const posts = await this.facebookService.getPagePosts(
        integrationId,
        limit || 25,
        after
      );
      return posts;
    } catch (error) {
      this.logger.error(`Failed to get Facebook posts:`, error);
      throw error;
    }
  }

  @Post(':integrationId/posts')
  @ApiOperation({ 
    summary: 'Create a Facebook post',
    description: 'Create a new post on the connected Facebook page'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Post message text' },
        link: { type: 'string', description: 'URL to share' },
        mediaIds: { 
          type: 'array', 
          items: { type: 'string' },
          description: 'Array of uploaded media IDs'
        },
        scheduledPublishTime: { 
          type: 'number', 
          description: 'Unix timestamp for scheduled publishing'
        }
      }
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Post created successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        post_id: { type: 'string' }
      }
    }
  })
  async createPost(
    @Param('integrationId') integrationId: string,
    @Body() postData: { 
      message?: string; 
      link?: string; 
      mediaIds?: string[];
      scheduledPublishTime?: number;
    },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Creating Facebook post for integration ${integrationId}`);
      
      const result = await this.facebookService.createPost(
        integrationId,
        postData.message,
        postData.link,
        postData.mediaIds,
        postData.scheduledPublishTime
      );
      return result;
    } catch (error) {
      this.logger.error(`Failed to create Facebook post:`, error);
      throw error;
    }
  }

  @Get(':integrationId/posts/:postId/comments')
  @ApiOperation({ 
    summary: 'Get post comments',
    description: 'Retrieve comments for a specific Facebook post'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiParam({ 
    name: 'postId', 
    description: 'The Facebook post ID' 
  })
  @ApiQuery({ 
    name: 'limit', 
    required: false, 
    description: 'Number of comments to return (default: 25)',
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
              message: { type: 'string' },
              created_time: { type: 'string' },
              from: { type: 'object' },
              like_count: { type: 'number' },
              comment_count: { type: 'number' }
            }
          }
        },
        paging: { type: 'object' }
      }
    }
  })
  async getPostComments(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
    @Query('limit') limit?: number,
    @Query('after') after?: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Retrieving comments for Facebook post ${postId}`);
      
      const comments = await this.facebookService.getPostComments(
        integrationId,
        postId,
        limit || 25,
        after
      );
      return comments;
    } catch (error) {
      this.logger.error(`Failed to get Facebook post comments:`, error);
      throw error;
    }
  }

  @Post(':integrationId/comments/:commentId/reply')
  @ApiOperation({ 
    summary: 'Reply to a comment',
    description: 'Reply to a comment on a Facebook post'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiParam({ 
    name: 'commentId', 
    description: 'The Facebook comment ID' 
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Reply message' }
      },
      required: ['message']
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Reply sent successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' }
      }
    }
  })
  async replyToComment(
    @Param('integrationId') integrationId: string,
    @Param('commentId') commentId: string,
    @Body() replyData: { message: string },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Replying to Facebook comment ${commentId}`);
      
      const result = await this.facebookService.replyToComment(
        integrationId,
        commentId,
        replyData.message
      );
      return result;
    } catch (error) {
      this.logger.error(`Failed to reply to Facebook comment:`, error);
      throw error;
    }
  }

  @Get(':integrationId/insights')
  @ApiOperation({ 
    summary: 'Get page insights',
    description: 'Retrieve analytics and insights for the Facebook page'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiQuery({ 
    name: 'metrics', 
    description: 'Comma-separated list of metrics (e.g., page_impressions,page_reach)',
    type: String
  })
  @ApiQuery({ 
    name: 'period', 
    description: 'Time period for the metrics',
    enum: ['day', 'week', 'days_28', 'month', 'lifetime']
  })
  @ApiQuery({ 
    name: 'since', 
    required: false,
    description: 'Start date (YYYY-MM-DD)',
    type: String
  })
  @ApiQuery({ 
    name: 'until', 
    required: false,
    description: 'End date (YYYY-MM-DD)',
    type: String
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Insights retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        data: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              period: { type: 'string' },
              values: { type: 'array' },
              title: { type: 'string' },
              description: { type: 'string' }
            }
          }
        }
      }
    }
  })
  async getPageInsights(
    @Param('integrationId') integrationId: string,
    @Query('metrics') metrics: string,
    @Query('period') period: 'day' | 'week' | 'days_28' | 'month' | 'lifetime',
    @Query('since') since?: string,
    @Query('until') until?: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Retrieving Facebook page insights for integration ${integrationId}`);
      
      const insights = await this.facebookService.getPageInsights(
        integrationId,
        metrics.split(','),
        period,
        since,
        until
      );
      return insights;
    } catch (error) {
      this.logger.error(`Failed to get Facebook page insights:`, error);
      throw error;
    }
  }

  @Post(':integrationId/upload-media')
  @ApiOperation({ 
    summary: 'Upload media to Facebook',
    description: 'Upload an image or video to Facebook for use in posts'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
          description: 'Media file to upload'
        },
        published: {
          type: 'boolean',
          description: 'Whether to publish immediately (default: false)'
        }
      }
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Media uploaded successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string', description: 'Media ID for use in posts' }
      }
    }
  })
  @UseInterceptors(FileInterceptor('file'))
  async uploadMedia(
    @Param('integrationId') integrationId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body('published') published?: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!file) {
      throw new HttpException('No file uploaded', HttpStatus.BAD_REQUEST);
    }

    try {
      this.logger.log(`Uploading media file for Facebook integration ${integrationId}`);
      
      const result = await this.facebookService.uploadMedia(
        integrationId,
        file.buffer,
        file.mimetype,
        file.originalname,
        published === 'true'
      );
      
      return result;
    } catch (error) {
      this.logger.error(`Failed to upload media to Facebook:`, error);
      throw error;
    }
  }

  @Delete(':integrationId/posts/:postId')
  @ApiOperation({ 
    summary: 'Delete a Facebook post',
    description: 'Delete a post from the connected Facebook page'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiParam({ 
    name: 'postId', 
    description: 'The Facebook post ID to delete' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Post deleted successfully',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' }
      }
    }
  })
  async deletePost(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Deleting Facebook post ${postId} for integration ${integrationId}`);
      
      const result = await this.facebookService.deletePost(integrationId, postId);
      return result;
    } catch (error) {
      this.logger.error(`Failed to delete Facebook post:`, error);
      throw error;
    }
  }

  @Post(':integrationId/comments/:commentId/moderate')
  @ApiOperation({ 
    summary: 'Moderate a comment',
    description: 'Hide or unhide a comment on a Facebook post'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiParam({ 
    name: 'commentId', 
    description: 'The Facebook comment ID' 
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        hide: { type: 'boolean', description: 'Whether to hide (true) or unhide (false) the comment' }
      },
      required: ['hide']
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Comment moderated successfully',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' }
      }
    }
  })
  async moderateComment(
    @Param('integrationId') integrationId: string,
    @Param('commentId') commentId: string,
    @Body() moderationData: { hide: boolean },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Moderating Facebook comment ${commentId}`);
      
      const result = await this.facebookService.moderateComment(
        integrationId,
        commentId,
        moderationData.hide
      );
      return result;
    } catch (error) {
      this.logger.error(`Failed to moderate Facebook comment:`, error);
      throw error;
    }
  }

  @Get(':integrationId/messages')
  @ApiOperation({ 
    summary: 'Get page messages',
    description: 'Retrieve conversations and messages for the Facebook page'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiQuery({ 
    name: 'limit', 
    required: false, 
    description: 'Number of conversations to return (default: 25)',
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
    description: 'Messages retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        data: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              participants: { type: 'object' },
              senders: { type: 'object' },
              can_reply: { type: 'boolean' },
              message_count: { type: 'number' },
              unread_count: { type: 'number' }
            }
          }
        }
      }
    }
  })
  async getPageMessages(
    @Param('integrationId') integrationId: string,
    @Query('limit') limit?: number,
    @Query('after') after?: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Retrieving Facebook page messages for integration ${integrationId}`);
      
      const messages = await this.facebookService.getPageMessages(
        integrationId,
        limit || 25,
        after
      );
      return messages;
    } catch (error) {
      this.logger.error(`Failed to get Facebook page messages:`, error);
      throw error;
    }
  }
}
