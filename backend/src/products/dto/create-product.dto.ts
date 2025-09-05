import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNumber, IsOptional, IsArray, Min } from 'class-validator';

export class CreateProductDto {
  @ApiProperty({ description: 'Product name' })
  @IsString()
  name: string;

  @ApiProperty({ description: 'Product description', required: false })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ description: 'Product price' })
  @IsNumber()
  @Min(0)
  price: number;

  @ApiProperty({ description: 'Product quantity in stock' })
  @IsNumber()
  @Min(0)
  quantity: number;

  @ApiProperty({ description: 'Product category' })
  @IsString()
  category: string;

  @ApiProperty({ description: 'Business ID that owns this product' })
  @IsString()
  businessId: string;

  @ApiProperty({ description: 'Product images', required: false, type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  images?: string[];

  @ApiProperty({ description: 'Product SKU', required: false })
  @IsOptional()
  @IsString()
  sku?: string;

  @ApiProperty({ description: 'Product weight', required: false })
  @IsOptional()
  @IsNumber()
  weight?: number;

  @ApiProperty({ description: 'Product dimensions', required: false })
  @IsOptional()
  @IsString()
  dimensions?: string;
}
