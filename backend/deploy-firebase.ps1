# Seafrika Backend - Firebase Functions Deployment Script (PowerShell)
Write-Host "🚀 Deploying Seafrika Backend to Firebase Functions..." -ForegroundColor Green

# Check if we're in the backend directory
if (-not (Test-Path "package.json")) {
    Write-Host "❌ Error: Please run this script from the backend directory" -ForegroundColor Red
    exit 1
}

# Check if .env exists
if (-not (Test-Path ".env")) {
    Write-Host "⚠️  Warning: .env file not found. Make sure environment variables are configured in Firebase Functions" -ForegroundColor Yellow
}

# Build the project
Write-Host "🔨 Building the project..." -ForegroundColor Cyan
npm run build

# Check if build was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed! Please fix the errors and try again." -ForegroundColor Red
    exit 1
}

# Deploy to Firebase Functions
Write-Host "🚀 Deploying to Firebase Functions..." -ForegroundColor Cyan
firebase deploy --only functions

# Check deployment status
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Your API is now available at:" -ForegroundColor Cyan
    Write-Host "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Swagger documentation:" -ForegroundColor Cyan
    Write-Host "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 Instagram Webhook URL:" -ForegroundColor Cyan
    Write-Host "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/webhooks/instagram" -ForegroundColor White
} else {
    Write-Host "❌ Deployment failed! Check the error messages above." -ForegroundColor Red
    exit 1
}
