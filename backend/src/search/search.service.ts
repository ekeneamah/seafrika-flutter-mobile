import { Injectable, Logger } from '@nestjs/common';
import { Firestore } from '@google-cloud/firestore';

/**
 * SearchService handles message search functionality
 * 
 * Note: This is a basic Firestore-based search implementation.
 * For production use with large datasets, consider integrating:
 * - Algolia (npm install algoliasearch)
 * - Elasticsearch
 * - Google Cloud Search
 */
@Injectable()
export class SearchService {
  private readonly logger = new Logger(SearchService.name);
  private readonly firestore: Firestore;

  constructor() {
    this.firestore = new Firestore();
  }

  /**
   * Search messages within a specific conversation
   */
  async searchMessages(
    conversationId: string,
    query: string,
    limit: number = 50,
    page: number = 0,
  ): Promise<{
    results: any[];
    total: number;
    hasMore: boolean;
  }> {
    try {
      this.logger.log(
        `Searching conversation ${conversationId} for "${query}" (limit: ${limit}, page: ${page})`,
      );

      const searchQuery = query.toLowerCase().trim();
      const offset = page * limit;

      // Firestore basic search (case-insensitive text contains)
      // For production, use Algolia or Elasticsearch for better search
      const messagesRef = this.firestore
        .collection('messages')
        .where('conversationId', '==', conversationId)
        .orderBy('createdAt', 'desc')
        .limit(1000); // Fetch up to 1000 messages for searching

      const snapshot = await messagesRef.get();

      // Filter messages that contain the search query
      const matchedMessages = [];
      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        const messageText = (data.content?.text || '').toLowerCase();
        const senderName = (data.sender?.name || '').toLowerCase();

        // Basic text matching
        if (
          messageText.includes(searchQuery) ||
          senderName.includes(searchQuery)
        ) {
          matchedMessages.push({
            id: doc.id,
            ...data,
            // Highlight the matched text
            highlightedText: this.highlightText(
              data.content?.text || '',
              query,
            ),
          });
        }
      });

      // Pagination
      const total = matchedMessages.length;
      const paginatedResults = matchedMessages.slice(offset, offset + limit);
      const hasMore = offset + limit < total;

      this.logger.log(
        `Found ${total} matches, returning ${paginatedResults.length} results`,
      );

