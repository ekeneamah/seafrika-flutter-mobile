import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Query,
  UseInterceptors,
  UploadedFile,
  Headers,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiConsumes, ApiParam, ApiQuery, ApiBody } from '@nestjs/swagger';
import { FacebookService } from './facebook.service';

@ApiTags('Facebook Integration')
@Controller('integrations/facebook')
export class FacebookController {
  constructor(private readonly facebookService: FacebookService) {}

  @Get(':integrationId/page-info')
  @ApiOperation({ summary: 'Get Facebook page information' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Page information retrieved successfully' })
  @ApiResponse({ status: 404, description: 'Integration not found' })
  async getPageInfo(@Param('integrationId') integrationId: string) {
    try {
      return await this.facebookService.getPageInfo(integrationId);
    } catch (error) {
      throw new HttpException(
        `Failed to get page info: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/posts')
  @ApiOperation({ summary: 'Get Facebook page posts' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiQuery({ name: 'limit', description: 'Number of posts to retrieve', required: false })
  @ApiQuery({ name: 'after', description: 'Pagination cursor', required: false })
  @ApiResponse({ status: 200, description: 'Posts retrieved successfully' })
  async getPagePosts(
    @Param('integrationId') integrationId: string,
    @Query('limit') limit?: number,
    @Query('after') after?: string,
  ) {
    try {
      return await this.facebookService.getPagePosts(integrationId, limit || 25, after);
    } catch (error) {
      throw new HttpException(
        `Failed to get page posts: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/posts')
  @ApiOperation({ summary: 'Create post on Facebook page' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Post created successfully' })
  @ApiResponse({ status: 400, description: 'Failed to create post' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Post message' },
        link: { type: 'string', description: 'Optional link to share' },
        imageUrl: { type: 'string', description: 'Optional image URL' },
        scheduledTime: { type: 'string', description: 'Optional scheduled publish time' },
      },
      required: ['message'],
    },
  })
  async createPost(
    @Param('integrationId') integrationId: string,
    @Body() postData: { message: string; link?: string; imageUrl?: string; scheduledTime?: string },
  ) {
    try {
      const mediaIds = postData.imageUrl ? [postData.imageUrl] : undefined;
      const scheduledTime = postData.scheduledTime ? new Date(postData.scheduledTime).getTime() : undefined;
      
      return await this.facebookService.createPost(
        integrationId,
        postData.message,
        postData.link,
        mediaIds,
        scheduledTime,
      );
    } catch (error) {
      throw new HttpException(
        `Failed to create post: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/upload-media')
  @ApiOperation({ summary: 'Upload media to Facebook page' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 200, description: 'Media uploaded successfully' })
  @ApiResponse({ status: 400, description: 'Failed to upload media' })
  @UseInterceptors(FileInterceptor('file'))
  async uploadMedia(
    @Param('integrationId') integrationId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body() data: { caption?: string; description?: string },
  ) {
    try {
      return await this.facebookService.uploadMedia(
        integrationId, 
        file.buffer, 
        file.mimetype, 
        file.originalname,
        true
      );
    } catch (error) {
      throw new HttpException(
        `Failed to upload media: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/insights')
  @ApiOperation({ summary: 'Get Facebook page insights' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiQuery({ name: 'metrics', description: 'Comma-separated list of metrics', required: false })
  @ApiQuery({ name: 'period', description: 'Time period for insights', required: false })
  @ApiResponse({ status: 200, description: 'Insights retrieved successfully' })
  async getPageInsights(
    @Param('integrationId') integrationId: string,
    @Query('metrics') metrics?: string,
    @Query('period') period?: string,
  ) {
    try {
      const metricsArray = metrics ? metrics.split(',') : ['page_impressions', 'page_reach', 'page_engaged_users'];
      const validPeriod = period as 'day' | 'week' | 'days_28' | 'month' | 'lifetime' || 'day';
      return await this.facebookService.getPageInsights(integrationId, metricsArray, validPeriod);
    } catch (error) {
      throw new HttpException(
        `Failed to get page insights: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/messages/send')
  @ApiOperation({ summary: 'Send Facebook Messenger message' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Message sent successfully' })
  @ApiResponse({ status: 400, description: 'Failed to send message' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        recipientId: { type: 'string', description: 'Recipient user ID' },
        message: { type: 'string', description: 'Message text' },
        messageType: { 
          type: 'string', 
          enum: ['text', 'image', 'video', 'audio', 'file'],
          description: 'Message type',
          default: 'text',
        },
        attachmentUrl: { type: 'string', description: 'URL for media attachments' },
      },
      required: ['recipientId', 'message'],
    },
  })
  async sendMessage(
    @Param('integrationId') integrationId: string,
    @Body() messageData: { 
      recipientId: string; 
      message: string; 
      messageType?: 'text' | 'image' | 'video' | 'audio' | 'file';
      attachmentUrl?: string;
    },
  ) {
    try {
      return await this.facebookService.sendMessage(
        integrationId,
        messageData.recipientId,
        messageData.message,
        messageData.messageType || 'text',
        messageData.attachmentUrl,
      );
    } catch (error) {
      throw new HttpException(
        `Failed to send message: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/conversations/:conversationId/messages')
  @ApiOperation({ summary: 'Get conversation messages' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiParam({ name: 'conversationId', description: 'Conversation ID' })
  @ApiQuery({ name: 'limit', description: 'Number of messages to retrieve', required: false })
  @ApiResponse({ status: 200, description: 'Messages retrieved successfully' })
  async getConversationMessages(
    @Param('integrationId') integrationId: string,
    @Param('conversationId') conversationId: string,
    @Query('limit') limit?: number,
  ) {
    try {
      return await this.facebookService.getConversationMessages(integrationId, conversationId, limit);
    } catch (error) {
      throw new HttpException(
        `Failed to get conversation messages: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/share-timeline')
  @ApiOperation({ summary: 'Share content to Facebook timeline' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Content shared successfully' })
  @ApiResponse({ status: 400, description: 'Failed to share content' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Post message' },
        link: { type: 'string', description: 'Optional link to share' },
        imageUrl: { type: 'string', description: 'Optional image URL' },
      },
      required: ['message'],
    },
  })
  async shareToTimeline(
    @Param('integrationId') integrationId: string,
    @Body() shareData: { message: string; link?: string; imageUrl?: string },
  ) {
    try {
      return await this.facebookService.shareToTimeline(
        integrationId,
        {
          message: shareData.message,
          link: shareData.link,
          mediaId: shareData.imageUrl,
        }
      );
    } catch (error) {
      throw new HttpException(
        `Failed to share to timeline: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/posts/:postId/like')
  @ApiOperation({ summary: 'Toggle like on Facebook post' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiResponse({ status: 200, description: 'Like toggled successfully' })
  @ApiResponse({ status: 400, description: 'Failed to toggle like' })
  async toggleLike(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
  ) {
    try {
      return await this.facebookService.toggleLike(integrationId, postId);
    } catch (error) {
      throw new HttpException(
        `Failed to toggle like: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/posts/:postId/reactions')
  @ApiOperation({ summary: 'Add reaction to Facebook post' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiResponse({ status: 200, description: 'Reaction added successfully' })
  @ApiResponse({ status: 400, description: 'Failed to add reaction' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        type: { 
          type: 'string', 
          enum: ['LIKE', 'LOVE', 'WOW', 'HAHA', 'SAD', 'ANGRY', 'THANKFUL'],
          description: 'Reaction type' 
        },
      },
      required: ['type'],
    },
  })
  async addReaction(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
    @Body() reactionData: { type: 'LIKE' | 'LOVE' | 'WOW' | 'HAHA' | 'SAD' | 'ANGRY' | 'THANKFUL' },
  ) {
    try {
      return await this.facebookService.addReaction(integrationId, postId, reactionData.type);
    } catch (error) {
      throw new HttpException(
        `Failed to add reaction: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/posts/:postId/comments')
  @ApiOperation({ summary: 'Reply to comment on Facebook post' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiParam({ name: 'postId', description: 'Facebook Post/Comment ID' })
  @ApiResponse({ status: 200, description: 'Comment reply added successfully' })
  @ApiResponse({ status: 400, description: 'Failed to add comment reply' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Reply message' },
      },
      required: ['message'],
    },
  })
  async replyToComment(
    @Param('integrationId') integrationId: string,
    @Param('postId') commentId: string,
    @Body() commentData: { message: string },
  ) {
    try {
      return await this.facebookService.replyToComment(integrationId, commentId, commentData.message);
    } catch (error) {
      throw new HttpException(
        `Failed to reply to comment: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/posts/:postId/comments')
  @ApiOperation({ summary: 'Get comments on Facebook post' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiQuery({ name: 'limit', description: 'Number of comments to retrieve', required: false })
  @ApiResponse({ status: 200, description: 'Comments retrieved successfully' })
  async getPostComments(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
    @Query('limit') limit?: number,
  ) {
    try {
      return await this.facebookService.getPostComments(integrationId, postId, limit);
    } catch (error) {
      throw new HttpException(
        `Failed to get post comments: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Delete(':integrationId/posts/:postId')
  @ApiOperation({ summary: 'Delete Facebook post' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiResponse({ status: 200, description: 'Post deleted successfully' })
  @ApiResponse({ status: 400, description: 'Failed to delete post' })
  async deletePost(
    @Param('integrationId') integrationId: string,
    @Param('postId') postId: string,
  ) {
    try {
      return await this.facebookService.deletePost(integrationId, postId);
    } catch (error) {
      throw new HttpException(
        `Failed to delete post: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/messages')
  @ApiOperation({ summary: 'Get Facebook page messages' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiQuery({ name: 'limit', description: 'Number of messages to retrieve', required: false })
  @ApiResponse({ status: 200, description: 'Messages retrieved successfully' })
  async getPageMessages(
    @Param('integrationId') integrationId: string,
    @Query('limit') limit?: number,
  ) {
    try {
      return await this.facebookService.getPageMessages(integrationId, limit);
    } catch (error) {
      throw new HttpException(
        `Failed to get page messages: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/comments/:commentId/moderate')
  @ApiOperation({ summary: 'Moderate Facebook comment' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiParam({ name: 'commentId', description: 'Comment ID' })
  @ApiResponse({ status: 200, description: 'Comment moderated successfully' })
  @ApiResponse({ status: 400, description: 'Failed to moderate comment' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        action: { 
          type: 'string', 
          enum: ['hide', 'unhide', 'delete'],
          description: 'Moderation action' 
        },
      },
      required: ['action'],
    },
  })
  async moderateComment(
    @Param('integrationId') integrationId: string,
    @Param('commentId') commentId: string,
    @Body() moderationData: { action: 'hide' | 'unhide' | 'delete' },
  ) {
    try {
      const hide = moderationData.action === 'hide';
      return await this.facebookService.moderateComment(integrationId, commentId, hide);
    } catch (error) {
      throw new HttpException(
        `Failed to moderate comment: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/user-profile')
  @ApiOperation({ summary: 'Get user Facebook profile' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Profile retrieved successfully' })
  @ApiResponse({ status: 401, description: 'User not authenticated with Facebook' })
  async getUserProfile(@Param('integrationId') integrationId: string) {
    try {
      const integration = await this.facebookService['getIntegration'](integrationId);
      const accessToken = integration.credentials.access_token;
      return await this.facebookService.getUserProfile(accessToken);
    } catch (error) {
      throw new HttpException(
        `Failed to get user profile: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/user-pages')
  @ApiOperation({ summary: 'Get user Facebook pages' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Pages retrieved successfully' })
  @ApiResponse({ status: 401, description: 'User not authenticated with Facebook' })
  async getUserPages(@Param('integrationId') integrationId: string) {
    try {
      const integration = await this.facebookService['getIntegration'](integrationId);
      const accessToken = integration.credentials.access_token;
      return await this.facebookService.getUserPages(accessToken);
    } catch (error) {
      throw new HttpException(
        `Failed to get user pages: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/webhook-subscription')
  @ApiOperation({ summary: 'Subscribe page to webhooks' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Webhook subscription successful' })
  @ApiResponse({ status: 400, description: 'Failed to subscribe to webhooks' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        subscriptions: { 
          type: 'array',
          items: { type: 'string' },
          description: 'Array of webhook subscriptions',
          default: ['messages', 'messaging_postbacks', 'messaging_optins', 'message_deliveries'],
        },
      },
    },
  })
  async subscribeToPageWebhooks(
    @Param('integrationId') integrationId: string,
    @Body() subscriptionData: { subscriptions?: string[] },
  ) {
    try {
      const subscriptions = subscriptionData.subscriptions || [
        'messages', 
        'messaging_postbacks', 
        'messaging_optins', 
        'message_deliveries'
      ];
      return await this.facebookService.subscribeToPageWebhooks(integrationId, subscriptions);
    } catch (error) {
      throw new HttpException(
        `Failed to subscribe to webhooks: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/page-roles')
  @ApiOperation({ summary: 'Get page roles and permissions' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Page roles retrieved successfully' })
  async getPageRoles(@Param('integrationId') integrationId: string) {
    try {
      return await this.facebookService.getPageRoles(integrationId);
    } catch (error) {
      throw new HttpException(
        `Failed to get page roles: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }
}
