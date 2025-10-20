import { JwtAuthGuard } from '@/auth/guards/jwt-auth.guard';
import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  UseGuards,
  Request,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiBearerAuth } from '@nestjs/swagger';
import { SearchService } from './search.service';

@ApiTags('Chat Search')
@ApiBearerAuth()
@Controller('search/chat-search')
@UseGuards(JwtAuthGuard)
export class ChatSearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  @ApiOperation({ summary: 'Search messages in a conversation' })
  @ApiQuery({ name: 'conversationId', required: true, type: String })
  @ApiQuery({ name: 'query', required: true, type: String })
  @ApiQuery({ name: 'limit', required: false, type: Number, example: 50 })
  @ApiQuery({ name: 'page', required: false, type: Number, example: 0 })
  async searchMessages(
    @Query('conversationId') conversationId: string,
    @Query('query') query: string,
    @Query('limit') limit?: number,
    @Query('page') page?: number,
    @Request() req?: any,
  ) {
    if (!conversationId || !query) {
      throw new HttpException(
        'conversationId and query are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    const searchLimit = limit ? parseInt(limit.toString(), 10) : 50;
    const searchPage = page ? parseInt(page.toString(), 10) : 0;

    try {
      const results = await this.searchService.searchMessages(
        conversationId,
        query,
        searchLimit,
        searchPage,
      );

      return {
        success: true,
        conversationId,
        query,
        page: searchPage,
        limit: searchLimit,
        ...results,
      };
    } catch (error) {
      throw new HttpException(
        `Search failed: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('business/:businessId')
  @ApiOperation({ summary: 'Search messages across all conversations for a business' })
  @ApiQuery({ name: 'query', required: true, type: String })
  @ApiQuery({ name: 'limit', required: false, type: Number, example: 50 })
  @ApiQuery({ name: 'page', required: false, type: Number, example: 0 })
  async searchBusinessMessages(
    @Query('query') query: string,
    @Query('limit') limit?: number,
    @Query('page') page?: number,
    @Request() req?: any,
  ) {
    const businessId = req.params.businessId;

    if (!businessId || !query) {
      throw new HttpException(
        'businessId and query are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    const searchLimit = limit ? parseInt(limit.toString(), 10) : 50;
    const searchPage = page ? parseInt(page.toString(), 10) : 0;

    try {
      const results = await this.searchService.searchBusinessMessages(
        businessId,
        query,
        searchLimit,
        searchPage,
      );

      return {
        success: true,
        businessId,
        query,
        page: searchPage,
        limit: searchLimit,
        ...results,
      };
    } catch (error) {
      throw new HttpException(
        `Search failed: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('index')
  @ApiOperation({ summary: 'Manually trigger indexing of messages' })
  async indexMessages(
    @Body() body: { conversationId?: string; businessId?: string; messageIds?: string[] },
    @Request() req?: any,
  ) {
    try {
      const result = await this.searchService.indexMessages(
        body.conversationId,
        body.businessId,
        body.messageIds,
      );

      return {
        success: true,
        message: 'Indexing completed',
        ...result,
      };
    } catch (error) {
      throw new HttpException(
        `Indexing failed: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('reindex')
  @ApiOperation({ summary: 'Reindex all messages (admin only)' })
  async reindexAll(@Request() req?: any) {
    try {
      const result = await this.searchService.reindexAll();

      return {
        success: true,
        message: 'Reindexing started',
        ...result,
      };
    } catch (error) {
      throw new HttpException(
        `Reindexing failed: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('suggestions')
  @ApiOperation({ summary: 'Get search suggestions based on partial query' })
  @ApiQuery({ name: 'query', required: true, type: String })
  @ApiQuery({ name: 'businessId', required: false, type: String })
  async getSuggestions(
    @Query('query') query: string,
    @Query('businessId') businessId?: string,
  ) {
    if (!query) {
      throw new HttpException('query is required', HttpStatus.BAD_REQUEST);
    }

    try {
      const suggestions = await this.searchService.getSuggestions(query, businessId);

      return {
        success: true,
        query,
        suggestions,
      };
    } catch (error) {
      throw new HttpException(
        `Failed to get suggestions: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}
