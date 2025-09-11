#!/usr/bin/env pwsh

# Deploy Instagram Comments Feature
# This script deploys the backend changes for Instagram comments functionality

Write-Host "🚀 Deploying Instagram Comments Feature..." -ForegroundColor Green

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
    Write-Host "✅ Instagram Comments Feature deployed successfully!" -ForegroundColor Green
    Write-Host "📋 New endpoint available:" -ForegroundColor Cyan
    Write-Host "   GET /api/integrations/instagram/{integrationId}/media/{postId}/comments" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🧪 Test the deployment:" -ForegroundColor Yellow
    Write-Host "   1. Open your Flutter app" -ForegroundColor White
    Write-Host "   2. Navigate to Instagram Posts" -ForegroundColor White
    Write-Host "   3. Tap the comment icon on any post" -ForegroundColor White
    Write-Host "   4. Comments should load in a bottom sheet" -ForegroundColor White
} else {
    Write-Host "❌ Deployment failed! Check the logs above for errors." -ForegroundColor Red
    exit 1
}
