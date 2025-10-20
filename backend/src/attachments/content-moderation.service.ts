import { Injectable, Logger } from '@nestjs/common';
import { ImageAnnotatorClient } from '@google-cloud/vision';

export interface ModerationResult {
  isSafe: boolean;
  reasons: string[];
  scores: {
    adult?: string | number;
    violence?: string | number;
    racy?: string | number;
    spoof?: string | number;
    medical?: string | number;
  };
}

@Injectable()
export class ContentModerationService {
  private readonly logger = new Logger(ContentModerationService.name);
  private visionClient: ImageAnnotatorClient;

  constructor() {
    // Initialize Vision API client
    // Uses GOOGLE_APPLICATION_CREDENTIALS environment variable
    // or Firebase Admin SDK credentials automatically
    this.visionClient = new ImageAnnotatorClient();
    this.logger.log('Google Cloud Vision API initialized');
  }

  /**
   * Moderate image content using Google Cloud Vision API Safe Search Detection
   * Detects: adult, violence, racy, spoof, medical content
   */
  async moderateImage(imageUrl: string): Promise<ModerationResult> {
    try {
      this.logger.log(`Moderating image: ${imageUrl}`);

      // Call Vision API Safe Search Detection
      const [result] = await this.visionClient.safeSearchDetection(imageUrl);
      const detections = result.safeSearchAnnotation;

      if (!detections) {
        this.logger.warn('No safe search detections returned');
        return {
          isSafe: true,
          reasons: [],
          scores: {},
        };
      }

      const reasons: string[] = [];
      const scores = {
        adult: detections.adult,
        violence: detections.violence,
        racy: detections.racy,
        spoof: detections.spoof,
        medical: detections.medical,
      };

      // Check for unsafe content
      // Likelihood values: UNKNOWN, VERY_UNLIKELY, UNLIKELY, POSSIBLE, LIKELY, VERY_LIKELY
      // We flag LIKELY and VERY_LIKELY as unsafe

      if (
        detections.adult === 'LIKELY' ||
        detections.adult === 'VERY_LIKELY'
      ) {
        reasons.push('adult_content');
      }

      if (
        detections.violence === 'LIKELY' ||
        detections.violence === 'VERY_LIKELY'
      ) {
        reasons.push('violence');
      }

      if (
        detections.racy === 'LIKELY' ||
        detections.racy === 'VERY_LIKELY'
      ) {
        reasons.push('racy_content');
      }

      // Spoof detection (fake/manipulated images)
      if (
        detections.spoof === 'LIKELY' ||
        detections.spoof === 'VERY_LIKELY'
      ) {
        reasons.push('manipulated_image');
      }

      const isSafe = reasons.length === 0;

      if (!isSafe) {
        this.logger.warn(
          `Unsafe content detected in ${imageUrl}: ${reasons.join(', ')}`,
        );
        this.logger.debug(`Detection scores:`, scores);
      } else {
        this.logger.log(`Image ${imageUrl} passed moderation`);
      }

      return {
        isSafe,
        reasons,
        scores,
      };
    } catch (error) {
      this.logger.error(
        `Failed to moderate image ${imageUrl}:`,
        error.message,
      );

      // Fail-safe: In case of API error, allow image but log for manual review
      // You can change this to fail-closed (return isSafe: false) for stricter policy
      return {
        isSafe: true, // Allow on error (fail-open)
        reasons: ['moderation_api_error'],
        scores: {},
      };
    }
  }

