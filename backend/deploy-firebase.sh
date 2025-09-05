#!/bin/bash

# Seafrika Backend - Firebase Functions Deployment Script
echo "🚀 Deploying Seafrika Backend to Firebase Functions..."

# Check if we're in the backend directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the backend directory"
    exit 1
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found. Make sure environment variables are configured in Firebase Functions"
fi

# Build the project
echo "🔨 Building the project..."
npm run build

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "❌ Build failed! Please fix the errors and try again."
    exit 1
fi

# Deploy to Firebase Functions
echo "🚀 Deploying to Firebase Functions..."
firebase deploy --only functions

# Check deployment status
if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    echo ""
    echo "🌐 Your API is now available at:"
    echo "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api"
    echo ""
    echo "📋 Swagger documentation:"
    echo "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api"
    echo ""
    echo "🔗 Instagram Webhook URL:"
    echo "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/webhooks/instagram"
else
    echo "❌ Deployment failed! Check the error messages above."
    exit 1
fi
