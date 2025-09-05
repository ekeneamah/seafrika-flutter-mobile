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
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { FirebaseAuthService, CreateUserData, UpdateUserData } from './firebase-auth.service';
import { FirebaseStorageService, UploadFileOptions } from './firebase-storage.service';
import { FirebaseMessagingService, NotificationData, PushNotificationOptions } from './firebase-messaging.service';
// import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('Firebase Services')
@Controller('firebase')
// @UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class FirebaseController {
  constructor(
    private firebaseAuth: FirebaseAuthService,
    private firebaseStorage: FirebaseStorageService,
    private firebaseMessaging: FirebaseMessagingService,
  ) {}

  // ============ AUTHENTICATION ENDPOINTS ============

  @Post('auth/users')
  @ApiOperation({ summary: 'Create new Firebase user' })
  @ApiResponse({ status: 201, description: 'User created successfully' })
  async createUser(@Body() userData: CreateUserData) {
    return this.firebaseAuth.createUser(userData);
  }

  @Get('auth/users/:uid')
  @ApiOperation({ summary: 'Get user by UID' })
  @ApiResponse({ status: 200, description: 'User retrieved successfully' })
  async getUserByUid(@Param('uid') uid: string) {
    return this.firebaseAuth.getUserByUid(uid);
  }

  @Put('auth/users/:uid')
  @ApiOperation({ summary: 'Update user' })
  @ApiResponse({ status: 200, description: 'User updated successfully' })
  async updateUser(@Param('uid') uid: string, @Body() userData: UpdateUserData) {
    return this.firebaseAuth.updateUser(uid, userData);
  }

  @Delete('auth/users/:uid')
  @ApiOperation({ summary: 'Delete user' })
  @ApiResponse({ status: 200, description: 'User deleted successfully' })
  async deleteUser(@Param('uid') uid: string) {
    return this.firebaseAuth.deleteUser(uid);
  }

  @Post('auth/verify-token')
  @ApiOperation({ summary: 'Verify Firebase ID token' })
  @ApiResponse({ status: 200, description: 'Token verified successfully' })
  async verifyToken(@Body('idToken') idToken: string) {
    return this.firebaseAuth.verifyToken(idToken);
  }

  @Post('auth/custom-token')
  @ApiOperation({ summary: 'Create custom token' })
  @ApiResponse({ status: 200, description: 'Custom token created successfully' })
  async createCustomToken(
    @Body('uid') uid: string,
    @Body('claims') claims?: object
  ) {
    const token = await this.firebaseAuth.createCustomToken(uid, claims);
    return { customToken: token };
  }

  @Post('auth/users/:uid/disable')
  @ApiOperation({ summary: 'Disable user account' })
  @ApiResponse({ status: 200, description: 'User disabled successfully' })
  async disableUser(@Param('uid') uid: string) {
    return this.firebaseAuth.disableUser(uid);
  }

  @Post('auth/users/:uid/enable')
  @ApiOperation({ summary: 'Enable user account' })
  @ApiResponse({ status: 200, description: 'User enabled successfully' })
  async enableUser(@Param('uid') uid: string) {
    return this.firebaseAuth.enableUser(uid);
  }

  @Get('auth/users')
  @ApiOperation({ summary: 'List users with pagination' })
  @ApiResponse({ status: 200, description: 'Users retrieved successfully' })
  async listUsers(
    @Query('maxResults') maxResults?: number,
    @Query('pageToken') pageToken?: string
  ) {
    return this.firebaseAuth.listUsers(maxResults, pageToken);
  }

  // ============ STORAGE ENDPOINTS ============

  @Post('storage/upload')
  @ApiOperation({ summary: 'Upload file to Firebase Storage' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 201, description: 'File uploaded successfully' })
  @UseInterceptors(FileInterceptor('file'))
  async uploadFile(
    @UploadedFile() file: any,
    @Body('destination') destination?: string,
    @Body('makePublic') makePublic?: string,
    @Body('generateSignedUrl') generateSignedUrl?: string
  ) {
    const options: UploadFileOptions = {
      destination,
      makePublic: makePublic === 'true',
      generateSignedUrl: generateSignedUrl === 'true',
    };

    return this.firebaseStorage.uploadFromBuffer(
      file.buffer,
      file.originalname,
      file.mimetype,
      options
    );
  }

  @Delete('storage/files/:fileName')
  @ApiOperation({ summary: 'Delete file from Firebase Storage' })
  @ApiResponse({ status: 200, description: 'File deleted successfully' })
  async deleteFile(@Param('fileName') fileName: string) {
    await this.firebaseStorage.deleteFile(fileName);
    return { message: 'File deleted successfully' };
  }

  @Get('storage/files/:fileName/metadata')
  @ApiOperation({ summary: 'Get file metadata' })
  @ApiResponse({ status: 200, description: 'File metadata retrieved successfully' })
  async getFileMetadata(@Param('fileName') fileName: string) {
    return this.firebaseStorage.getFileMetadata(fileName);
  }

  @Get('storage/files/:fileName/signed-url')
  @ApiOperation({ summary: 'Get signed URL for file' })
  @ApiResponse({ status: 200, description: 'Signed URL generated successfully' })
  async getSignedUrl(
    @Param('fileName') fileName: string,
    @Query('action') action: 'read' | 'write' | 'delete' = 'read',
    @Query('expiration') expiration?: string
  ) {
    const expirationDate = expiration ? new Date(expiration) : undefined;
    const signedUrl = await this.firebaseStorage.getSignedUrl(fileName, action, expirationDate);
    return { signedUrl };
  }

  @Post('storage/files/:fileName/make-public')
  @ApiOperation({ summary: 'Make file public' })
  @ApiResponse({ status: 200, description: 'File made public successfully' })
  async makeFilePublic(@Param('fileName') fileName: string) {
    const publicUrl = await this.firebaseStorage.makeFilePublic(fileName);
    return { publicUrl };
  }

  @Get('storage/files')
  @ApiOperation({ summary: 'List files in storage' })
  @ApiResponse({ status: 200, description: 'Files listed successfully' })
  async listFiles(
    @Query('prefix') prefix?: string,
    @Query('maxResults') maxResults?: number
  ) {
    return this.firebaseStorage.listFiles(prefix, maxResults);
  }

  // ============ MESSAGING ENDPOINTS ============

  @Post('messaging/send-to-device')
  @ApiOperation({ summary: 'Send notification to single device' })
  @ApiResponse({ status: 200, description: 'Notification sent successfully' })
  async sendToDevice(
    @Body('token') token: string,
    @Body('notification') notification: NotificationData,
    @Body('options') options?: PushNotificationOptions
  ) {
    const messageId = await this.firebaseMessaging.sendToDevice(token, notification, options);
    return { messageId };
  }

  @Post('messaging/send-to-multiple')
  @ApiOperation({ summary: 'Send notification to multiple devices' })
  @ApiResponse({ status: 200, description: 'Notifications sent successfully' })
  async sendToMultipleDevices(
    @Body('tokens') tokens: string[],
    @Body('notification') notification: NotificationData,
    @Body('options') options?: PushNotificationOptions
  ) {
    return this.firebaseMessaging.sendToMultipleDevices(tokens, notification, options);
  }

  @Post('messaging/send-to-topic')
  @ApiOperation({ summary: 'Send notification to topic' })
  @ApiResponse({ status: 200, description: 'Notification sent to topic successfully' })
  async sendToTopic(
    @Body('topic') topic: string,
    @Body('notification') notification: NotificationData,
    @Body('options') options?: PushNotificationOptions
  ) {
    const messageId = await this.firebaseMessaging.sendToTopic(topic, notification, options);
    return { messageId };
  }

  @Post('messaging/subscribe-to-topic')
  @ApiOperation({ summary: 'Subscribe tokens to topic' })
  @ApiResponse({ status: 200, description: 'Tokens subscribed to topic successfully' })
  async subscribeToTopic(
    @Body('tokens') tokens: string[],
    @Body('topic') topic: string
  ) {
    return this.firebaseMessaging.subscribeToTopic(tokens, topic);
  }

  @Post('messaging/unsubscribe-from-topic')
  @ApiOperation({ summary: 'Unsubscribe tokens from topic' })
  @ApiResponse({ status: 200, description: 'Tokens unsubscribed from topic successfully' })
  async unsubscribeFromTopic(
    @Body('tokens') tokens: string[],
    @Body('topic') topic: string
  ) {
    return this.firebaseMessaging.unsubscribeFromTopic(tokens, topic);
  }

  @Post('messaging/send-data')
  @ApiOperation({ summary: 'Send data-only message' })
  @ApiResponse({ status: 200, description: 'Data message sent successfully' })
  async sendDataMessage(
    @Body('token') token: string,
    @Body('data') data: { [key: string]: string },
    @Body('options') options?: PushNotificationOptions
  ) {
    const messageId = await this.firebaseMessaging.sendDataMessage(token, data, options);
    return { messageId };
  }

  @Post('messaging/validate-token')
  @ApiOperation({ summary: 'Validate FCM token' })
  @ApiResponse({ status: 200, description: 'Token validation result' })
  async validateToken(@Body('token') token: string) {
    const isValid = await this.firebaseMessaging.validateToken(token);
    return { isValid };
  }
}
