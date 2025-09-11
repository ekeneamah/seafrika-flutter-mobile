import { IsString, IsOptional, IsArray, IsObject, IsNumber, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class FacebookPostDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  type?: string;

  @ApiProperty()
  @IsNumber()
  created_time: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  message?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  link?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  picture?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  video?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsArray()
  photos?: string[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  status_type?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsNumber()
  updated_time?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  permalink_url?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  promotion_status?: string;
}

export class FacebookFromDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty()
  @IsString()
  name: string;
}

export class FacebookShareDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty()
  @IsString()
  link: string;
}

export class FacebookWebhookValueDto {
  @ApiProperty()
  @IsString()
  item: string;

  @ApiProperty()
  @IsString()
  verb: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  post_id?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  comment_id?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  parent_id?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsNumber()
  created_time?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  message?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => FacebookFromDto)
  from?: FacebookFromDto;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => FacebookPostDto)
  post?: FacebookPostDto;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  reaction_type?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => FacebookShareDto)
  share?: FacebookShareDto;
}

export class FacebookWebhookChangeDto {
  @ApiProperty()
  @IsObject()
  @ValidateNested()
  @Type(() => FacebookWebhookValueDto)
  value: FacebookWebhookValueDto;

  @ApiProperty()
  @IsString()
  field: string;
}

export class FacebookWebhookEntryDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty()
  @IsNumber()
  time: number;

  @ApiProperty()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FacebookWebhookChangeDto)
  changes: FacebookWebhookChangeDto[];
}

export class FacebookWebhookDto {
  @ApiProperty()
  @IsString()
  object: string;

  @ApiProperty()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FacebookWebhookEntryDto)
  entry: FacebookWebhookEntryDto[];
}
