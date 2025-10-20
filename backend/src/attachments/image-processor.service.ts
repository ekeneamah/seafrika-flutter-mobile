import { Injectable, Logger } from '@nestjs/common';
import * as sharp from 'sharp';
import * as fs from 'fs/promises';
import * as path from 'path';

export interface ImageVariant {
  name: string; // 'thumbnail', 'medium', 'full'
  path: string;
  width: number;
  height: number;
  size: number; // bytes
  format: string;
}

export interface ProcessedImage {
  variants: ImageVariant[];
  metadata: {
    originalWidth: number;
    originalHeight: number;
    originalSize: number;
    originalFormat: string;
    hasAlpha: boolean;
  };
}

@Injectable()
export class ImageProcessorService {
  private readonly logger = new Logger(ImageProcessorService.name);

  // Image variant configurations
  private readonly THUMBNAIL_SIZE = 150; // 150x150px for lists
  private readonly MEDIUM_SIZE = 800; // 800px width for chat bubbles
  private readonly FULL_SIZE = 1920; // 1920px max for full resolution

  /**
   * Process image: compress, generate variants, remove EXIF data
   * @param inputPath Path to the input image file
   * @returns Processed image with multiple size variants
   */
  async processImage(inputPath: string): Promise<ProcessedImage> {
    try {
      this.logger.log(`Processing image: ${inputPath}`);

      // Get original metadata
      const metadata = await sharp(inputPath).metadata();
      
      const originalMetadata = {
        originalWidth: metadata.width || 0,
        originalHeight: metadata.height || 0,
        originalSize: (await fs.stat(inputPath)).size,
        originalFormat: metadata.format || 'unknown',
        hasAlpha: metadata.hasAlpha || false,
      };

      this.logger.log(
        `Original image: ${originalMetadata.originalWidth}x${originalMetadata.originalHeight}, ` +
        `${(originalMetadata.originalSize / 1024).toFixed(2)}KB, format: ${originalMetadata.originalFormat}`,
      );

      // Generate variants
      const variants: ImageVariant[] = [];

      // 1. Thumbnail (150x150px, square crop, WebP 70% quality)
      const thumbnailPath = this.getVariantPath(inputPath, 'thumbnail');
      await sharp(inputPath)
        .resize(this.THUMBNAIL_SIZE, this.THUMBNAIL_SIZE, {
          fit: 'cover',
          position: 'center',
        })
        .webp({ quality: 70 })
        .toFile(thumbnailPath);
      
      const thumbnailStats = await fs.stat(thumbnailPath);
      variants.push({
        name: 'thumbnail',
        path: thumbnailPath,
        width: this.THUMBNAIL_SIZE,
        height: this.THUMBNAIL_SIZE,
        size: thumbnailStats.size,
        format: 'webp',
      });

      // 2. Medium (800px width, maintain aspect ratio, WebP 85% quality)
      const mediumPath = this.getVariantPath(inputPath, 'medium');
      const mediumImage = await sharp(inputPath)
        .resize(this.MEDIUM_SIZE, null, {
          fit: 'inside',
          withoutEnlargement: true,
        })
        .webp({ quality: 85 })
        .toFile(mediumPath);
      
      const mediumStats = await fs.stat(mediumPath);
      variants.push({
        name: 'medium',
        path: mediumPath,
        width: mediumImage.width,
        height: mediumImage.height,
        size: mediumStats.size,
        format: 'webp',
      });

      // 3. Full (1920px max, maintain aspect ratio, WebP 90% quality)
      const fullPath = this.getVariantPath(inputPath, 'full');
      const fullImage = await sharp(inputPath)
        .resize(this.FULL_SIZE, this.FULL_SIZE, {
          fit: 'inside',
          withoutEnlargement: true,
        })
        .webp({ quality: 90 })
        // Remove EXIF data for privacy (location, camera info, etc.)
        .rotate() // Auto-rotate based on EXIF, then remove it
        .toFile(fullPath);
      
      const fullStats = await fs.stat(fullPath);
      variants.push({
        name: 'full',
        path: fullPath,
        width: fullImage.width,
        height: fullImage.height,
        size: fullStats.size,
        format: 'webp',
      });

      this.logger.log(
        `Generated ${variants.length} variants: ` +
        variants.map(v => `${v.name}(${(v.size / 1024).toFixed(2)}KB)`).join(', '),
      );

      const totalSaved = originalMetadata.originalSize - variants.reduce((sum, v) => sum + v.size, 0);
      const compressionRatio = ((totalSaved / originalMetadata.originalSize) * 100).toFixed(1);
      this.logger.log(`Compression saved: ${(totalSaved / 1024).toFixed(2)}KB (${compressionRatio}%)`);

      return {
        variants,
        metadata: originalMetadata,
      };
    } catch (error) {
      this.logger.error(`Failed to process image ${inputPath}:`, error.message);
      throw error;
    }
  }

  /**
   * Validate file is actually an image by checking magic bytes
   * @param filePath Path to file
   * @returns True if valid image format
   */
  async validateImageFile(filePath: string): Promise<boolean> {
    try {
      // Try to read metadata - will fail if not a valid image
      const metadata = await sharp(filePath).metadata();
      
      // Check if it's a supported format
      const supportedFormats = ['jpeg', 'png', 'webp', 'gif', 'tiff', 'svg'];
      if (!metadata.format || !supportedFormats.includes(metadata.format)) {
        this.logger.warn(`Unsupported image format: ${metadata.format}`);
        return false;
      }

      // Check dimensions
      if (!metadata.width || !metadata.height) {
        this.logger.warn('Image has no dimensions');
        return false;
      }

      // Check for reasonable dimensions (max 5000x5000px)
      if (metadata.width > 5000 || metadata.height > 5000) {
        this.logger.warn(`Image dimensions too large: ${metadata.width}x${metadata.height}`);
        return false;
      }

      return true;
    } catch (error) {
      this.logger.error(`File validation failed: ${error.message}`);
      return false;
    }
  }

  /**
   * Generate path for image variant
   */
  private getVariantPath(originalPath: string, variant: string): string {
    const dir = path.dirname(originalPath);
    const ext = path.extname(originalPath);
    const basename = path.basename(originalPath, ext);
    return path.join(dir, `${basename}_${variant}.webp`);
  }

  /**
   * Clean up temporary files
   */
  async cleanupFiles(files: string[]): Promise<void> {
    await Promise.all(
      files.map(async (file) => {
        try {
          await fs.unlink(file);
          this.logger.log(`Deleted temp file: ${file}`);
        } catch (error) {
          this.logger.warn(`Failed to delete ${file}: ${error.message}`);
        }
      }),
    );
  }
}