      return {
        results: paginatedResults,
        total,
        hasMore,
      };
    } catch (error) {
      this.logger.error(`Search failed: ${error.message}`, error.stack);
      throw error;
    }
  }

  /**
   * Search messages across all conversations for a business
   */
  async searchBusinessMessages(
    businessId: string,
    query: string,
    limit: number = 50,
    page: number = 0,
  ): Promise<{
    results: any[];
    total: number;
    hasMore: boolean;
  }> {
    try {
      this.logger.log(
        `Searching business ${businessId} for "${query}" (limit: ${limit}, page: ${page})`,
      );

      const searchQuery = query.toLowerCase().trim();
      const offset = page * limit;

      // Get all conversations for this business first
      const conversationsRef = this.firestore
        .collection('conversations')
        .where('businessId', '==', businessId);

      const conversationsSnapshot = await conversationsRef.get();
      const conversationIds = conversationsSnapshot.docs.map((doc) => doc.id);

      if (conversationIds.length === 0) {
        return { results: [], total: 0, hasMore: false };
      }

      // Search messages in batches (Firestore 'in' query limit is 10)
      const allMatches = [];
      for (let i = 0; i < conversationIds.length; i += 10) {
        const batch = conversationIds.slice(i, i + 10);

        const messagesRef = this.firestore
          .collection('messages')
          .where('conversationId', 'in', batch)
          .orderBy('createdAt', 'desc')
          .limit(500);

        const snapshot = await messagesRef.get();

        snapshot.docs.forEach((doc) => {
          const data = doc.data();
          const messageText = (data.content?.text || '').toLowerCase();
          const senderName = (data.sender?.name || '').toLowerCase();

          if (
            messageText.includes(searchQuery) ||
            senderName.includes(searchQuery)
          ) {
            allMatches.push({
              id: doc.id,
              ...data,
              highlightedText: this.highlightText(
                data.content?.text || '',
                query,
              ),
            });
          }
        });
      }

      // Sort by relevance (messages with query in text first, then by date)
      allMatches.sort((a, b) => {
        const aText = (a.content?.text || '').toLowerCase();
        const bText = (b.content?.text || '').toLowerCase();
        const aStartsWith = aText.startsWith(searchQuery);
        const bStartsWith = bText.startsWith(searchQuery);

        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;

        return b.createdAt?.toMillis() - a.createdAt?.toMillis();
      });

      // Pagination
      const total = allMatches.length;
      const paginatedResults = allMatches.slice(offset, offset + limit);
      const hasMore = offset + limit < total;

      this.logger.log(
        `Found ${total} matches across ${conversationIds.length} conversations`,
      );

      return {
        results: paginatedResults,
        total,
        hasMore,
      };
    } catch (error) {
      this.logger.error(
        `Business search failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * Index messages for search
   * Note: With Firestore, indexing happens automatically
   * This method is a placeholder for future Algolia/Elasticsearch integration
   */
  async indexMessages(
    conversationId?: string,
    businessId?: string,
    messageIds?: string[],
  ): Promise<{ indexed: number }> {
    this.logger.log('Index messages called (Firestore auto-indexes)');

    // For Algolia integration, you would:
    // 1. Fetch messages from Firestore
    // 2. Transform them into Algolia objects
    // 3. Push to Algolia index using algolia.saveObjects()

    return { indexed: 0 };
  }

  /**
   * Reindex all messages
   */
  async reindexAll(): Promise<{ message: string }> {
    this.logger.log('Reindex all called (not implemented for Firestore)');

    // For Algolia integration, you would:
    // 1. Clear existing index
    // 2. Fetch all messages in batches
    // 3. Push to Algolia in batches

    return { message: 'Reindexing not needed with Firestore' };
  }

  /**
   * Get search suggestions based on partial query
   */
  async getSuggestions(
    query: string,
    businessId?: string,
  ): Promise<string[]> {
    try {
      const searchQuery = query.toLowerCase().trim();
      if (searchQuery.length < 2) {
        return [];
      }

      // Basic suggestion implementation
      // In production, use Algolia's query suggestions feature
      const suggestions = new Set<string>();

      let messagesRef = this.firestore
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(100);

      if (businessId) {
        // Get conversations for business
        const conversationsRef = this.firestore
          .collection('conversations')
          .where('businessId', '==', businessId)
          .limit(10);

        const conversationsSnapshot = await conversationsRef.get();
        const conversationIds = conversationsSnapshot.docs.map(
          (doc) => doc.id,
        );

        if (conversationIds.length > 0) {
          messagesRef = this.firestore
            .collection('messages')
            .where('conversationId', 'in', conversationIds.slice(0, 10))
            .orderBy('createdAt', 'desc')
            .limit(100);
        }
      }

      const snapshot = await messagesRef.get();

      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        const text = (data.content?.text || '').toLowerCase();

        // Extract words that match the query
        const words = text.split(/\s+/);
        words.forEach((word) => {
          if (word.startsWith(searchQuery) && word.length > searchQuery.length) {
            suggestions.add(word);
          }
        });
      });

      return Array.from(suggestions).slice(0, 10);
    } catch (error) {
      this.logger.error(`Get suggestions failed: ${error.message}`, error.stack);
      return [];
    }
  }

  /**
   * Highlight search query in text
   */
  private highlightText(text: string, query: string): string {
    if (!text || !query) return text;

    const regex = new RegExp(`(${this.escapeRegex(query)})`, 'gi');
    return text.replace(regex, '<mark>$1</mark>');
  }

  /**
   * Escape special regex characters
   */
  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}
