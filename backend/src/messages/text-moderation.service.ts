import { Injectable, Logger } from '@nestjs/common';
import { LanguageServiceClient } from '@google-cloud/language';
const Filter = require('bad-words');

export interface TextModerationResult {
  isSafe: boolean;
  categories: {
    toxic: number;
    profanity: number;
    threat: number;
    insult: number;
    identity_hate: number;
    spam: number;
    phishing: number;
  };
  reasons: string[];
  action: 'allow' | 'block' | 'review';
  sentiment?: {
    score: number;
    magnitude: number;
  };
}

@Injectable()
export class TextModerationService {
  private readonly logger = new Logger(TextModerationService.name);
  private client: LanguageServiceClient;
  private profanityFilter: any; // bad-words library type

  // Known phishing/scam domains
  private readonly phishingDomains = [
    // URL shorteners (often used for phishing)
    'bit.ly',
    'tinyurl.com',
    'goo.gl',
    'ow.ly',
    't.co',
    // Known scam domains (add more as discovered)
    // You can load this from a config file or database
  ];

  // Spam keywords (common spam phrases)
  private readonly spamKeywords = [
    'free money',
    'click here now',
    'limited time offer',
    'act now',
    'buy now',
    'winner',
    'congratulations you won',
    'claim your prize',
    'you have been selected',
    'exclusive deal',
    'make money fast',
    'work from home',
    'weight loss',
    'get rich quick',
    'apply now',
    'dear friend',
    'nigerian prince', // Classic scam
  ];

  constructor() {
    // Initialize Google Cloud Natural Language API client
    // Uses GOOGLE_APPLICATION_CREDENTIALS environment variable
    this.client = new LanguageServiceClient();

    // Initialize bad-words profanity filter
    // This library contains a comprehensive list of profanity in multiple languages
    this.profanityFilter = new Filter();

    // Optional: Add custom words to the filter
    // this.profanityFilter.addWords('customword1', 'customword2');

    // Optional: Remove words from the filter if they're false positives
    // this.profanityFilter.removeWords('word1', 'word2');

    this.logger.log('Text moderation service initialized with profanity filter');
  }

  /**
   * Moderate text content for inappropriate language, spam, and threats
   * ONLY USES LOCAL CHECKS (no AI API calls)
   * Use analyzeConversationSentiment() for AI-powered admin analytics
   */
  async moderateText(text: string): Promise<TextModerationResult> {
    try {
      this.logger.log(`Moderating text (local checks only): ${text.substring(0, 50)}...`);

      // Initialize result
      const result: TextModerationResult = {
        isSafe: true,
        categories: {
          toxic: 0,
          profanity: 0,
          threat: 0,
          insult: 0,
          identity_hate: 0,
          spam: 0,
          phishing: 0,
        },
        reasons: [],
        action: 'allow',
      };

      // 1. Check for empty or very short text
      if (!text || text.trim().length === 0) {
        return result;
      }

      // 2. Quick local checks ONLY (no AI API calls)
      const localChecks = this.performLocalChecks(text);
      if (!localChecks.isSafe) {
        result.isSafe = false;
        result.reasons.push(...localChecks.reasons);
        result.categories.profanity = localChecks.hasProfanity ? 0.9 : 0;
        result.categories.spam = localChecks.isSpam ? 0.9 : 0;
        result.categories.phishing = localChecks.hasPhishing ? 0.9 : 0;
        result.action = 'block';
        return result;
      }

      // AI checks DISABLED for real-time moderation
      // Use analyzeConversationSentiment() for admin dashboard analytics

      this.logger.log(
        `Moderation result (local only): ${result.action} (isSafe: ${result.isSafe})`,
      );

      return result;
    } catch (error) {
      this.logger.error(`Text moderation failed: ${error.message}`, error.stack);

      // Fail-open: Allow message
      return {
        isSafe: true,
        categories: {
          toxic: 0,
          profanity: 0,
          threat: 0,
          insult: 0,
          identity_hate: 0,
          spam: 0,
          phishing: 0,
        },
        reasons: [],
        action: 'allow',
      };
    }
  }

