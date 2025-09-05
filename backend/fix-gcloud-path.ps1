# Add Google Cloud SDK to PATH for current session
# This script helps when gcloud is installed but not in PATH

Write-Host "🔍 Searching for Google Cloud SDK installation..." -ForegroundColor Cyan

# Common installation paths
$possiblePaths = @(
    "C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin",
    "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin",
    "$env:USERPROFILE\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin",
    "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin",
    "C:\google-cloud-sdk\bin"
)

$foundPath = $null

foreach ($path in $possiblePaths) {
    if (Test-Path "$path\gcloud.cmd") {
        $foundPath = $path
        break
    }
}

if ($foundPath) {
    Write-Host "✅ Found Google Cloud SDK at: $foundPath" -ForegroundColor Green
    
    # Add to current session PATH
    $env:PATH = "$foundPath;$env:PATH"
    
    Write-Host "✅ Added to PATH for current session" -ForegroundColor Green
    Write-Host "🔧 Testing gcloud command..." -ForegroundColor Cyan
    
    try {
        & "$foundPath\gcloud.cmd" --version
        Write-Host "✅ gcloud is now working!" -ForegroundColor Green
        
        Write-Host "`n🚀 You can now run:" -ForegroundColor Cyan
        Write-Host "npm run deploy:gcloud" -ForegroundColor White
    }
    catch {
        Write-Host "❌ gcloud command failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Google Cloud SDK not found in common locations" -ForegroundColor Red
    Write-Host "💡 Try reinstalling with: winget install Google.CloudSDK --include-unknown" -ForegroundColor Yellow
    Write-Host "💡 Or use Firebase CLI: npm run deploy" -ForegroundColor Yellow
}

Write-Host "`n📋 Available deployment options:" -ForegroundColor Cyan
Write-Host "1. npm run deploy       - Use Firebase CLI (recommended)" -ForegroundColor White
Write-Host "2. npm run deploy:gcloud - Use gcloud CLI (after PATH fix)" -ForegroundColor White
