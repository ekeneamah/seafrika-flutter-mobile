import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import * as compression from 'compression';
import * as helmet from 'helmet';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  const configService = app.get(ConfigService);

  // Security
  app.use(helmet.default());
  app.use(compression());

  // CORS
  app.enableCors({
    origin: [
      'http://localhost:3000',
      'http://localhost:5000',
      'https://seafrika-vendor.web.app',
      'https://seafrika-vendor.firebaseapp.com',
    ],
    credentials: true,
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // Conditional middleware to prevent raw body parsing on file upload routes
  app.use((req, res, next) => {
    // Skip raw body parsing for multipart file upload routes
    if (req.path === '/api/v1/webhooks/tiktok/upload-verification') {
      return next();
    }
    next();
  });

  // API prefix
  app.setGlobalPrefix('api/v1');

  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('Seafrika API')
    .setDescription('The Seafrika Vendor Platform API')
    .setVersion('1.0')
    //.addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = configService.get('PORT') || 3000;
  await app.listen(port);
  console.log(`Application is running on: ${await app.getUrl()}`);
}

bootstrap();
