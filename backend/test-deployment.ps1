# Test Your Deployed Firebase Functions

Write-Host "🧪 Testing Seafrika Backend Deployment" -ForegroundColor Green
Write-Host ""

# Base URL for your deployed function
$baseUrl = "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi"

Write-Host "🌐 Testing API endpoints..." -ForegroundColor Cyan

# Test 1: Health check
Write-Host "1. Testing API root..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api" -Method GET -TimeoutSec 30
    Write-Host "✅ API root accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ API root failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Swagger documentation
Write-Host "2. Testing Swagger docs..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api" -Method GET -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Swagger documentation accessible" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Swagger docs failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Instagram webhook endpoint
Write-Host "3. Testing Instagram webhook..." -ForegroundColor Yellow
try {
    $webhookUrl = "$baseUrl/api/webhooks/instagram"
    $testData = @{
        "hub.mode" = "subscribe"
        "hub.verify_token" = "test-token"
        "hub.challenge" = "test-challenge"
    }
    
    # This will likely fail verification but should return a response
    $response = Invoke-WebRequest -Uri $webhookUrl -Method GET -Body $testData -TimeoutSec 30
    Write-Host "✅ Instagram webhook endpoint accessible" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "⚠️  Instagram webhook accessible but verification failed (expected)" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Instagram webhook failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 4: Products API
Write-Host "4. Testing Products API..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products" -Method GET -TimeoutSec 30
    Write-Host "✅ Products API accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ Products API failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "📋 Your API URLs:" -ForegroundColor Cyan
Write-Host "• Main API: $baseUrl/api" -ForegroundColor White
Write-Host "• Instagram Webhook: $baseUrl/api/webhooks/instagram" -ForegroundColor White
Write-Host "• Products: $baseUrl/api/products" -ForegroundColor White
Write-Host "• Firebase Auth: $baseUrl/api/firebase/auth" -ForegroundColor White
Write-Host "• Firebase Storage: $baseUrl/api/firebase/storage" -ForegroundColor White
Write-Host "• Firebase Messaging: $baseUrl/api/firebase/messaging" -ForegroundColor White

Write-Host ""
Write-Host "🔗 For Facebook Instagram App, use:" -ForegroundColor Cyan
Write-Host "$baseUrl/api/webhooks/instagram" -ForegroundColor Green
