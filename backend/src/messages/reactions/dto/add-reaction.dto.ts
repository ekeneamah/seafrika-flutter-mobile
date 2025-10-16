import { IsString, IsNotEmpty, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class AddReactionDto {
  @ApiProperty({
    description: 'User ID who is adding the reaction',
    example: 'user123',
  })
  @IsString()
  @IsNotEmpty()
  userId: string;

  @ApiProperty({
    description: 'Business ID (vendor ID)',
    example: 'business456',
  })
  @IsString()
  @IsNotEmpty()
  businessId: string;

  @ApiProperty({
    description: 'Emoji unicode or shortcode',
    example: '👍',
  })
  @IsString()
  @IsNotEmpty()
  emoji: string;

  @ApiProperty({
    description: 'User display name',
    example: 'John Doe',
    required: false,
  })
  @IsString()
  @IsOptional()
  userName?: string;

  @ApiProperty({
    description: 'Platform where reaction originated (messenger, instagram, app)',
    example: 'messenger',
    required: false,
  })
  @IsString()
  @IsOptional()
  platform?: string;
}
