#!/bin/bash

# Instagram Integration Fix Deployment Script
# This script deploys the updated Instagram service that fixes the Graph API error

echo "🚀 Deploying Instagram Integration Fix..."

# Navigate to backend directory
cd "$(dirname "$0")"

# Check if we're in the backend directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Not in backend directory. Please run from backend/"
    exit 1
fi

echo "📦 Installing dependencies..."
npm install

echo "🔨 Building project..."
npm run build

echo "🔥 Deploying to Firebase..."
firebase deploy --only functions

echo "✅ Deployment complete!"
echo ""
echo "🔍 Testing the fix:"
echo "1. The service now discovers Instagram Business Account IDs from connected Facebook Pages"
echo "2. Uses Page tokens instead of User tokens for Instagram API calls" 
echo "3. Caches discovered Instagram user ID for faster subsequent calls"
echo ""
echo "📊 Expected behavior:"
echo "- First call: Discovers IG user ID from pages (may take longer)"
echo "- Subsequent calls: Uses cached IG user ID (faster)"
echo "- API calls now target: /{ig_user_id}/media instead of /{facebook_user_id}/media"
echo ""
echo "🧪 Test with integration ID: ZlTZKFbKZ2aqhkI3reZh"
