#!/bin/bash

# Deploy Instagram Post Creation & Comment Reply Features
# This script deploys the backend changes for Instagram post creation and comment reply functionality

echo "🚀 Deploying Instagram Post Creation & Reply Features..."

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
    echo "✅ Instagram Post Creation & Reply Features deployed successfully!"
    echo "📋 New endpoints available:"
    echo "   POST /api/integrations/instagram/{integrationId}/media/{postId}/comments/{commentId}/replies"
    echo "   POST /api/integrations/instagram/{integrationId}/media"
    echo ""
    echo "🧪 Test the deployment:"
    echo "   1. Open your Flutter app"
    echo "   2. Navigate to Instagram Posts"
    echo "   3. Tap the + button to create a new post"
    echo "   4. Tap reply icon on comments to reply"
    echo ""
    echo "⚠️  Required Permissions:"
    echo "   - instagram_content_publish (for creating posts)"
    echo "   - instagram_manage_comments (for replying to comments)"
else
    echo "❌ Deployment failed! Check the logs above for errors."
    exit 1
fi