  /**
   * Analyze conversation sentiment using AI (for admin dashboard analytics)
   * NOT used for real-time blocking - only for insights
   */
  async analyzeConversationSentiment(messages: string[]): Promise<{
    overallSentiment: {
      score: number;
      magnitude: number;
      label: 'very_positive' | 'positive' | 'neutral' | 'negative' | 'very_negative';
    };
    messageCount: number;
    sentimentDistribution: {
      positive: number;
      neutral: number;
      negative: number;
    };
    categories: string[];
    warnings: string[];
  }> {
    try {
      this.logger.log(`Analyzing sentiment for ${messages.length} messages (admin analytics)`);

      const sentiments: number[] = [];
      const magnitudes: number[] = [];
      const allCategories: string[] = [];
      const warnings: string[] = [];

      // Combine messages into chunks (API limit: ~1000 chars per request)
      const combinedText = messages.join(' ');
      
      // 1. Overall sentiment analysis
      try {
        const [sentimentResult] = await this.client.analyzeSentiment({
          document: {
            content: combinedText,
            type: 'PLAIN_TEXT',
          },
        });

        if (sentimentResult.documentSentiment) {
          sentiments.push(sentimentResult.documentSentiment.score);
          magnitudes.push(sentimentResult.documentSentiment.magnitude);
        }

        // Analyze individual message sentiments
        if (sentimentResult.sentences) {
          for (const sentence of sentimentResult.sentences) {
            if (sentence.sentiment) {
              sentiments.push(sentence.sentiment.score);
              
              // Flag very negative sentences
              if (sentence.sentiment.score < -0.7) {
                warnings.push(`Highly negative message detected: "${sentence.text.content.substring(0, 50)}..."`);
              }
            }
          }
        }
      } catch (error) {
        this.logger.warn(`Sentiment analysis failed: ${error.message}`);
      }

      // 2. Content classification (if text is long enough)
      if (combinedText.split(/\s+/).length >= 20) {
        try {
          const [classificationResult] = await this.client.classifyText({
            document: {
              content: combinedText,
              type: 'PLAIN_TEXT',
            },
          });

          if (classificationResult.categories) {
            for (const category of classificationResult.categories) {
              allCategories.push(`${category.name} (${(category.confidence * 100).toFixed(1)}%)`);
              
              // Flag sensitive categories
              if (
                (category.name.includes('/Adult') ||
                category.name.includes('/Violence') ||
                category.name.includes('/Sensitive')) &&
                category.confidence > 0.5
              ) {
                warnings.push(`Sensitive content detected: ${category.name}`);
              }
            }
          }
        } catch (error) {
          this.logger.debug(`Content classification skipped: ${error.message}`);
        }
      }

      // 3. Calculate sentiment distribution
      let positive = 0, neutral = 0, negative = 0;
      for (const score of sentiments) {
        if (score > 0.25) positive++;
        else if (score < -0.25) negative++;
        else neutral++;
      }

      // 4. Calculate overall sentiment
      const avgScore = sentiments.length > 0 
        ? sentiments.reduce((a, b) => a + b, 0) / sentiments.length 
        : 0;
      const avgMagnitude = magnitudes.length > 0 
        ? magnitudes.reduce((a, b) => a + b, 0) / magnitudes.length 
        : 0;

      let label: 'very_positive' | 'positive' | 'neutral' | 'negative' | 'very_negative' = 'neutral';
      if (avgScore > 0.6) label = 'very_positive';
      else if (avgScore > 0.25) label = 'positive';
      else if (avgScore < -0.6) label = 'very_negative';
      else if (avgScore < -0.25) label = 'negative';

      return {
        overallSentiment: {
          score: avgScore,
          magnitude: avgMagnitude,
          label,
        },
        messageCount: messages.length,
        sentimentDistribution: {
          positive,
          neutral,
          negative,
        },
        categories: allCategories,
        warnings,
      };
    } catch (error) {
      this.logger.error(`Conversation sentiment analysis failed: ${error.message}`, error.stack);
      
      return {
        overallSentiment: {
          score: 0,
          magnitude: 0,
          label: 'neutral',
        },
        messageCount: messages.length,
        sentimentDistribution: {
          positive: 0,
          neutral: messages.length,
          negative: 0,
        },
        categories: [],
        warnings: [`Analysis failed: ${error.message}`],
      };
    }
  }

