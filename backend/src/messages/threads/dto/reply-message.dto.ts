import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsArray, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class MessageAttachmentDto {
  @ApiProperty({ description: 'Attachment type (image, video, document, audio)' })
  @IsString()
  type: string;

  @ApiProperty({ description: 'Attachment URL' })
  @IsString()
  url: string;

  @ApiProperty({ description: 'Thumbnail URL', required: false })
  @IsOptional()
  @IsString()
  thumbnailUrl?: string;

  @ApiProperty({ description: 'File name', required: false })
  @IsOptional()
  @IsString()
  filename?: string;
}

export class ReplyMessageDto {
  @ApiProperty({
    description: 'Message content text',
    example: 'This is a reply to your message',
  })
  @IsString()
  @IsNotEmpty()
  content: string;

  @ApiProperty({
    description: 'ID of the parent message being replied to',
    example: 'msg_12345',
  })
  @IsString()
  @IsNotEmpty()
  parentMessageId: string;

  @ApiProperty({
    description: 'Conversation ID',
    example: 'conv_67890',
  })
  @IsString()
  @IsNotEmpty()
  conversationId: string;

  @ApiProperty({
    description: 'Sender user ID',
    example: 'user_abc123',
  })
  @IsString()
  @IsNotEmpty()
  senderId: string;

  @ApiProperty({
    description: 'Platform (instagram, messenger, whatsapp, app)',
    example: 'app',
    required: false,
  })
  @IsOptional()
  @IsString()
  platform?: string;

  @ApiProperty({
    description: 'Array of attachments',
    type: [MessageAttachmentDto],
    required: false,
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => MessageAttachmentDto)
  attachments?: MessageAttachmentDto[];
}

export class ThreadResponseDto {
  @ApiProperty({ description: 'Parent message ID' })
  parentMessageId: string;

  @ApiProperty({ description: 'Total number of replies' })
  replyCount: number;

  @ApiProperty({ description: 'Thread messages', type: 'array' })
  messages: any[];

  @ApiProperty({ description: 'Thread depth level' })
  threadDepth: number;
}
