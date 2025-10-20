import { Injectable, Logger } from '@nestjs/common';
import { ImageAnnotatorClient } from '@google-cloud/vision';
import { LanguageServiceClient } from '@google-cloud/language';

/**
 * Quick test service to verify Google Cloud API permissions
 */
@Injectable()
export class GoogleApiTestService {
  private readonly logger = new Logger(GoogleApiTestService.name);

  async testVisionAPI(): Promise<{ success: boolean; message: string }> {
    try {
      const visionClient = new ImageAnnotatorClient();
      
      // Test with a simple public image
      const testImageUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Cat03.jpg/1200px-Cat03.jpg';
      
      this.logger.log('Testing Vision API with sample image...');
      const [result] = await visionClient.safeSearchDetection(testImageUrl);
      
      if (result.safeSearchAnnotation) {
        this.logger.log('✅ Vision API is working!');
        this.logger.log(`Sample result: ${JSON.stringify(result.safeSearchAnnotation)}`);
        return {
          success: true,
          message: 'Vision API is properly configured and working',
        };
      }
      
      return {
        success: false,
        message: 'Vision API returned no results',
      };
    } catch (error) {
      this.logger.error('❌ Vision API test failed:', error.message);
      
      if (error.message.includes('permission')) {
        return {
          success: false,
          message: `Permission denied. Add "Cloud Vision AI Service Agent" role to service account: ${error.message}`,
        };
      }
      
      if (error.message.includes('API not enabled')) {
        return {
          success: false,
          message: 'Vision API is not enabled. Enable it at: https://console.cloud.google.com/apis/library/vision.googleapis.com',
        };
      }
      
      return {
        success: false,
        message: `Vision API error: ${error.message}`,
      };
    }
  }

  async testNaturalLanguageAPI(): Promise<{ success: boolean; message: string }> {
    try {
      const languageClient = new LanguageServiceClient();
      
      const testText = 'Google Cloud Natural Language API is awesome!';
      
      this.logger.log('Testing Natural Language API with sample text...');
      const [result] = await languageClient.analyzeSentiment({
        document: {
          content: testText,
          type: 'PLAIN_TEXT',
        },
      });
      
      if (result.documentSentiment) {
        this.logger.log('✅ Natural Language API is working!');
        this.logger.log(`Sentiment score: ${result.documentSentiment.score}`);
        return {
          success: true,
          message: 'Natural Language API is properly configured and working',
        };
      }
      
      return {
        success: false,
        message: 'Natural Language API returned no results',
      };
    } catch (error) {
      this.logger.error('❌ Natural Language API test failed:', error.message);
      
      if (error.message.includes('permission')) {
        return {
          success: false,
          message: `Permission denied. Add "Cloud Natural Language API Service Agent" role to service account: ${error.message}`,
        };
      }
      
      if (error.message.includes('API not enabled')) {
        return {
          success: false,
          message: 'Natural Language API is not enabled. Enable it at: https://console.cloud.google.com/apis/library/language.googleapis.com',
        };
      }
      
      return {
        success: false,
        message: `Natural Language API error: ${error.message}`,
      };
    }
  }

  async testAll(): Promise<{
    vision: { success: boolean; message: string };
    language: { success: boolean; message: string };
  }> {
    const vision = await this.testVisionAPI();
    const language = await this.testNaturalLanguageAPI();
    
    return { vision, language };
  }
}
