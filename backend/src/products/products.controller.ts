import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { GetUser } from '../auth/decorators/get-user.decorator';

@ApiTags('Products')
@Controller('products')
// @UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new product' })
  @ApiResponse({ status: 201, description: 'Product created successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  async create(@Body() createProductDto: CreateProductDto, @GetUser() user: any) {
    return this.productsService.create(createProductDto, user.id);
  }

  @Get()
  @ApiOperation({ summary: 'Get all products' })
  @ApiResponse({ status: 200, description: 'Products retrieved successfully' })
  async findAll(
    @Query('businessId') businessId?: string,
    @Query('category') category?: string,
    @Query('search') search?: string,
    @Query('limit') limit?: number,
    @Query('page') page?: number,
  ) {
    return this.productsService.findAll({
      businessId,
      category,
      search,
      limit: limit || 20,
      page: page || 1,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get product by ID' })
  @ApiResponse({ status: 200, description: 'Product retrieved successfully' })
  @ApiResponse({ status: 404, description: 'Product not found' })
  async findOne(@Param('id') id: string) {
    return this.productsService.findOne(id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update product' })
  @ApiResponse({ status: 200, description: 'Product updated successfully' })
  @ApiResponse({ status: 404, description: 'Product not found' })
  async update(
    @Param('id') id: string,
    @Body() updateProductDto: UpdateProductDto,
    @GetUser() user: any,
  ) {
    return this.productsService.update(id, updateProductDto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete product' })
  @ApiResponse({ status: 200, description: 'Product deleted successfully' })
  @ApiResponse({ status: 404, description: 'Product not found' })
  async remove(@Param('id') id: string, @GetUser() user: any) {
    return this.productsService.remove(id, user.id);
  }

  @Get('business/:businessId')
  @ApiOperation({ summary: 'Get products by business ID' })
  @ApiResponse({ status: 200, description: 'Business products retrieved successfully' })
  async findByBusiness(@Param('businessId') businessId: string) {
    return this.productsService.findByBusiness(businessId);
  }

  @Get('low-stock/:businessId')
  @ApiOperation({ summary: 'Get low stock products' })
  @ApiResponse({ status: 200, description: 'Low stock products retrieved successfully' })
  async getLowStockProducts(@Param('businessId') businessId: string) {
    return this.productsService.getLowStockProducts(businessId);
  }
}
