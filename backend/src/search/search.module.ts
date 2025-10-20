import { Module } from '@nestjs/common';
import { ChatSearchController } from './chat-search.controller';
import { SearchService } from './search.service';

@Module({
  controllers: [ChatSearchController],
  providers: [SearchService],
  exports: [SearchService],
})
export class SearchModule {}
