import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { InstagramWebhookService } from './instagram-webhook.service';
// import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('Webhook Management')
@Controller('webhooks/management')
// @UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class WebhookManagementController {
  constructor(
    private readonly instagramWebhookService: InstagramWebhookService,
  ) {}

  @Get('instagram/events/:accountId')
  @ApiOperation({ summary: 'Get Instagram webhook events for an account' })
  @ApiResponse({ status: 200, description: 'Webhook events retrieved successfully' })
  async getInstagramEvents(
    @Param('accountId') accountId: string,
    @Query('limit') limit?: number,
  ) {
    return this.instagramWebhookService.getWebhookEvents(
      accountId,
      limit || 50,
    );
  }

  @Get('instagram/media/:accountId')
  @ApiOperation({ summary: 'Get Instagram media events for an account' })
  @ApiResponse({ status: 200, description: 'Media events retrieved successfully' })
  async getInstagramMediaEvents(
    @Param('accountId') accountId: string,
    @Query('limit') limit?: number,
  ) {
    return this.instagramWebhookService.getMediaEvents(
      accountId,
      limit || 50,
    );
  }

  @Get('status')
  @ApiOperation({ summary: 'Get webhook service status' })
  @ApiResponse({ status: 200, description: 'Webhook status retrieved successfully' })
  async getWebhookStatus() {
    return {
      status: 'active',
      services: ['instagram'],
      endpoints: {
        instagram: {
          verification: '/api/webhooks/instagram',
          notification: '/api/webhooks/instagram',
          test: '/api/webhooks/instagram/test',
        },
      },
      timestamp: new Date().toISOString(),
    };
  }
}
