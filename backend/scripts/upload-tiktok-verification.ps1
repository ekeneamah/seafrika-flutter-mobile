# TikTok Verification File Upload Script
# Usage: .\upload-tiktok-verification.ps1 -FilePath "C:\path\to\file.txt" -ServerUrl "http://localhost:3000"

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerUrl = "http://localhost:3000"
)

# Check if file exists
if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$FileName = Split-Path $FilePath -Leaf
$UploadUrl = "$ServerUrl/api/v1/webhooks/tiktok/upload-verification"

Write-Host "Uploading TikTok verification file..." -ForegroundColor Yellow
Write-Host "File: $FileName" -ForegroundColor Cyan
Write-Host "URL: $UploadUrl" -ForegroundColor Cyan

try {
    # Method 1: Using Invoke-RestMethod (PowerShell 3.0+)
    $response = Invoke-RestMethod -Uri $UploadUrl -Method Post -InFile $FilePath -ContentType "multipart/form-data"
    
    Write-Host "✅ Success!" -ForegroundColor Green
    Write-Host "Filename: $($response.filename)" -ForegroundColor White
    Write-Host "Size: $($response.size) bytes" -ForegroundColor White
    Write-Host "Upload Time: $($response.uploadTime)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Upload failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    # Try alternative method with curl if available
    if (Get-Command curl -ErrorAction SilentlyContinue) {
        Write-Host "Trying with curl..." -ForegroundColor Yellow
        
        $curlResult = curl -X POST $UploadUrl -F "file=@$FilePath" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Success with curl!" -ForegroundColor Green
            Write-Host $curlResult -ForegroundColor White
        } else {
            Write-Host "❌ Curl also failed!" -ForegroundColor Red
            Write-Host $curlResult -ForegroundColor Red
        }
    }
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Go to TikTok Developer Console" -ForegroundColor White
Write-Host "2. Click 'Verify' on your webhook configuration" -ForegroundColor White
Write-Host "3. TikTok will check the uploaded file" -ForegroundColor White