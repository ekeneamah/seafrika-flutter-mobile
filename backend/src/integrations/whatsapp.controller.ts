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
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { WhatsAppService } from './whatsapp.service';
import { WhatsAppMessage, WhatsAppBusinessProfile } from './types/whatsapp.types';
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

@ApiTags('WhatsApp Integration')
@Controller('integrations/whatsapp')
@ApiBearerAuth()
export class WhatsAppController {
  private readonly logger = new Logger(WhatsAppController.name);

  constructor(private readonly whatsappService: WhatsAppService) {}

  @Post(':integrationId/send-message')
  @ApiOperation({ 
    summary: 'Send a WhatsApp message',
    description: 'Send a text, media, or template message via WhatsApp Business API'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        to: { type: 'string', description: 'Recipient phone number in international format' },
        type: { type: 'string', enum: ['text', 'image', 'document', 'audio', 'video', 'location', 'contacts'] },
        text: {
          type: 'object',
          properties: {
            body: { type: 'string' }
          }
        },
        context: {
          type: 'object',
          properties: {
            message_id: { type: 'string', description: 'ID of message to reply to' }
          }
        }
      },
      required: ['to', 'type']
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Message sent successfully',
    schema: {
      type: 'object',
      properties: {
        messaging_product: { type: 'string' },
        contacts: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              wa_id: { type: 'string' },
              profile: {
                type: 'object',
                properties: {
                  name: { type: 'string' }
                }
              }
            }
          }
        },
        messages: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              message_status: { type: 'string' }
            }
          }
        }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 404, description: 'Integration not found or inactive' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async sendMessage(
    @Param('integrationId') integrationId: string,
    @Body() messageData: { to: string; type: string; text?: any; image?: any; document?: any; audio?: any; video?: any; location?: any; contacts?: any; context?: any },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Sending WhatsApp message to ${messageData.to} via integration ${integrationId}`);
      
      const result = await this.whatsappService.sendMessage(
        integrationId,
        messageData.to,
        messageData as Partial<WhatsAppMessage>
      );

      return result;
    } catch (error) {
      this.logger.error(`Failed to send WhatsApp message:`, error);
      throw error;
    }
  }

  @Post(':integrationId/send-template')
  @ApiOperation({ 
    summary: 'Send a WhatsApp template message',
    description: 'Send a pre-approved template message via WhatsApp Business API'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        to: { type: 'string', description: 'Recipient phone number in international format' },
        templateName: { type: 'string', description: 'Name of the approved template' },
        language: { type: 'string', description: 'Language code (e.g., en_US)' },
        components: {
          type: 'array',
          description: 'Template components with parameters',
          items: {
            type: 'object',
            properties: {
              type: { type: 'string', enum: ['header', 'body', 'footer', 'button'] },
              parameters: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    type: { type: 'string' },
                    text: { type: 'string' }
                  }
                }
              }
            }
          }
        }
      },
      required: ['to', 'templateName', 'language']
    }
  })
  @ApiResponse({ status: 200, description: 'Template message sent successfully' })
  @ApiResponse({ status: 400, description: 'Bad request - invalid template or parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 404, description: 'Integration or template not found' })
  async sendTemplateMessage(
    @Param('integrationId') integrationId: string,
    @Body() templateData: { to: string; templateName: string; language: string; components?: any[] },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Sending WhatsApp template message to ${templateData.to} via integration ${integrationId}`);
      
      const result = await this.whatsappService.sendTemplateMessage(
        integrationId,
        templateData.to,
        templateData.templateName,
        templateData.language,
        templateData.components
      );

      return result;
    } catch (error) {
      this.logger.error(`Failed to send WhatsApp template message:`, error);
      throw error;
    }
  }

  @Get(':integrationId/templates')
  @ApiOperation({ 
    summary: 'Get WhatsApp message templates',
    description: 'Retrieve all approved message templates for the WhatsApp Business account'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Templates retrieved successfully',
    schema: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          name: { type: 'string' },
          category: { type: 'string' },
          status: { type: 'string' },
          language: { type: 'string' },
          components: { type: 'array' }
        }
      }
    }
  })
  async getTemplates(
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
      this.logger.log(`Retrieving WhatsApp templates for integration ${integrationId}`);
      
      const templates = await this.whatsappService.getTemplates(integrationId);
      return templates;
    } catch (error) {
      this.logger.error(`Failed to get WhatsApp templates:`, error);
      throw error;
    }
  }

  @Get(':integrationId/business-profile')
  @ApiOperation({ 
    summary: 'Get WhatsApp business profile',
    description: 'Retrieve the business profile information for the WhatsApp Business account'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Business profile retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        messaging_product: { type: 'string' },
        address: { type: 'string' },
        description: { type: 'string' },
        email: { type: 'string' },
        profile_picture_url: { type: 'string' },
        websites: { type: 'array', items: { type: 'string' } },
        vertical: { type: 'string' }
      }
    }
  })
  async getBusinessProfile(
    @Param('integrationId') integrationId: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<WhatsAppBusinessProfile> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Retrieving WhatsApp business profile for integration ${integrationId}`);
      
      const profile = await this.whatsappService.getBusinessProfile(integrationId);
      return profile;
    } catch (error) {
      this.logger.error(`Failed to get WhatsApp business profile:`, error);
      throw error;
    }
  }

  @Post(':integrationId/business-profile')
  @ApiOperation({ 
    summary: 'Update WhatsApp business profile',
    description: 'Update the business profile information for the WhatsApp Business account'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        address: { type: 'string' },
        description: { type: 'string' },
        email: { type: 'string' },
        websites: { type: 'array', items: { type: 'string' } },
        vertical: { 
          type: 'string',
          enum: ['UNDEFINED', 'OTHER', 'AUTO', 'BEAUTY', 'APPAREL', 'EDU', 'ENTERTAIN', 'EVENT_PLAN', 'FINANCE', 'GROCERY', 'GOVT', 'HOTEL', 'HEALTH', 'NONPROFIT', 'PROF_SERVICES', 'RETAIL', 'TRAVEL', 'RESTAURANT']
        }
      }
    }
  })
  @ApiResponse({ status: 200, description: 'Business profile updated successfully' })
  async updateBusinessProfile(
    @Param('integrationId') integrationId: string,
    @Body() profileData: Partial<WhatsAppBusinessProfile>,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Updating WhatsApp business profile for integration ${integrationId}`);
      
      const result = await this.whatsappService.updateBusinessProfile(integrationId, profileData);
      return result;
    } catch (error) {
      this.logger.error(`Failed to update WhatsApp business profile:`, error);
      throw error;
    }
  }

  @Get(':integrationId/analytics')
  @ApiOperation({ 
    summary: 'Get WhatsApp analytics',
    description: 'Retrieve analytics data for the WhatsApp Business account'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiQuery({ 
    name: 'start', 
    description: 'Start date in YYYY-MM-DD format' 
  })
  @ApiQuery({ 
    name: 'end', 
    description: 'End date in YYYY-MM-DD format' 
  })
  @ApiQuery({ 
    name: 'granularity', 
    required: false,
    enum: ['HALF_HOUR', 'DAY', 'MONTH'],
    description: 'Data granularity (default: DAY)' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Analytics retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        messaging_product: { type: 'string' },
        granularity: { type: 'string' },
        data_points: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              start: { type: 'number' },
              end: { type: 'number' },
              sent: { type: 'number' },
              delivered: { type: 'number' },
              read: { type: 'number' },
              failed: { type: 'number' }
            }
          }
        }
      }
    }
  })
  async getAnalytics(
    @Param('integrationId') integrationId: string,
    @Query('start') start: string,
    @Query('end') end: string,
    @Query('granularity') granularity: 'HALF_HOUR' | 'DAY' | 'MONTH' = 'DAY',
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Retrieving WhatsApp analytics for integration ${integrationId}`);
      
      const analytics = await this.whatsappService.getAnalytics(integrationId, start, end, granularity);
      return analytics;
    } catch (error) {
      this.logger.error(`Failed to get WhatsApp analytics:`, error);
      throw error;
    }
  }

  @Post(':integrationId/upload-media')
  @ApiOperation({ 
    summary: 'Upload media for WhatsApp',
    description: 'Upload an image, document, audio, or video file for use in WhatsApp messages'
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
        id: { type: 'string', description: 'Media ID for use in messages' }
      }
    }
  })
  @UseInterceptors(FileInterceptor('file'))
  async uploadMedia(
    @Param('integrationId') integrationId: string,
    @UploadedFile() file: Express.Multer.File,
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
      this.logger.log(`Uploading media file for integration ${integrationId}`);
      
      const result = await this.whatsappService.uploadMedia(
        integrationId,
        file.buffer,
        file.mimetype,
        file.originalname
      );
      
      return result;
    } catch (error) {
      this.logger.error(`Failed to upload media:`, error);
      throw error;
    }
  }

  @Post(':integrationId/mark-read/:messageId')
  @ApiOperation({ 
    summary: 'Mark message as read',
    description: 'Mark a WhatsApp message as read'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiParam({ 
    name: 'messageId', 
    description: 'The message ID to mark as read' 
  })
  @ApiResponse({ status: 200, description: 'Message marked as read successfully' })
  async markMessageAsRead(
    @Param('integrationId') integrationId: string,
    @Param('messageId') messageId: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    try {
      this.logger.log(`Marking WhatsApp message ${messageId} as read for integration ${integrationId}`);
      
      const result = await this.whatsappService.markMessageAsRead(integrationId, messageId);
      return result;
    } catch (error) {
      this.logger.error(`Failed to mark message as read:`, error);
      throw error;
    }
  }
}
