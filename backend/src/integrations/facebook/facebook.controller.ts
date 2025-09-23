import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Query,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery, ApiBody } from '@nestjs/swagger';
import { MetaIntegrationService } from '../shared/meta-integration.service';

@ApiTags('Facebook Integration')
@Controller('integrations/facebook')
export class FacebookController {
  constructor(private readonly metaIntegrationService: MetaIntegrationService) {}

  @Get(':integrationId/page-info')
  @ApiOperation({ summary: 'Get Facebook page information' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Page information retrieved successfully' })
  @ApiResponse({ status: 404, description: 'Integration not found' })
  async getPageInfo(@Param('integrationId') integrationId: string) {
    try {
      return await this.metaIntegrationService.getPageInfo(integrationId);
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
  @ApiQuery({ name: 'pageId', description: 'Specific page ID', required: false })
  @ApiResponse({ status: 200, description: 'Posts retrieved successfully' })
  async getPagePosts(
    @Param('integrationId') integrationId: string,
    @Query('limit') limit?: number,
    @Query('pageId') pageId?: string,
  ) {
    try {
      return await this.metaIntegrationService.getPagePosts(integrationId, pageId, limit || 25);
    } catch (error) {
      throw new HttpException(
        `Failed to get page posts: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/posts')
  @ApiOperation({ summary: 'Create a Facebook page post' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'Post message' },
        imageUrl: { type: 'string', description: 'Optional image URL' },
        pageId: { type: 'string', description: 'Optional specific page ID' },
      },
      required: ['message'],
    },
  })
  async createPost(
    @Param('integrationId') integrationId: string,
    @Body() postData: { message: string; imageUrl?: string; pageId?: string },
  ) {
    try {
      return await this.metaIntegrationService.postToFacebookPage(
        integrationId,
        postData.message,
        postData.pageId,
        postData.imageUrl
      );
    } catch (error) {
      throw new HttpException(
        `Failed to create post: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/insights')
  @ApiOperation({ summary: 'Get Facebook page insights' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiQuery({ name: 'period', description: 'Time period (day, week, days_28)', required: false })
  @ApiQuery({ name: 'pageId', description: 'Specific page ID', required: false })
  @ApiResponse({ status: 200, description: 'Page insights retrieved successfully' })
  async getPageInsights(
    @Param('integrationId') integrationId: string,
    @Query('period') period?: string,
    @Query('pageId') pageId?: string,
  ) {
    try {
      const validPeriod = ['day', 'week', 'days_28'].includes(period) ? period : 'day';
      return await this.metaIntegrationService.getPageInsights(integrationId, pageId, validPeriod);
    } catch (error) {
      throw new HttpException(
        `Failed to get page insights: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/available-pages')
  @ApiOperation({ summary: 'Get available Facebook pages' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Available pages retrieved successfully' })
  async getAvailablePages(@Param('integrationId') integrationId: string) {
    try {
      return await this.metaIntegrationService.getAvailablePages(integrationId);
    } catch (error) {
      throw new HttpException(
        `Failed to get available pages: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Get(':integrationId/validate-credentials')
  @ApiOperation({ summary: 'Validate Facebook integration credentials' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Credentials validation result' })
  async validateCredentials(@Param('integrationId') integrationId: string) {
    try {
      const isValid = await this.metaIntegrationService.validateCredentials(integrationId);
      return { valid: isValid };
    } catch (error) {
      throw new HttpException(
        `Failed to validate credentials: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Post(':integrationId/refresh-tokens')
  @ApiOperation({ summary: 'Refresh access tokens' })
  @ApiParam({ name: 'integrationId', description: 'Integration ID' })
  @ApiResponse({ status: 200, description: 'Tokens refreshed successfully' })
  async refreshTokens(@Param('integrationId') integrationId: string) {
    try {
      await this.metaIntegrationService.refreshTokens(integrationId);
      return { message: 'Tokens refreshed successfully' };
    } catch (error) {
      throw new HttpException(
        `Failed to refresh tokens: ${error.message}`,
        HttpStatus.BAD_REQUEST,
      );
    }
  }
}