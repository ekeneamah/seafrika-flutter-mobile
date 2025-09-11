import { IsString, IsOptional, IsArray, IsObject, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class WhatsAppContactDto {
  @ApiProperty()
  @IsString()
  wa_id: string;

  @ApiProperty()
  @IsObject()
  profile: {
    name: string;
  };
}

export class WhatsAppMessageDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty()
  @IsString()
  from: string;

  @ApiProperty()
  @IsString()
  timestamp: string;

  @ApiProperty()
  @IsString()
  type: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  text?: {
    body: string;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  image?: {
    id: string;
    mime_type: string;
    sha256: string;
    caption?: string;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  document?: {
    id: string;
    filename: string;
    mime_type: string;
    sha256: string;
    caption?: string;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  audio?: {
    id: string;
    mime_type: string;
    sha256: string;
    voice?: boolean;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  video?: {
    id: string;
    mime_type: string;
    sha256: string;
    caption?: string;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  location?: {
    latitude: number;
    longitude: number;
    name?: string;
    address?: string;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsArray()
  contacts?: Array<{
    name: {
      formatted_name: string;
      first_name?: string;
      last_name?: string;
    };
    phones?: Array<{
      phone: string;
      type?: string;
      wa_id?: string;
    }>;
  }>;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  context?: {
    message_id: string;
  };
}

export class WhatsAppStatusDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty()
  @IsString()
  status: string;

  @ApiProperty()
  @IsString()
  timestamp: string;

  @ApiProperty()
  @IsString()
  recipient_id: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  conversation?: {
    id: string;
    expiration_timestamp?: string;
    origin: {
      type: string;
    };
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  pricing?: {
    billable: boolean;
    pricing_model: string;
    category: string;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsArray()
  errors?: Array<{
    code: number;
    title: string;
    message: string;
    error_data: {
      details: string;
    };
  }>;
}

export class WhatsAppWebhookValueDto {
  @ApiProperty()
  @IsString()
  messaging_product: string;

  @ApiProperty()
  @IsObject()
  metadata: {
    display_phone_number: string;
    phone_number_id: string;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => WhatsAppContactDto)
  contacts?: WhatsAppContactDto[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => WhatsAppMessageDto)
  messages?: WhatsAppMessageDto[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => WhatsAppStatusDto)
  statuses?: WhatsAppStatusDto[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsArray()
  errors?: Array<{
    code: number;
    title: string;
    message: string;
    error_data: {
      details: string;
    };
  }>;
}

export class WhatsAppWebhookChangeDto {
  @ApiProperty()
  @IsObject()
  @ValidateNested()
  @Type(() => WhatsAppWebhookValueDto)
  value: WhatsAppWebhookValueDto;

  @ApiProperty()
  @IsString()
  field: string;
}

export class WhatsAppWebhookEntryDto {
  @ApiProperty()
  @IsString()
  id: string;

  @ApiProperty()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => WhatsAppWebhookChangeDto)
  changes: WhatsAppWebhookChangeDto[];
}

export class WhatsAppWebhookDto {
  @ApiProperty()
  @IsString()
  object: string;

  @ApiProperty()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => WhatsAppWebhookEntryDto)
  entry: WhatsAppWebhookEntryDto[];
}
