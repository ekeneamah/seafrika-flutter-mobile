# TikTok Verification File Setup Script
# This script helps you set the environment variable for TikTok verification

param(
    [Parameter(Mandatory=$false)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$Text,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseBase64
)

Write-Host "🎵 TikTok Verification File Setup" 
Write-Host "=====================================" 

if ($FilePath -and (Test-Path $FilePath)) {
    # Read from file
    $content = Get-Content $FilePath -Raw
    Write-Host "✅ File read successfully: $FilePath" 
    Write-Host "📝 Content length: $($content.Length) characters" 
} elseif ($Text) {
    # Use provided text
    $content = $Text
    Write-Host "✅ Using provided text" 
} else {
    Write-Host "❌ Please provide either -FilePath or -Text"
    Write-Host ""
    Write-Host "Examples:" 
    Write-Host "  .\setup-tiktok-verification.ps1 -FilePath 'C:\path\to\tiktok3CNWiPpcjbDVMlehbFB9ufQTRggYf0dF.txt'" 
    Write-Host "  .\setup-tiktok-verification.ps1 -Text 'your verification content here'" 
    Write-Host "  .\setup-tiktok-verification.ps1 -FilePath 'file.txt' -UseBase64" 
    exit 1
}