  /**
   * Perform quick local checks without API calls
   */
  private performLocalChecks(text: string): {
    isSafe: boolean;
    reasons: string[];
    hasProfanity: boolean;
    isSpam: boolean;
    hasPhishing: boolean;
  } {
    const result = {
      isSafe: true,
      reasons: [],
      hasProfanity: false,
      isSpam: false,
      hasPhishing: false,
    };

    const lowerText = text.toLowerCase();

    // 1. Check for profanity using bad-words library
    if (this.profanityFilter.isProfane(text)) {
      result.isSafe = false;
      result.hasProfanity = true;
      result.reasons.push('Profanity detected');
      
      // Optional: Get the cleaned version to log what was detected
      const cleaned = this.profanityFilter.clean(text);
      this.logger.debug(`Profanity found: ${text} -> ${cleaned}`);
    }

    // 2. Check for spam patterns
    if (this.detectSpamPatterns(text)) {
      result.isSafe = false;
      result.isSpam = true;
      result.reasons.push('Spam pattern detected');
    }

    // 3. Check for spam keywords
    for (const keyword of this.spamKeywords) {
      if (lowerText.includes(keyword)) {
        result.isSafe = false;
        result.isSpam = true;
        result.reasons.push(`Spam keyword detected: ${keyword}`);
        break;
      }
    }

    // 4. Check for phishing URLs
    if (this.detectPhishingLinks(text)) {
      result.isSafe = false;
      result.hasPhishing = true;
      result.reasons.push('Suspicious URL detected');
    }

    return result;
  }

  /**
   * Detect spam patterns in text
   */
  private detectSpamPatterns(text: string): boolean {
    // 1. Repeated characters (e.g., "BUY NOW!!!!!!")
    if (/(.)\1{5,}/.test(text)) {
      this.logger.debug('Spam: Repeated characters detected');
      return true;
    }

    // 2. All caps spam (messages longer than 20 chars)
    if (text.length > 20 && text === text.toUpperCase() && /[A-Z]/.test(text)) {
      this.logger.debug('Spam: All caps message detected');
      return true;
    }

    // 3. Excessive emojis
    const emojiCount = (text.match(/[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]/gu) || []).length;
    if (emojiCount > 10) {
      this.logger.debug(`Spam: Excessive emojis detected (${emojiCount})`);
      return true;
    }

    // 4. Too many exclamation marks
    const exclamationCount = (text.match(/!/g) || []).length;
    if (exclamationCount > 5) {
      this.logger.debug(`Spam: Excessive exclamation marks (${exclamationCount})`);
      return true;
    }

    // 5. Repeated words
    const words = text.toLowerCase().split(/\s+/);
    const wordCount = new Map<string, number>();
    for (const word of words) {
      if (word.length > 3) {
        wordCount.set(word, (wordCount.get(word) || 0) + 1);
      }
    }
    for (const count of wordCount.values()) {
      if (count > 5) {
        this.logger.debug('Spam: Repeated words detected');
        return true;
      }
    }

    return false;
  }

  /**
   * Detect phishing or suspicious URLs
   */
  private detectPhishingLinks(text: string): boolean {
    // Extract URLs from text
    const urlRegex = /(https?:\/\/[^\s]+)/gi;
    const urls = text.match(urlRegex) || [];

    if (urls.length === 0) {
      return false;
    }

    // 1. Check for URL shorteners (often used in phishing)
    for (const url of urls) {
      const lowerUrl = url.toLowerCase();

      // Check against known phishing domains
      for (const domain of this.phishingDomains) {
        if (lowerUrl.includes(domain)) {
          this.logger.debug(`Phishing: Suspicious domain detected - ${domain}`);
          return true;
        }
      }

      // Check for suspicious URL patterns
      // Multiple @ symbols
      if ((url.match(/@/g) || []).length > 1) {
        this.logger.debug('Phishing: Multiple @ symbols in URL');
        return true;
      }

      // IP address as domain
      if (/https?:\/\/\d+\.\d+\.\d+\.\d+/.test(url)) {
        this.logger.debug('Phishing: IP address as domain');
        return true;
      }

      // Very long URLs (often used to hide malicious domains)
      if (url.length > 200) {
        this.logger.debug('Phishing: Excessively long URL');
        return true;
      }
    }

    // 2. Too many URLs (spam pattern)
    if (urls.length > 3) {
      this.logger.debug(`Spam: Too many URLs (${urls.length})`);
      return true;
    }

    return false;
  }

  /**
   * Batch moderate multiple texts
   */
  async moderateTexts(texts: string[]): Promise<TextModerationResult[]> {
    const results = await Promise.all(
      texts.map(text => this.moderateText(text)),
    );
    return results;
  }
}
