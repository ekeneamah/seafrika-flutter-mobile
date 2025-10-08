import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppService } from './app.service';

@ApiTags('Health')
@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly configService: ConfigService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Health check' })
  @ApiResponse({ status: 200, description: 'API is running' })
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('health')
  @ApiOperation({ summary: 'Health status' })
  @ApiResponse({ status: 200, description: 'Service health status' })
  getHealth() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'Seafrika API',
      version: '1.0.0',
    };
  }

 /*  @Get('env')
  @ApiOperation({ summary: 'Environment variables' })
  @ApiResponse({ status: 200, description: 'Environment variables and configuration' })
  getEnvironmentVariables() {
    // Get common environment variables
    const envVars = {
      NODE_ENV: this.configService.get<string>('NODE_ENV'),
      FIREBASE_PROJECT_ID: this.configService.get<string>('FIREBASE_PROJECT_ID'),
      FIREBASE_CLIENT_EMAIL: this.configService.get<string>('FIREBASE_CLIENT_EMAIL') ? 'SET' : 'NOT SET',
      FIREBASE_PRIVATE_KEY: this.configService.get<string>('FIREBASE_PRIVATE_KEY') ? 'SET' : 'NOT SET',
      GOOGLE_APPLICATION_CREDENTIALS: this.configService.get<string>('GOOGLE_APPLICATION_CREDENTIALS'),
      INSTAGRAM_VERIFY_TOKEN: this.configService.get<string>('INSTAGRAM_VERIFY_TOKEN') ? 'SET' : 'NOT SET',
      FACEBOOK_APP_ID: this.configService.get<string>('FACEBOOK_APP_ID'),
      FACEBOOK_APP_SECRET: this.configService.get<string>('FACEBOOK_APP_SECRET') ? 'SET' : 'NOT SET',
      INSTAGRAM_APP_ID: this.configService.get<string>('INSTAGRAM_APP_ID'),
      INSTAGRAM_APP_SECRET: this.configService.get<string>('INSTAGRAM_APP_SECRET') ? 'SET' : 'NOT SET',
      JWT_SECRET: this.configService.get<string>('JWT_SECRET') ? 'SET' : 'NOT SET',
      // Add other environment variables as needed
    }; 

    return {
      timestamp: new Date().toISOString(),
      environment: envVars,
      note: 'Sensitive values are masked for security',
    };
  }*/
}
