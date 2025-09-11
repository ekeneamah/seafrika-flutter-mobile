#!/bin/bash

# Deploy Instagram Comments Feature
# This script deploys the backend changes for Instagram comments functionality

echo "🚀 Deploying Instagram Comments Feature..."

# Check if we're in the backend directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the backend directory"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build the project
echo "🔨 Building project..."
npm run build

# Deploy to Firebase Functions
echo "🌐 Deploying to Firebase Functions..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo "✅ Instagram Comments Feature deployed successfully!"
    echo "📋 New endpoint available:"
    echo "   GET /api/integrations/instagram/{integrationId}/media/{postId}/comments"
    echo ""
    echo "🧪 Test the deployment:"
    echo "   1. Open your Flutter app"
    echo "   2. Navigate to Instagram Posts"
    echo "   3. Tap the comment icon on any post"
    echo "   4. Comments should load in a bottom sheet"
else
    echo "❌ Deployment failed! Check the logs above for errors."
    exit 1
fi
