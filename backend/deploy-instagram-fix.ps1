# Instagram Integration Fix Deployment Script
# This script deploys the updated Instagram service that fixes the Graph API error

Write-Host "🚀 Deploying Instagram Integration Fix..." -ForegroundColor Green

# Check if we're in the backend directory
if (-not (Test-Path "package.json")) {
    Write-Host "❌ Error: Not in backend directory. Please run from backend/" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ npm install failed" -ForegroundColor Red
    exit 1
}

Write-Host "🔨 Building project..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host "🔥 Deploying to Firebase..." -ForegroundColor Yellow
firebase deploy --only functions

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Firebase deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🔍 Testing the fix:" -ForegroundColor Cyan
Write-Host "1. The service now discovers Instagram Business Account IDs from connected Facebook Pages"
Write-Host "2. Uses Page tokens instead of User tokens for Instagram API calls" 
Write-Host "3. Caches discovered Instagram user ID for faster subsequent calls"
Write-Host ""
Write-Host "📊 Expected behavior:" -ForegroundColor Cyan
Write-Host "- First call: Discovers IG user ID from pages (may take longer)"
Write-Host "- Subsequent calls: Uses cached IG user ID (faster)"
Write-Host "- API calls now target: /{ig_user_id}/media instead of /{facebook_user_id}/media"
Write-Host ""
Write-Host "🧪 Test with integration ID: ZlTZKFbKZ2aqhkI3reZh" -ForegroundColor Yellow
