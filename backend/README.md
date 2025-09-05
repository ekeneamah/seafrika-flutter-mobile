# Seafrika Backend API

A NestJS-based REST API backend for the Seafrika mobile application, designed to work with Google Cloud Functions and Firestore.

## Features

- **Authentication**: JWT-based authentication with Passport
- **Products Management**: Full CRUD operations for products
- **Business Integration**: Multi-tenant business support
- **Firestore Integration**: Real-time database with Google Cloud Firestore
- **Instagram Webhooks**: Real-time Instagram notifications and events
- **API Documentation**: Auto-generated Swagger/OpenAPI documentation
- **Google Cloud Functions**: Serverless deployment support
- **TypeScript**: Full type safety and modern JavaScript features

## Technology Stack

- **Framework**: NestJS
- **Database**: Google Cloud Firestore
- **Authentication**: JWT with Passport.js
- **Documentation**: Swagger/OpenAPI
- **Deployment**: Google Cloud Functions
- **Language**: TypeScript

## Getting Started

### Prerequisites

- Node.js 18 or higher
- npm or yarn
- Google Cloud account with Firestore enabled
- Google Cloud CLI (for deployment)

### Installation

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. Build the project:
```bash
npm run build
```

4. Start development server:
```bash
npm run start:dev
```

The API will be available at `http://localhost:3000` and documentation at `http://localhost:3000/api/docs`.

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration
- `GET /api/auth/profile` - Get user profile

### Products
- `GET /api/products` - Get all products
- `POST /api/products` - Create new product
- `GET /api/products/:id` - Get product by ID
- `PUT /api/products/:id` - Update product
- `DELETE /api/products/:id` - Delete product
- `GET /api/products/business/:businessId` - Get products by business
- `GET /api/products/low-stock/:businessId` - Get low stock products

### Instagram Webhooks
- `GET /api/webhooks/instagram` - Webhook verification
- `POST /api/webhooks/instagram` - Receive Instagram notifications
- `GET /api/webhooks/instagram/test` - Test webhook endpoint
- `GET /api/webhooks/management/instagram/events/:accountId` - Get webhook events
- `GET /api/webhooks/management/instagram/media/:accountId` - Get media events
- `GET /api/webhooks/management/status` - Webhook service status

## Project Structure

```
src/
├── auth/                 # Authentication module
│   ├── decorators/      # Custom decorators
│   ├── guards/          # Auth guards
│   ├── strategies/      # Passport strategies
│   └── auth.module.ts   # Auth module
├── products/            # Products module
│   ├── dto/            # Data transfer objects
│   ├── products.controller.ts
│   ├── products.service.ts
│   └── products.module.ts
├── firestore/          # Firestore service
│   └── firestore.service.ts
├── app.module.ts       # Main app module
├── main.ts            # Application entry point
└── index.ts           # Google Cloud Functions entry point
```

## Deployment

### Google Cloud Functions

1. Build the project:
```bash
npm run build
```

2. Deploy to Google Cloud Functions:
```bash
gcloud functions deploy seafrikaApi \
  --runtime=nodejs20 \
  --trigger-http \
  --allow-unauthenticated \
  --source=dist \
  --entry-point=seafrikaApi
```

### Environment Variables

Set these environment variables for production:

- `FIRESTORE_PROJECT_ID`: Your Google Cloud project ID
- `JWT_SECRET`: Secret key for JWT token signing
- `NODE_ENV`: Set to "production" for production deployment

## API Documentation

When running the server, API documentation is available at `/api/docs`. The documentation is auto-generated using Swagger/OpenAPI and provides:

- Interactive API explorer
- Request/response schemas
- Authentication requirements
- Example requests and responses

## Security

- JWT-based authentication
- Route guards for protected endpoints
- Input validation using DTOs
- CORS configuration
- Environment-based configuration

## Mobile App Integration

This backend is designed to work seamlessly with the Seafrika Flutter mobile app. The mobile app can connect using axios or any HTTP client:

```javascript
// Example axios configuration
const api = axios.create({
  baseURL: 'https://your-cloud-function-url/api',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});
```

## Development Scripts

- `npm run start:dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm run start:prod` - Start production server
- `npm run test` - Run tests
- `npm run lint` - Run ESLint

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new features
5. Submit a pull request

## License

This project is licensed under the MIT License.
