import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNumber, IsArray, ValidateNested, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';

export class InstagramChange {
  @ApiProperty({ description: 'The field that changed (e.g., media, comments, mentions)' })
  @IsString()
  field: string;

  @ApiProperty({ description: 'The new value or data about the change' })
  value: any;
}

export class InstagramEntry {
  @ApiProperty({ description: 'Instagram account ID' })
  @IsString()
  id: string;

  @ApiProperty({ description: 'Unix timestamp when the change occurred' })
  @IsNumber()
  time: number;

  @ApiProperty({ description: 'Array of changes that occurred', type: [InstagramChange] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => InstagramChange)
  changes: InstagramChange[];
}

export class InstagramWebhookDto {
  @ApiProperty({ description: 'Object type (always "instagram")' })
  @IsString()
  object: string;

  @ApiProperty({ description: 'Array of webhook entries', type: [InstagramEntry] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => InstagramEntry)
  entry: InstagramEntry[];
}

export class InstagramMediaWebhookValue {
  @ApiProperty({ description: 'Media ID' })
  @IsString()
  media_id: string;

  @ApiProperty({ description: 'Media type (IMAGE, VIDEO, CAROUSEL_ALBUM)' })
  @IsOptional()
  @IsString()
  media_type?: string;

  @ApiProperty({ description: 'Media URL' })
  @IsOptional()
  @IsString()
  media_url?: string;

  @ApiProperty({ description: 'Caption text' })
  @IsOptional()
  @IsString()
  caption?: string;

  @ApiProperty({ description: 'Permalink to the media' })
  @IsOptional()
  @IsString()
  permalink?: string;

  @ApiProperty({ description: 'Timestamp when media was created' })
  @IsOptional()
  @IsString()
  timestamp?: string;
}

export class InstagramCommentWebhookValue {
  @ApiProperty({ description: 'Comment ID' })
  @IsString()
  comment_id: string;

  @ApiProperty({ description: 'Media ID the comment belongs to' })
  @IsString()
  media_id: string;

  @ApiProperty({ description: 'Comment text' })
  @IsOptional()
  @IsString()
  text?: string;

  @ApiProperty({ description: 'User who made the comment' })
  @IsOptional()
  from?: {
    id: string;
    username: string;
  };

  @ApiProperty({ description: 'Timestamp when comment was created' })
  @IsOptional()
  @IsString()
  timestamp?: string;
}

export class InstagramMentionWebhookValue {
  @ApiProperty({ description: 'Mention ID' })
  @IsString()
  mention_id: string;

  @ApiProperty({ description: 'Media ID where the mention occurred' })
  @IsString()
  media_id: string;

  @ApiProperty({ description: 'Comment ID if mention was in a comment' })
  @IsOptional()
  @IsString()
  comment_id?: string;

  @ApiProperty({ description: 'User who made the mention' })
  @IsOptional()
  from?: {
    id: string;
    username: string;
  };
}
