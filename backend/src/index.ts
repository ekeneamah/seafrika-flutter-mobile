import { NestFactory } from '@nestjs/core';
import { ExpressAdapter } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import * as express from 'express';
import * as functions from '@google-cloud/functions-framework';

// Create Express instance
const server = express();

// Create NestJS app
const createNestApp = async (expressInstance: any) => {
  const app = await NestFactory.create(
    AppModule,
    new ExpressAdapter(expressInstance),
  );

  // Enable CORS
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // Setup Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('Seafrika API')
    .setDescription('The Seafrika API for mobile app')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  // Global prefix
  app.setGlobalPrefix('api');

  await app.init();
  return app;
};

// Initialize the app
let app: any;
const initializeApp = async () => {
  if (!app) {
    app = await createNestApp(server);
  }
  return app;
};

// Google Cloud Function handler
functions.http('seafrikaApi', async (req: any, res: any) => {
  await initializeApp();
  server(req, res);
});

// For local development
if (process.env.NODE_ENV !== 'production') {
  const startServer = async () => {
    const app = await createNestApp(server);
    const port = process.env.PORT || 3000;
    await app.listen(port);
    console.log(`Application is running on: http://localhost:${port}`);
    console.log(`Swagger docs available at: http://localhost:${port}/api/docs`);
  };
  
  startServer().catch(error => {
    console.error('Error starting server:', error);
  });
}
