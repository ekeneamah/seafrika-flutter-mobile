import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpException,
  HttpStatus,
  Logger,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
} from '@nestjs/common';
import { FileInterceptor, FileFieldsInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiResponse,
  ApiBody,
  ApiConsumes,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ContentModerationService } from './content-moderation.service';
import { ImageProcessorService } from './image-processor.service';
import { FirebaseStorageService } from './firebase-storage.service';
import { DocumentProcessorService } from './processors/document.processor';
import { VideoProcessorService } from './processors/video.processor';
import * as path from 'path';
import * as fs from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';

class ModerateImageDto {
  imageUrl: string;
}

// Multer storage configuration
const storage = diskStorage({
  destination: './uploads/temp',
  filename: (req, file, cb) => {
    const uniqueName = `${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

@ApiTags('Attachments')
@Controller('attachments')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class AttachmentsController {
  private readonly logger = new Logger(AttachmentsController.name);

  constructor(
    private readonly contentModerationService: ContentModerationService,
    private readonly imageProcessorService: ImageProcessorService,
    private readonly firebaseStorageService: FirebaseStorageService,
    private readonly documentProcessorService: DocumentProcessorService,
    private readonly videoProcessorService: VideoProcessorService,
  ) {
    // Ensure upload directory exists
    this.ensureUploadDir();
  }

  private async ensureUploadDir() {
    try {
      await fs.mkdir('./uploads/temp', { recursive: true });
      this.logger.log('Upload directory ready');
    } catch (error) {
      this.logger.error('Failed to create upload directory:', error.message);
    }
  }

  /**
   * Secure image upload with validation, moderation, compression
   * POST /attachments/upload
   */
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('image', {
      storage,
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB max
      },
      fileFilter: (req, file, cb) => {
        // Basic MIME type check (will be validated again on server)
        const allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if (allowedMimes.includes(file.mimetype)) {
          cb(null, true);
        } else {
          cb(new HttpException('Invalid file type', HttpStatus.BAD_REQUEST), false);
        }
      },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload image with security validation (Task #14)',
    description:
      'Secure image upload workflow:\n' +
      '1. Frontend validation (file type, size)\n' +
      '2. Backend re-validation (magic bytes)\n' +
      '3. Google Vision API content moderation\n' +
      '4. Text detection (spam/phishing)\n' +
      '5. Image compression with Sharp\n' +
      '6. Generate 3 variants (thumbnail, medium, full)\n' +
      '7. Upload to Firebase Storage\n' +
      '8. Clean up temporary files\n' +
      '9. Return URLs and metadata',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        image: {
          type: 'string',
          format: 'binary',
          description: 'Image file (JPEG, PNG, WebP, GIF). Max 10MB.',
        },
        conversationId: {
          type: 'string',
          description: 'Conversation ID for organizing uploads',
        },
      },
      required: ['image', 'conversationId'],
    },
  })
  @ApiResponse({
    status: 200,
    description: 'Image uploaded successfully',
    schema: {
      example: {
        success: true,
        attachmentId: 'a1b2c3d4',
        urls: {
          thumbnail: 'https://storage.googleapis.com/.../image_thumbnail_uuid.webp',
          medium: 'https://storage.googleapis.com/.../image_medium_uuid.webp',
          full: 'https://storage.googleapis.com/.../image_full_uuid.webp',
        },
        metadata: {
          originalSize: 5242880,
          compressedSize: 524288,
          originalWidth: 3840,
          originalHeight: 2160,
          format: 'webp',
        },
        moderation: {
          isSafe: true,
          scannedAt: '2025-10-19T12:00:00Z',
        },
      },
    },
  })
  @ApiResponse({ status: 400, description: 'Invalid file or moderation failed' })
  async uploadImage(
    @UploadedFile() file: Express.Multer.File,
    @Body('conversationId') conversationId: string,
  ) {
    const tempFiles: string[] = [];
    
    try {
      if (!file) {
        throw new HttpException('No file uploaded', HttpStatus.BAD_REQUEST);
      }

      if (!conversationId) {
        throw new HttpException('conversationId is required', HttpStatus.BAD_REQUEST);
      }

      tempFiles.push(file.path);

      this.logger.log(
        `Processing upload: ${file.originalname} (${(file.size / 1024).toFixed(2)}KB) for conversation: ${conversationId}`,
      );

      // STEP 1: Validate file is actually an image (magic bytes check)
      const isValid = await this.imageProcessorService.validateImageFile(file.path);
      if (!isValid) {
        throw new HttpException(
          'Invalid image file. File may be corrupted or not a supported format.',
          HttpStatus.BAD_REQUEST,
        );
      }

      // STEP 2: Content moderation with Google Vision API
      const modResult = await this.contentModerationService.moderateImageFromFile(
        file.path,
      );
      
      if (!modResult.isSafe) {
        throw new HttpException(
          `Content policy violation: ${modResult.reasons.join(', ')}`,
          HttpStatus.BAD_REQUEST,
        );
      }

      // STEP 3: Detect text in image (spam/phishing detection)
      const detectedText = await this.contentModerationService.detectTextInImageFromFile(
        file.path,
      );
      
      // Check for spam keywords in detected text
      if (detectedText && this.containsSpam(detectedText)) {
        throw new HttpException(
          'Spam content detected in image',
          HttpStatus.BAD_REQUEST,
        );
      }

      // STEP 4: Process image - compress and generate variants
      const processed = await this.imageProcessorService.processImage(file.path);
      
      // Add variant paths to temp files for cleanup
      processed.variants.forEach(v => tempFiles.push(v.path));

      // STEP 5: Upload to Firebase Storage
      const remotePath = this.firebaseStorageService.generateRemotePath(
        conversationId,
        'images',
      );

      const uploadedFiles = await this.firebaseStorageService.uploadMultipleFiles(
        processed.variants.map(variant => ({
          localPath: variant.path,
          remotePath,
          contentType: 'image/webp',
        })),
      );

      // STEP 6: Build response with URLs
      const urls: any = {};
      uploadedFiles.forEach((uploaded, index) => {
        const variantName = processed.variants[index].name;
        urls[variantName] = uploaded.downloadUrl; // Use signed URL for security
      });

      const attachmentId = uuidv4().substring(0, 8);

      const response = {
        success: true,
        attachmentId,
        urls,
        metadata: {
          originalSize: processed.metadata.originalSize,
          compressedSize: processed.variants.reduce((sum, v) => sum + v.size, 0),
          originalWidth: processed.metadata.originalWidth,
          originalHeight: processed.metadata.originalHeight,
          format: 'webp',
          variants: processed.variants.map(v => ({
            name: v.name,
            width: v.width,
            height: v.height,
            size: v.size,
          })),
        },
        moderation: {
          isSafe: modResult.isSafe,
          scannedAt: new Date().toISOString(),
          scores: modResult.scores,
        },
      };

      this.logger.log(`Successfully uploaded image ${attachmentId} for conversation ${conversationId}`);

      // STEP 7: Clean up temporary files
      await this.imageProcessorService.cleanupFiles(tempFiles);

      return response;
    } catch (error) {
      this.logger.error(`Upload failed: ${error.message}`, error.stack);
      
      // Clean up temp files on error
      await this.imageProcessorService.cleanupFiles(tempFiles);

      throw new HttpException(
        error.message || 'Image upload failed',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Check if text contains spam keywords
   */
  private containsSpam(text: string): boolean {
    const spamKeywords = [
      'free money',
      'click here',
      'limited time',
      'act now',
      'guaranteed',
      'no risk',
      'buy now',
      'nigerian prince',
    ];

    const lowerText = text.toLowerCase();
    return spamKeywords.some(keyword => lowerText.includes(keyword));
  }

  @Post('moderate')
  @ApiOperation({
    summary: 'Moderate image content',
    description:
      'Check if an image contains inappropriate content using Google Cloud Vision API',
  })
  @ApiBody({ type: ModerateImageDto })
  @ApiResponse({
    status: 200,
    description: 'Moderation result',
    schema: {
      example: {
        isSafe: true,
        reasons: [],
        scores: {
          adult: 'VERY_UNLIKELY',
          violence: 'UNLIKELY',
          racy: 'UNLIKELY',
          spoof: 'VERY_UNLIKELY',
          medical: 'UNLIKELY',
        },
      },
    },
  })
  @ApiResponse({ status: 400, description: 'Invalid image URL' })
  async moderateImage(@Body() dto: ModerateImageDto) {
    try {
      if (!dto.imageUrl) {
        throw new HttpException('Image URL is required', HttpStatus.BAD_REQUEST);
      }

      this.logger.log(`Moderating image: ${dto.imageUrl}`);

      const result = await this.contentModerationService.moderateImage(
        dto.imageUrl,
      );

      return {
        success: true,
        ...result,
      };
    } catch (error) {
      this.logger.error('Error moderating image:', error.message);
      throw new HttpException(
        error.message || 'Failed to moderate image',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('detect-text')
  @ApiOperation({
    summary: 'Detect text in image (OCR)',
    description: 'Extract text from an image using Google Cloud Vision API',
  })
  @ApiBody({ type: ModerateImageDto })
  @ApiResponse({
    status: 200,
    description: 'Detected text',
    schema: {
      example: {
        success: true,
        text: 'Hello World',
      },
    },
  })
  async detectText(@Body() dto: ModerateImageDto) {
    try {
      if (!dto.imageUrl) {
        throw new HttpException('Image URL is required', HttpStatus.BAD_REQUEST);
      }

      this.logger.log(`Detecting text in image: ${dto.imageUrl}`);

      const text = await this.contentModerationService.detectTextInImage(
        dto.imageUrl,
      );

      return {
        success: true,
        text,
      };
    } catch (error) {
      this.logger.error('Error detecting text:', error.message);
      throw new HttpException(
        error.message || 'Failed to detect text',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('get-labels')
  @ApiOperation({
    summary: 'Get image labels',
    description: 'Get descriptive labels for an image using Google Cloud Vision API',
  })
  @ApiBody({ type: ModerateImageDto })
  @ApiResponse({
    status: 200,
    description: 'Image labels',
    schema: {
      example: {
        success: true,
        labels: ['Person', 'Smile', 'Happy', 'Clothing'],
      },
    },
  })
  async getImageLabels(@Body() dto: ModerateImageDto) {
    try {
      if (!dto.imageUrl) {
        throw new HttpException('Image URL is required', HttpStatus.BAD_REQUEST);
      }

      this.logger.log(`Getting labels for image: ${dto.imageUrl}`);

      const labels = await this.contentModerationService.getImageLabels(
        dto.imageUrl,
      );

      return {
        success: true,
        labels,
      };
    } catch (error) {
      this.logger.error('Error getting labels:', error.message);
      throw new HttpException(
        error.message || 'Failed to get labels',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Secure document upload with validation and malware scanning
   * POST /attachments/document/upload
   */
  @Post('document/upload')
  @UseInterceptors(
    FileInterceptor('document', {
      storage,
      limits: {
        fileSize: 25 * 1024 * 1024, // 25MB max for documents
      },
      fileFilter: (req, file, cb) => {
        // Allow common document types
        const allowedMimes = [
          'application/pdf',
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.ms-powerpoint',
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'text/plain',
          'application/rtf',
        ];

        if (allowedMimes.includes(file.mimetype)) {
          cb(null, true);
        } else {
          cb(
            new HttpException(
              'Invalid file type. Allowed: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, RTF',
              HttpStatus.BAD_REQUEST,
            ),
            false,
          );
        }
      },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload document securely',
    description:
      'Upload documents (PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, RTF) with security validation',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        document: {
          type: 'string',
          format: 'binary',
        },
        conversationId: {
          type: 'string',
        },
      },
    },
  })
  @ApiResponse({
    status: 200,
    description: 'Document uploaded successfully',
    schema: {
      example: {
        success: true,
        documentId: 'uuid',
        url: 'https://...',
        metadata: {
          fileName: 'document.pdf',
          fileSize: 1024000,
          mimeType: 'application/pdf',
          extension: '.pdf',
          pages: 5,
          isEncrypted: false,
        },
      },
    },
  })
  async uploadDocument(
    @UploadedFile() file: Express.Multer.File,
    @Body('conversationId') conversationId: string,
  ) {
    if (!file) {
      throw new HttpException('No file provided', HttpStatus.BAD_REQUEST);
    }

    if (!conversationId) {
      throw new HttpException(
        'Conversation ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    this.logger.log(`Document upload started: ${file.originalname}`);

    try {
      // Step 1: Validate file type using magic bytes
      const isValid = await this.documentProcessorService.validateDocumentFile(
        file.path,
      );

      if (!isValid.valid) {
        await fs.unlink(file.path);
        throw new HttpException(isValid.reason, HttpStatus.BAD_REQUEST);
      }

      // Step 2: Process document (extract metadata, scan for malware)
      const processed = await this.documentProcessorService.processDocument(
        file.path,
      );

      this.logger.log(
        `Document processed: ${processed.metadata.fileName} (${processed.metadata.fileSize} bytes)`,
      );

      // Step 3: Upload to Firebase Storage
      const uniqueFilename = `${uuidv4()}${processed.metadata.extension}`;
      const remotePath = `messages/${conversationId}/attachments/documents`;

      const uploadResult = await this.firebaseStorageService.uploadFile(
        processed.filePath,
        remotePath,
        processed.metadata.mimeType,
      );

      // Step 4: Clean up temp file
      await this.documentProcessorService.cleanupFiles([file.path]);

      this.logger.log(`Document uploaded successfully: ${remotePath}/${uploadResult.name}`);

      return {
        success: true,
        documentId: uuidv4(),
        url: uploadResult.url,
        metadata: processed.metadata,
      };
    } catch (error) {
      this.logger.error('Error uploading document:', error.message);

      // Clean up temp file on error
      try {
        await fs.unlink(file.path);
      } catch (cleanupError) {
        this.logger.warn('Failed to cleanup temp file:', cleanupError.message);
      }

      throw new HttpException(
        error.message || 'Failed to upload document',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Secure video upload with frontend-generated thumbnail and moderation
   * POST /attachments/video/upload
   * 
   * Constraints:
   * - Max duration: 10 seconds
   * - Max file size: 50MB
   * - Allowed formats: MP4, MOV, AVI
   * - Thumbnail: JPEG/PNG generated by frontend
   * 
   * Process:
   * 1. Frontend generates thumbnail using video_thumbnail package
   * 2. Frontend uploads both video + thumbnail
   * 3. Backend validates file types (magic bytes)
   * 4. Backend validates duration (max 10s) and size (max 50MB)
   * 5. Backend moderates thumbnail with Google Vision API
   * 6. Backend uploads video + thumbnail to Firebase Storage
   * 7. Return URLs and metadata
   * 
   * Benefits:
   * - No ffmpeg dependency (thumbnail generated client-side)
   * - Works on any hosting platform
   * - Faster processing (no server-side video decoding)
   */
  @Post('video/upload')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'video', maxCount: 1 },
        { name: 'thumbnail', maxCount: 1 },
      ],
      {
        storage,
        limits: {
          fileSize: 50 * 1024 * 1024, // 50MB max
        },
      },
    ),
  )
  @ApiOperation({
    summary: 'Upload video with frontend-generated thumbnail and moderation',
    description:
      'Securely upload videos (max 10s, max 50MB). Frontend generates thumbnail, backend moderates via Vision API, uploads to Firebase Storage.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        video: {
          type: 'string',
          format: 'binary',
          description: 'Video file (MP4, MOV, AVI)',
        },
        thumbnail: {
          type: 'string',
          format: 'binary',
          description: 'Thumbnail image (JPEG/PNG, generated by frontend)',
        },
        conversationId: {
          type: 'string',
          description: 'Conversation ID for organizing uploads',
        },
        duration: {
          type: 'number',
          description: 'Video duration in seconds (from frontend)',
        },
        width: {
          type: 'number',
          description: 'Video width in pixels (from frontend)',
        },
        height: {
          type: 'number',
          description: 'Video height in pixels (from frontend)',
        },
      },
      required: ['video', 'thumbnail', 'conversationId', 'duration', 'width', 'height'],
    },
  })
  @ApiResponse({
    status: 200,
    description: 'Video uploaded successfully with thumbnail',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        video: {
          type: 'object',
          properties: {
            url: { type: 'string', example: 'https://...' },
            thumbnailUrl: { type: 'string', example: 'https://...' },
            metadata: {
              type: 'object',
              properties: {
                duration: { type: 'number', example: 8.5 },
                width: { type: 'number', example: 1920 },
                height: { type: 'number', example: 1080 },
                size: { type: 'number', example: 15728640 },
                format: { type: 'string', example: 'mp4' },
              },
            },
          },
        },
        moderation: {
          type: 'object',
          properties: {
            isSafe: { type: 'boolean', example: true },
            reasons: { type: 'array', items: { type: 'string' } },
            scores: { type: 'object' },
          },
        },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description:
      'Bad request - invalid file, duration > 10s, size > 50MB, inappropriate content',
  })
  async uploadVideo(
    @UploadedFiles()
    files: {
      video?: Express.Multer.File[];
      thumbnail?: Express.Multer.File[];
    },
    @Body('conversationId') conversationId: string,
    @Body('duration') durationStr: string,
    @Body('width') widthStr: string,
    @Body('height') heightStr: string,
  ) {
    // Validate required fields
    if (!files?.video?.[0]) {
      throw new HttpException('No video file provided', HttpStatus.BAD_REQUEST);
    }

    if (!files?.thumbnail?.[0]) {
      throw new HttpException('No thumbnail file provided', HttpStatus.BAD_REQUEST);
    }

    if (!conversationId) {
      throw new HttpException(
        'conversationId is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Parse metadata from request body
    const duration = parseFloat(durationStr);
    const width = parseInt(widthStr, 10);
    const height = parseInt(heightStr, 10);

    if (isNaN(duration) || isNaN(width) || isNaN(height)) {
      throw new HttpException(
        'Invalid metadata: duration, width, and height must be numbers',
        HttpStatus.BAD_REQUEST,
      );
    }

    const videoFile = files.video[0];
    const thumbnailFile = files.thumbnail[0];
    const videoPath = videoFile.path;
    const thumbnailPath = thumbnailFile.path;

    try {
      this.logger.log(`📹 Processing video upload: ${videoFile.originalname}`);
      this.logger.log(`Video path: ${videoPath}`);
      this.logger.log(`Thumbnail path: ${thumbnailPath}`);
      this.logger.log(`Metadata - Duration: ${duration}s, Dimensions: ${width}x${height}`);

      // Step 1: Validate video file type (magic bytes)
      const videoBuffer = await fs.readFile(videoPath);
      await this.videoProcessorService.validateVideoFile(videoBuffer);
      this.logger.log('✅ Video file type validated');

      // Step 2: Validate thumbnail file type (magic bytes)
      const thumbnailBuffer = await fs.readFile(thumbnailPath);
      await this.videoProcessorService.validateThumbnailFile(thumbnailBuffer);
      this.logger.log('✅ Thumbnail file type validated');

      // Step 3: Process video (validate, moderate thumbnail)
      const processed = await this.videoProcessorService.processVideo(
        videoPath,
        thumbnailPath,
        { duration, width, height },
      );

      this.logger.log(
        `✅ Video processed - Duration: ${processed.metadata.duration.toFixed(1)}s, Size: ${(processed.metadata.size / (1024 * 1024)).toFixed(2)}MB`,
      );
      this.logger.log(`✅ Moderation passed: ${processed.moderationResult.isSafe}`);

      // Step 4: Upload video to Firebase Storage
      const videoFileName = `videos/${conversationId}/${uuidv4()}.${processed.metadata.format}`;
      const videoUrl = await this.firebaseStorageService.uploadFile(
        videoPath,
        videoFileName,
        `video/${processed.metadata.format}`,
      );
      this.logger.log(`✅ Video uploaded: ${videoUrl}`);

      // Step 5: Upload thumbnail to Firebase Storage
      const thumbnailFileName = `videos/${conversationId}/${uuidv4()}_thumb.jpg`;
      const thumbnailUrl = await this.firebaseStorageService.uploadFile(
        thumbnailPath,
        thumbnailFileName,
        'image/jpeg',
      );
      this.logger.log(`✅ Thumbnail uploaded: ${thumbnailUrl}`);

      // Step 6: Clean up temporary files
      await this.videoProcessorService.cleanupFiles([videoPath, thumbnailPath]);
      this.logger.log('✅ Temporary files cleaned up');

      // Step 7: Return success response
      return {
        success: true,
        video: {
          url: videoUrl,
          thumbnailUrl: thumbnailUrl,
          metadata: {
            duration: processed.metadata.duration,
            width: processed.metadata.width,
            height: processed.metadata.height,
            size: processed.metadata.size,
            format: processed.metadata.format,
          },
        },
        moderation: {
          isSafe: processed.moderationResult.isSafe,
          reasons: processed.moderationResult.reasons,
          scores: processed.moderationResult.scores,
        },
      };
    } catch (error) {
      this.logger.error(`❌ Video upload failed: ${error.message}`, error.stack);

      // Clean up files on error
      try {
        await fs.unlink(videoPath);
        await fs.unlink(thumbnailPath);
      } catch (cleanupError) {
        this.logger.warn(`Failed to cleanup files: ${cleanupError.message}`);
      }

      throw new HttpException(
        error.message || 'Failed to upload video',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}
