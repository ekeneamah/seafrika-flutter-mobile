import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, MaxLength } from 'class-validator';

export class ModerateTextDto {
  @ApiProperty({
    description: 'Text content to moderate',
    example: 'Hello, I would like to inquire about your product.',
    maxLength: 5000,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  text: string;

  @ApiProperty({
    description: 'Conversation ID for context tracking',
    example: 'conv_123abc',
    required: false,
  })
  @IsString()
  conversationId?: string;
}
