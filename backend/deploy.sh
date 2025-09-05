#!/bin/bash

# Seafrika Backend Deployment Script
echo "🚀 Starting Seafrika Backend Deployment..."

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI not found. Please install it first:"
    echo "   Download from: https://cloud.google.com/sdk/docs/install-windows"
    exit 1
fi

# Set project
echo "📋 Setting Google Cloud project..."
gcloud config set project sme-afrika

# Build the project
echo "🔨 Building the project..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

# Deploy function with environment variables
echo "📦 Deploying to Google Cloud Functions..."
gcloud functions deploy seafrikaApi \
  --runtime=nodejs20 \
  --trigger-http \
  --allow-unauthenticated \
  --source=dist \
  --entry-point=seafrikaApi \
  --memory=1GB \
  --timeout=540s \
  --set-env-vars NODE_ENV=production,FIREBASE_PROJECT_ID=sme-afrika,FIREBASE_PROJECT_NUMBER=229268356345,FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@sme-afrika.iam.gserviceaccount.com,FIREBASE_STORAGE_BUCKET=sme-afrika.firebasestorage.app,INSTAGRAM_APP_ID=779189224487576,INSTAGRAM_VERIFY_TOKEN=IGWebhookVerifyToken_f4c9d7b82e6a47cbb913e2e50dca5a91-verify-token,FACEBOOK_APP_ID=744815985034707,API_PREFIX=api,PORT=8080

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    echo ""
    echo "🔗 Your webhook URL is:"
    echo "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/instagram/webhook"
    echo ""
    echo "📖 API Documentation:"
    echo "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/docs"
    echo ""
    echo "🔑 Verify Token for Instagram:"
    echo "IGWebhookVerifyToken_f4c9d7b82e6a47cbb913e2e50dca5a91-verify-token"
else
    echo "❌ Deployment failed!"
    exit 1
fi