  /**
   * Moderate image from local file path
   */
  async moderateImageFromFile(filePath: string): Promise<ModerationResult> {
    try {
      this.logger.log(`Moderating image from file: ${filePath}`);

      const [result] = await this.visionClient.safeSearchDetection(filePath);
      const detections = result.safeSearchAnnotation;

      if (!detections) {
        return {
          isSafe: true,
          reasons: [],
          scores: {},
        };
      }

      const reasons: string[] = [];
      const scores = {
        adult: detections.adult,
        violence: detections.violence,
        racy: detections.racy,
        spoof: detections.spoof,
        medical: detections.medical,
      };

      if (
        detections.adult === 'LIKELY' ||
        detections.adult === 'VERY_LIKELY'
      ) {
        reasons.push('adult_content');
      }

      if (
        detections.violence === 'LIKELY' ||
        detections.violence === 'VERY_LIKELY'
      ) {
        reasons.push('violence');
      }

      if (
        detections.racy === 'LIKELY' ||
        detections.racy === 'VERY_LIKELY'
      ) {
        reasons.push('racy_content');
      }

      if (
        detections.spoof === 'LIKELY' ||
        detections.spoof === 'VERY_LIKELY'
      ) {
        reasons.push('manipulated_image');
      }

      const isSafe = reasons.length === 0;

      return {
        isSafe,
        reasons,
        scores,
      };
    } catch (error) {
      this.logger.error(
        `Failed to moderate file ${filePath}:`,
        error.message,
      );

      return {
        isSafe: true, // Fail-open
        reasons: ['moderation_api_error'],
        scores: {},
      };
    }
  }

  /**
   * Moderate image from buffer (useful for in-memory processing)
   */
  async moderateImageFromBuffer(
    imageBuffer: Buffer,
  ): Promise<ModerationResult> {
    try {
      this.logger.log('Moderating image from buffer');

      const [result] = await this.visionClient.safeSearchDetection({
        image: { content: imageBuffer },
      });

      const detections = result.safeSearchAnnotation;

      if (!detections) {
        return {
          isSafe: true,
          reasons: [],
          scores: {},
        };
      }

      const reasons: string[] = [];
      const scores = {
        adult: detections.adult,
        violence: detections.violence,
        racy: detections.racy,
        spoof: detections.spoof,
        medical: detections.medical,
      };

      if (
        detections.adult === 'LIKELY' ||
        detections.adult === 'VERY_LIKELY'
      ) {
        reasons.push('adult_content');
      }

      if (
        detections.violence === 'LIKELY' ||
        detections.violence === 'VERY_LIKELY'
      ) {
        reasons.push('violence');
      }

      if (
        detections.racy === 'LIKELY' ||
        detections.racy === 'VERY_LIKELY'
      ) {
        reasons.push('racy_content');
      }

      if (
        detections.spoof === 'LIKELY' ||
        detections.spoof === 'VERY_LIKELY'
      ) {
        reasons.push('manipulated_image');
      }

      const isSafe = reasons.length === 0;

      return {
        isSafe,
        reasons,
        scores,
      };
    } catch (error) {
      this.logger.error(
        'Failed to moderate image from buffer:',
        error.message,
      );

      return {
        isSafe: true, // Fail-open
        reasons: ['moderation_api_error'],
        scores: {},
      };
    }
  }

  /**
   * Get detailed labels for an image (optional - costs extra)
   * Useful for understanding what's in the image
   */
  async getImageLabels(imageUrl: string): Promise<string[]> {
    try {
      const [result] = await this.visionClient.labelDetection(imageUrl);
      const labels = result.labelAnnotations || [];

      return labels.map((label) => label.description).filter(Boolean);
    } catch (error) {
      this.logger.error(`Failed to get labels for ${imageUrl}:`, error.message);
      return [];
    }
  }

  /**
   * Detect text in image (OCR) - useful for detecting spam text in images
   */
  async detectTextInImage(imageUrl: string): Promise<string> {
    try {
      const [result] = await this.visionClient.textDetection(imageUrl);
      const detections = result.textAnnotations || [];

      if (detections.length > 0) {
        // First detection contains full text
        return detections[0].description || '';
      }

      return '';
    } catch (error) {
      this.logger.error(
        `Failed to detect text in ${imageUrl}:`,
        error.message,
      );
      return '';
    }
  }

  /**
   * Detect text in image from local file path (OCR)
   */
  async detectTextInImageFromFile(filePath: string): Promise<string> {
    try {
      this.logger.log(`Detecting text in image from file: ${filePath}`);

      const [result] = await this.visionClient.textDetection(filePath);
      const detections = result.textAnnotations || [];

      if (detections.length > 0) {
        return detections[0].description || '';
      }

      return '';
    } catch (error) {
      this.logger.error(
        `Failed to detect text in file ${filePath}:`,
        error.message,
      );
      return '';
    }
  }
}
