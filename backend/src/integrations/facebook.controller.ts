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

  @Post('auth')
  @ApiOperation({ summary: 'Authenticate with Facebook' })
  @ApiResponse({ status: 200, description: 'Authentication successful' })
  @ApiResponse({ status: 400, description: 'Invalid authentication code' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        code: { type: 'string', description: 'OAuth authorization code' },
        redirectUri: { type: 'string', description: 'OAuth redirect URI' },
      },
      required: ['code', 'redirectUri'],
    },
  })
  async authenticateFacebook(
    @Body() body: { code: string; redirectUri: string },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.authenticateUser(body.code, body.redirectUri, businessId);
    } catch (error) {
      throw new HttpException(
        `Facebook authentication failed: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get('user/profile')
  @ApiOperation({ summary: 'Get user Facebook profile' })
  @ApiResponse({ status: 200, description: 'Profile retrieved successfully' })
  @ApiResponse({ status: 401, description: 'User not authenticated with Facebook' })
  async getUserProfile(@Headers('business-id') businessId: string) {
    try {
      return await this.facebookService.getUserProfile(businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to get user profile: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get('user/pages')
  @ApiOperation({ summary: 'Get user Facebook pages' })
  @ApiResponse({ status: 200, description: 'Pages retrieved successfully' })
  @ApiResponse({ status: 401, description: 'User not authenticated with Facebook' })
  async getUserPages(@Headers('business-id') businessId: string) {
    try {
      return await this.facebookService.getUserPages(businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to get user pages: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('pages/:pageId/subscribe-webhook')
  @ApiOperation({ summary: 'Subscribe page to webhooks' })
  @ApiParam({ name: 'pageId', description: 'Facebook Page ID' })
  @ApiResponse({ status: 200, description: 'Webhook subscription successful' })
  @ApiResponse({ status: 400, description: 'Failed to subscribe to webhooks' })
  async subscribePageWebhooks(
    @Param('pageId') pageId: string,
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.subscribeToPageWebhooks(pageId, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to subscribe to webhooks: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get('pages/:pageId/roles')
  @ApiOperation({ summary: 'Get page roles and permissions' })
  @ApiParam({ name: 'pageId', description: 'Facebook Page ID' })
  @ApiResponse({ status: 200, description: 'Page roles retrieved successfully' })
  async getPageRoles(
    @Param('pageId') pageId: string,
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.getPageRoles(pageId, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to get page roles: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('share/timeline')
  @ApiOperation({ summary: 'Share content to Facebook timeline' })
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
    @Body() shareData: { message: string; link?: string; imageUrl?: string },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.shareToTimeline(shareData, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to share to timeline: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('pages/:pageId/posts')
  @ApiOperation({ summary: 'Create post on Facebook page' })
  @ApiParam({ name: 'pageId', description: 'Facebook Page ID' })
  @ApiResponse({ status: 200, description: 'Post created successfully' })
  @ApiResponse({ status: 400, description: 'Failed to create post' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Post message' },
        link: { type: 'string', description: 'Optional link to share' },
        imageUrl: { type: 'string', description: 'Optional image URL' },
        published: { type: 'boolean', description: 'Whether to publish immediately', default: true },
      },
      required: ['message'],
    },
  })
  async createPagePost(
    @Param('pageId') pageId: string,
    @Body() postData: { message: string; link?: string; imageUrl?: string; published?: boolean },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.createPagePost(pageId, postData, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to create page post: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('pages/:pageId/photos')
  @ApiOperation({ summary: 'Upload photo to Facebook page' })
  @ApiParam({ name: 'pageId', description: 'Facebook Page ID' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 200, description: 'Photo uploaded successfully' })
  @ApiResponse({ status: 400, description: 'Failed to upload photo' })
  @UseInterceptors(FileInterceptor('photo'))
  async uploadPagePhoto(
    @Param('pageId') pageId: string,
    @UploadedFile() photo: Express.Multer.File,
    @Body() data: { caption?: string; published?: boolean },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.uploadPagePhoto(pageId, photo, data, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to upload photo: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('pages/:pageId/videos')
  @ApiOperation({ summary: 'Upload video to Facebook page' })
  @ApiParam({ name: 'pageId', description: 'Facebook Page ID' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 200, description: 'Video uploaded successfully' })
  @ApiResponse({ status: 400, description: 'Failed to upload video' })
  @UseInterceptors(FileInterceptor('video'))
  async uploadPageVideo(
    @Param('pageId') pageId: string,
    @UploadedFile() video: Express.Multer.File,
    @Body() data: { title?: string; description?: string; published?: boolean },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.uploadPageVideo(pageId, video, data, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to upload video: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get('pages/:pageId/insights')
  @ApiOperation({ summary: 'Get Facebook page insights' })
  @ApiParam({ name: 'pageId', description: 'Facebook Page ID' })
  @ApiQuery({ name: 'metric', description: 'Specific metrics to retrieve', required: false })
  @ApiQuery({ name: 'period', description: 'Time period for insights', required: false })
  @ApiResponse({ status: 200, description: 'Insights retrieved successfully' })
  async getPageInsights(
    @Param('pageId') pageId: string,
    @Query('metric') metric?: string,
    @Query('period') period?: string,
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.getPageInsights(pageId, { metric, period }, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to get page insights: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('messages/send')
  @ApiOperation({ summary: 'Send Facebook Messenger message' })
  @ApiResponse({ status: 200, description: 'Message sent successfully' })
  @ApiResponse({ status: 400, description: 'Failed to send message' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        recipientId: { type: 'string', description: 'Recipient user ID' },
        message: { type: 'string', description: 'Message text' },
        pageId: { type: 'string', description: 'Page ID to send from' },
      },
      required: ['recipientId', 'message', 'pageId'],
    },
  })
  async sendMessage(
    @Body() messageData: { recipientId: string; message: string; pageId: string },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.sendMessage(
        messageData.pageId,
        messageData.recipientId,
        messageData.message,
        businessId,
      );
    } catch (error) {
      throw new HttpException(
        `Failed to send message: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get('conversations/:conversationId/messages')
  @ApiOperation({ summary: 'Get conversation messages' })
  @ApiParam({ name: 'conversationId', description: 'Conversation ID' })
  @ApiQuery({ name: 'limit', description: 'Number of messages to retrieve', required: false })
  @ApiResponse({ status: 200, description: 'Messages retrieved successfully' })
  async getConversationMessages(
    @Param('conversationId') conversationId: string,
    @Query('limit') limit?: number,
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.getConversationMessages(conversationId, limit, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to get conversation messages: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('posts/:postId/like')
  @ApiOperation({ summary: 'Toggle like on Facebook post' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiResponse({ status: 200, description: 'Like toggled successfully' })
  @ApiResponse({ status: 400, description: 'Failed to toggle like' })
  async toggleLike(
    @Param('postId') postId: string,
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.toggleLike(postId, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to toggle like: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('posts/:postId/reactions')
  @ApiOperation({ summary: 'Add reaction to Facebook post' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiResponse({ status: 200, description: 'Reaction added successfully' })
  @ApiResponse({ status: 400, description: 'Failed to add reaction' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        type: { 
          type: 'string', 
          enum: ['LIKE', 'LOVE', 'WOW', 'HAHA', 'SAD', 'ANGRY'],
          description: 'Reaction type' 
        },
      },
      required: ['type'],
    },
  })
  async addReaction(
    @Param('postId') postId: string,
    @Body() reactionData: { type: 'LIKE' | 'LOVE' | 'WOW' | 'HAHA' | 'SAD' | 'ANGRY' },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.addReaction(postId, reactionData.type, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to add reaction: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post('posts/:postId/comments')
  @ApiOperation({ summary: 'Comment on Facebook post' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiResponse({ status: 200, description: 'Comment added successfully' })
  @ApiResponse({ status: 400, description: 'Failed to add comment' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Comment message' },
        pageId: { type: 'string', description: 'Page ID to comment from (optional)' },
      },
      required: ['message'],
    },
  })
  async commentOnPost(
    @Param('postId') postId: string,
    @Body() commentData: { message: string; pageId?: string },
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.commentOnPost(postId, commentData, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to comment on post: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get('pages/:pageId/posts')
  @ApiOperation({ summary: 'Get Facebook page posts' })
  @ApiParam({ name: 'pageId', description: 'Facebook Page ID' })
  @ApiQuery({ name: 'limit', description: 'Number of posts to retrieve', required: false })
  @ApiQuery({ name: 'fields', description: 'Specific fields to retrieve', required: false })
  @ApiResponse({ status: 200, description: 'Posts retrieved successfully' })
  async getPagePosts(
    @Param('pageId') pageId: string,
    @Query('limit') limit?: number,
    @Query('fields') fields?: string,
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.getPagePosts(pageId, { limit, fields }, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to get page posts: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Delete('posts/:postId')
  @ApiOperation({ summary: 'Delete Facebook post' })
  @ApiParam({ name: 'postId', description: 'Facebook Post ID' })
  @ApiResponse({ status: 200, description: 'Post deleted successfully' })
  @ApiResponse({ status: 400, description: 'Failed to delete post' })
  async deletePost(
    @Param('postId') postId: string,
    @Headers('business-id') businessId: string,
  ) {
    try {
      return await this.facebookService.deletePost(postId, businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to delete post: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Delete('auth')
  @ApiOperation({ summary: 'Disconnect Facebook integration' })
  @ApiResponse({ status: 200, description: 'Facebook disconnected successfully' })
  @ApiResponse({ status: 400, description: 'Failed to disconnect Facebook' })
  async disconnectFacebook(@Headers('business-id') businessId: string) {
    try {
      return await this.facebookService.disconnectUser(businessId);
    } catch (error) {
      throw new HttpException(
        `Failed to disconnect Facebook: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }
}
