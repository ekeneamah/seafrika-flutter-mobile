import { NestFactory } from '@nestjs/core';
import { ExpressAdapter } from '@nestjs/platform-express';
import { AppModule } from './src/app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import * as express from 'express';
import * as functions from 'firebase-functions';

const server = express();

async function createNestServer(expressInstance: express.Express) {
  const adapter = new ExpressAdapter(expressInstance);
  const app = await NestFactory.create(AppModule, adapter, {
    logger: ['error', 'warn', 'log'],
  });

  // Enable CORS
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // Global validation pipe
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }));

  // API prefix
  app.setGlobalPrefix('api');

  // Swagger setup
  const config = new DocumentBuilder()
    .setTitle('Seafrika Backend API')
    .setDescription('Backend API for Seafrika Mobile Application with Firebase Integration')
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();
  
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document);

  await app.init();
  return app;
}

// Initialize the server
createNestServer(server)
  .then(() => console.log('Nest Ready'))
  .catch(err => console.error('Nest broken', err));

// Export the Cloud Function
export const seafrikaApi = functions.https.onRequest(server);

// Export for local development
export const app = server;
