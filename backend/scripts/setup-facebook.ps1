# Facebook Instagram Webhook Setup Script (PowerShell)
# This script helps you set up Facebook Developer configuration for Instagram webhooks

Write-Host "🚀 Seafrika Instagram Webhook Setup" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""

# Check if required environment variables are set
Write-Host "📋 Checking environment configuration..." -ForegroundColor Blue

$requiredVars = @(
    "FACEBOOK_APP_ID",
    "FACEBOOK_APP_SECRET", 
    "INSTAGRAM_APP_ID",
    "INSTAGRAM_APP_SECRET",
    "INSTAGRAM_VERIFY_TOKEN"
)

$missingVars = @()

foreach ($var in $requiredVars) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if ([string]::IsNullOrEmpty($value)) {
        $missingVars += $var
    }
}

if ($missingVars.Count -eq 0) {
    Write-Host "✅ All required environment variables are set" -ForegroundColor Green
} else {
    Write-Host "❌ Missing required environment variables:" -ForegroundColor Red
    foreach ($var in $missingVars) {
        Write-Host "   - $var" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Please add these to your .env file:" -ForegroundColor Yellow
    Write-Host "FACEBOOK_APP_ID=your-facebook-app-id"
    Write-Host "FACEBOOK_APP_SECRET=your-facebook-app-secret"
    Write-Host "INSTAGRAM_APP_ID=your-instagram-app-id"
    Write-Host "INSTAGRAM_APP_SECRET=your-instagram-app-secret"
    Write-Host "INSTAGRAM_VERIFY_TOKEN=your-custom-verify-token"
    Write-Host ""
    Write-Host "📖 See docs/FACEBOOK_DEVELOPER_SETUP.md for detailed instructions" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "🔗 Useful URLs for setup:" -ForegroundColor Blue
Write-Host "========================="
Write-Host "Facebook Developer Console: https://developers.facebook.com/"
Write-Host "Graph API Explorer: https://developers.facebook.com/tools/explorer/"
Write-Host "Instagram Basic Display Docs: https://developers.facebook.com/docs/instagram-basic-display-api/"
Write-Host ""

# Check if server is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/api/webhooks/instagram/test" -UseBasicParsing -TimeoutSec 5
    Write-Host "✅ Webhook server is running" -ForegroundColor Green
    
    # Test webhook endpoints
    Write-Host ""
    Write-Host "🧪 Testing webhook endpoints..." -ForegroundColor Blue
    
    # Test configuration validation
    Write-Host "Testing configuration validation..."
    try {
        $configResponse = Invoke-WebRequest -Uri "http://localhost:3000/api/config/facebook/validate" -UseBasicParsing
        Write-Host "✅ Configuration endpoint accessible" -ForegroundColor Green
    } catch {
        Write-Host "❌ Configuration endpoint not available" -ForegroundColor Red
    }
    
    # Test webhook verification
    Write-Host ""
    Write-Host "Testing webhook verification..."
    $testToken = "test123"
    $verifyToken = [Environment]::GetEnvironmentVariable("INSTAGRAM_VERIFY_TOKEN")
    
    if (-not [string]::IsNullOrEmpty($verifyToken)) {
        try {
            $verifyUrl = "http://localhost:3000/api/webhooks/instagram?hub.mode=subscribe&hub.challenge=${testToken}&hub.verify_token=${verifyToken}"
            $verifyResponse = Invoke-WebRequest -Uri $verifyUrl -UseBasicParsing
            
            if ($verifyResponse.Content -eq $testToken) {
                Write-Host "✅ Webhook verification working correctly" -ForegroundColor Green
            } else {
                Write-Host "❌ Webhook verification failed" -ForegroundColor Red
                Write-Host "Expected: $testToken"
                Write-Host "Got: $($verifyResponse.Content)"
            }
        } catch {
            Write-Host "❌ Webhook verification test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ INSTAGRAM_VERIFY_TOKEN not set, skipping verification test" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Webhook server is not running" -ForegroundColor Red
    Write-Host "Please start the server with: npm run start:dev" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Blue
Write-Host "=============="
Write-Host "1. Create Facebook App at: https://developers.facebook.com/"
Write-Host "2. Add Instagram Basic Display product"
Write-Host "3. Configure webhook URL: https://your-domain.com/api/webhooks/instagram"
Write-Host "4. Set verify token: $([Environment]::GetEnvironmentVariable('INSTAGRAM_VERIFY_TOKEN'))"
Write-Host "5. Test with: curl `"http://localhost:3000/api/config/facebook/setup-guide`""
Write-Host ""
Write-Host "📖 Full documentation: docs/FACEBOOK_DEVELOPER_SETUP.md" -ForegroundColor Cyan
Write-Host "🔧 API docs: http://localhost:3000/api/docs" -ForegroundColor Cyan

# Open useful URLs in browser
$openBrowser = Read-Host "Would you like to open helpful URLs in your browser? (y/n)"
if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
    Start-Process "https://developers.facebook.com/"
    Start-Process "http://localhost:3000/api/docs"
    Start-Process "http://localhost:3000/api/config/facebook/setup-guide"
}
