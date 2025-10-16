import { IsString, IsNotEmpty, IsOptional, IsObject } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class QueueMessageDto {
  @ApiProperty({ description: 'Message ID from Firestore' })
  @IsString()
  @IsNotEmpty()
  messageId: string;

  @ApiProperty({ description: 'Conversation ID' })
  @IsString()
  @IsNotEmpty()
  conversationId: string;

  @ApiProperty({ description: 'Business ID' })
  @IsString()
  @IsNotEmpty()
  businessId: string;

  @ApiProperty({ description: 'Integration ID' })
  @IsString()
  @IsNotEmpty()
  integrationId: string;

  @ApiProperty({ description: 'Platform (messenger, instagram, whatsapp)' })
  @IsString()
  @IsNotEmpty()
  platform: string;

  @ApiProperty({ description: 'Recipient ID' })
  @IsString()
  @IsNotEmpty()
  recipientId: string;

  @ApiProperty({ description: 'Message text content' })
  @IsString()
  @IsOptional()
  message?: string;

  @ApiProperty({ description: 'Message type (text, image, video, etc.)' })
  @IsString()
  @IsOptional()
  messageType?: string;

  @ApiProperty({ description: 'Attachment URL' })
  @IsString()
  @IsOptional()
  attachmentUrl?: string;

  @ApiProperty({ description: 'Additional metadata' })
  @IsObject()
  @IsOptional()
  metadata?: Record<string, any>;

  @ApiProperty({ description: 'Reason for queueing' })
  @IsString()
  @IsOptional()
  reason?: string;
}
