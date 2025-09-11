#!/usr/bin/env pwsh

# Deploy Instagram Post Creation & Comment Reply Features
# This script deploys the backend changes for Instagram post creation and comment reply functionality

Write-Host "🚀 Deploying Instagram Post Creation & Reply Features..." -ForegroundColor Green

# Check if we're in the backend directory
if (-not (Test-Path "package.json")) {
    Write-Host "❌ Error: Please run this script from the backend directory" -ForegroundColor Red
    exit 1
}

# Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
npm install

# Build the project
Write-Host "🔨 Building project..." -ForegroundColor Yellow
npm run build

# Deploy to Firebase Functions
Write-Host "🌐 Deploying to Firebase Functions..." -ForegroundColor Yellow
firebase deploy --only functions

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Instagram Post Creation & Reply Features deployed successfully!" -ForegroundColor Green
    Write-Host "📋 New endpoints available:" -ForegroundColor Cyan
    Write-Host "   POST /api/integrations/instagram/{integrationId}/media/{postId}/comments/{commentId}/replies" -ForegroundColor Cyan
    Write-Host "   POST /api/integrations/instagram/{integrationId}/media" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🧪 Test the deployment:" -ForegroundColor Yellow
    Write-Host "   1. Open your Flutter app" -ForegroundColor White
    Write-Host "   2. Navigate to Instagram Posts" -ForegroundColor White
    Write-Host "   3. Tap the + button to create a new post" -ForegroundColor White
    Write-Host "   4. Tap reply icon on comments to reply" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  Required Permissions:" -ForegroundColor Yellow
    Write-Host "   - instagram_content_publish (for creating posts)" -ForegroundColor White
    Write-Host "   - instagram_manage_comments (for replying to comments)" -ForegroundColor White
} else {
    Write-Host "❌ Deployment failed! Check the logs above for errors." -ForegroundColor Red
    exit 1
}
