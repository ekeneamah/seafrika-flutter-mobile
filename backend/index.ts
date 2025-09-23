import { NestFactory } from '@nestjs/core';
import { ExpressAdapter } from '@nestjs/platform-express';
import { AppModule } from './src/app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import * as express from 'express';
import * as functions from 'firebase-functions';

const server = express();

// TikTok verification file handling via environment variables
const RAW = process.env.TIKTOK_VERIFY_TEXT ?? '';
const B64 = process.env.TIKTOK_VERIFY_BASE64 ?? '';
const VERIFY_TEXT = (B64 ? Buffer.from(B64, 'base64').toString('utf8') : RAW)
  .replace(/^\uFEFF/, '')   // strip BOM if present
  .trimEnd();               // avoid trailing newline/space issues

// Serve landing page for the app
server.get(['/', '/landing', '/home'], (req, res) => {
  const landingPageHtml = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Seafrika - Vendor Management Platform</title>
    <meta name="description" content="Seafrika is a comprehensive vendor management platform connecting businesses with social media integrations, analytics, and seamless operations.">
    <meta name="keywords" content="vendor management, business platform, social media integration, TikTok, Facebook, Instagram, analytics">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            padding: 60px 0;
            color: white;
        }
        
        .logo {
            font-size: 3rem;
            font-weight: 700;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .tagline {
            font-size: 1.2rem;
            opacity: 0.9;
            margin-bottom: 30px;
        }
        
        .content {
            background: white;
            border-radius: 20px;
            padding: 40px;
            margin: 20px 0;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        }
        
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin: 40px 0;
        }
        
        .feature {
            text-align: center;
            padding: 30px;
            background: #f8f9fa;
            border-radius: 15px;
            transition: transform 0.3s ease;
        }
        
        .feature:hover {
            transform: translateY(-5px);
        }
        
        .feature-icon {
            font-size: 3rem;
            margin-bottom: 20px;
        }
        
        .feature h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.3rem;
        }
        
        .cta {
            text-align: center;
            margin: 40px 0;
        }
        
        .btn {
            display: inline-block;
            padding: 15px 30px;
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            text-decoration: none;
            border-radius: 50px;
            font-weight: 600;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.6);
        }
        
        .api-info {
            background: #e3f2fd;
            border: 1px solid #90caf9;
            border-radius: 10px;
            padding: 20px;
            margin: 30px 0;
        }
        
        .api-info h3 {
            color: #1565c0;
            margin-bottom: 10px;
        }
        
        .api-link {
            color: #1976d2;
            text-decoration: none;
            font-weight: 500;
        }
        
        .api-link:hover {
            text-decoration: underline;
        }
        
        .footer {
            text-align: center;
            padding: 40px 0;
            color: white;
            opacity: 0.8;
        }
        
        @media (max-width: 768px) {
            .logo {
                font-size: 2rem;
            }
            
            .content {
                padding: 20px;
            }
            
            .features {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1 class="logo">🌊 Seafrika</h1>
            <p class="tagline">Comprehensive Vendor Management Platform</p>
            <p>Connecting businesses with powerful social media integrations and analytics</p>
        </header>
        
        <main class="content">
            <section>
                <h2 style="text-align: center; margin-bottom: 30px; color: #667eea;">Welcome to Seafrika</h2>
                <p style="text-align: center; font-size: 1.1rem; margin-bottom: 40px;">
                    Seafrika is a cutting-edge vendor management platform designed to streamline business operations 
                    and enhance social media presence through seamless integrations.
                </p>
                
                <div class="features">
                    <div class="feature">
                        <div class="feature-icon">📱</div>
                        <h3>Social Media Integration</h3>
                        <p>Connect with TikTok, Facebook, Instagram, and WhatsApp Business APIs for comprehensive social media management.</p>
                    </div>
                    
                    <div class="feature">
                        <div class="feature-icon">📊</div>
                        <h3>Analytics & Insights</h3>
                        <p>Get detailed analytics and insights to understand your business performance and customer engagement.</p>
                    </div>
                    
                    <div class="feature">
                        <div class="feature-icon">🔐</div>
                        <h3>Secure & Reliable</h3>
                        <p>Built with enterprise-grade security and reliability using Firebase and Google Cloud Platform.</p>
                    </div>
                    
                    <div class="feature">
                        <div class="feature-icon">⚡</div>
                        <h3>Real-time Operations</h3>
                        <p>Real-time webhook processing, inventory management, and customer communications.</p>
                    </div>
                </div>
            </section>
            
            <div class="api-info">
                <h3>🔗 Developer Resources</h3>
                <p>Access our comprehensive API documentation and developer tools:</p>
                <br>
                <p>
                    <strong>API Documentation:</strong> 
                    <a href="/api" class="api-link">https://seafrikaapi-u53tcgosiq-uc.a.run.app/api</a>
                </p>
                <p>
                    <strong>Base API URL:</strong> 
                    <a href="/api/v1" class="api-link">https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/v1</a>
                </p>
            </div>
            
            <div class="cta">
                <h3 style="margin-bottom: 20px;">Ready to Get Started?</h3>
                <p style="margin-bottom: 30px;">Join thousands of vendors already using Seafrika to grow their business.</p>
                <a href="https://seafrika-vendor.web.app" class="btn">Launch Vendor App</a>
            </div>
        </main>
        
        <footer class="footer">
            <p>&copy; 2025 Seafrika. All rights reserved.</p>
            <p>Empowering vendors, connecting communities.</p>
        </footer>
    </div>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour
  res.status(200).send(landingPageHtml);
});

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

  // Conditional middleware to prevent raw body parsing on file upload routes
  // This ensures multipart/form-data is properly handled by multer
  expressInstance.use((req, res, next) => {
    // Skip any raw body parsing for file upload routes
    if (req.path === '/api/webhooks/tiktok/upload-verification') {
      return next();
    }
    next();
  });

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
