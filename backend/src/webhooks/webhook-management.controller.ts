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
import { MetaService } from './meta/meta.service';
// import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('Webhook Management')
@Controller('webhooks/management')
// @UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class WebhookManagementController {
  constructor(
    private readonly metaService: MetaService,
  ) {}

  @Get('meta/channels')
  @ApiOperation({ summary: 'Get available Meta integration channels' })
  @ApiResponse({ status: 200, description: 'Meta channels retrieved successfully' })
  async getMetaChannels() {
    return {
      success: true,
      data: this.metaService.getAllChannels(),
    };
  }

  @Get('meta/credentials/:businessId')
  @ApiOperation({ summary: 'Get Meta credentials status for business' })
  @ApiResponse({ status: 200, description: 'Credentials status retrieved successfully' })
  async getCredentialsStatus(@Param('businessId') businessId: string) {
    const integrations = await this.metaService.getBusinessIntegrations(businessId);
    
    // Get first Facebook integration for user-level info
    const facebookIntegration = integrations.find(i => 
      i.channel === 'facebook_pages' || i.channel === 'messenger'
    );
    
    const pagesCount = integrations.filter(i => i.credentials.pageInfo).length;
    
    return {
      success: true,
      data: {
        hasCredentials: integrations.length > 0,
        userId: facebookIntegration?.credentials?.userId,
        scopes: facebookIntegration?.credentials?.scopes || [],
        pagesCount: pagesCount,
        expiresAt: facebookIntegration?.credentials?.expiresAt,
        integrationsCount: integrations.length,
      },
    };
  }

  @Get('status')
  @ApiOperation({ summary: 'Get webhook service status' })
  @ApiResponse({ status: 200, description: 'Webhook status retrieved successfully' })
  async getWebhookStatus() {
    return {
      status: 'active',
      services: ['meta', 'whatsapp'],
      endpoints: {
        meta: {
          verification: '/webhooks/meta',
          notification: '/webhooks/meta',
          oauth: '/api/config/meta/oauth/redirect',
        },
        whatsapp: {
          verification: '/webhooks/whatsapp',
          notification: '/webhooks/whatsapp',
        },
      },
      timestamp: new Date().toISOString(),
    };
  }
}
