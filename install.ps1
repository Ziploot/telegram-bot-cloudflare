# ZipLoot Windows 1-Click Serverless Telegram Bot Setup
Write-Host "==============================================" -ForegroundColor Green
Write-Host "⚡ ZipLoot - Windows Auto-Installer ⚡" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

# 1. Check Node.js
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeInstalled) {
    Write-Host "⚠️ Node.js not detected. Installing Node.js silently via winget..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS --silent --accept-package-agreements --accept-source-agreements
    
    # Update PATH env in current session so npx works immediately
    $env:Path += ";$env:ProgramFiles\nodejs"
    
    # Verify installation
    $nodeVerify = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeVerify) {
        Write-Host "❌ Silent Node.js installation failed. Please install Node.js manually." -ForegroundColor Red
        Exit
    }
    Write-Host "✅ Node.js successfully installed!" -ForegroundColor Green
} else {
    Write-Host "✅ Node.js is already installed." -ForegroundColor Green
}

# Clone the template locally into temp directory to execute
$tempFolder = "$env:TEMP\telegram-bot-cloudflare"
if (Test-Path $tempFolder) { Remove-Item $tempFolder -Recurse -Force }
New-Item -ItemType Directory -Path $tempFolder | Out-Null

Write-Host "📥 Fetching template code from Ziploot repo..." -ForegroundColor Cyan
Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/index.js" -OutFile "$tempFolder\index.js"
Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/wrangler.json" -OutFile "$tempFolder\wrangler.json"
Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/package.json" -OutFile "$tempFolder\package.json"

Set-Location $tempFolder

Write-Host "📦 Installing dependencies locally..." -ForegroundColor Cyan
# Run via cmd.exe to bypass PowerShell Execution Policy restriction on npm.ps1
cmd.exe /c "npm install"

Write-Host "🔑 Logging in to Cloudflare..." -ForegroundColor Cyan
# Run via cmd.exe to bypass PowerShell Execution Policy restriction on npx.ps1
cmd.exe /c "npx wrangler login"

$token = Read-Host "`n🔑 Enter your Telegram Bot API Token from @BotFather"
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "❌ Token cannot be empty." -ForegroundColor Red
    Exit
}

Write-Host "🔒 Saving Telegram token securely in Cloudflare..." -ForegroundColor Cyan
$token | cmd.exe /c "npx wrangler secret put TELEGRAM_TOKEN"

Write-Host "🚀 Deploying worker to Cloudflare..." -ForegroundColor Cyan
$deployOutput = cmd.exe /c "npx wrangler deploy"
Write-Host $deployOutput

# Extract worker url
$urlMatch = [regex]::Match($deployOutput, "https://[a-zA-Z0-9.-]+\.workers\.dev")
if (-not $urlMatch.Success) {
    Write-Host "❌ Deployment succeeded but URL could not be parsed." -ForegroundColor Red
    Exit
}
$workerUrl = $urlMatch.Value
Write-Host "✅ Worker live at: $workerUrl" -ForegroundColor Green

Write-Host "🔗 Registering webhook with Telegram API..." -ForegroundColor Cyan
$webhookUrl = "https://api.telegram.org/bot$($token.Trim())/setWebhook?url=$workerUrl"
$response = Invoke-RestMethod -UserAgent $ua -Uri $webhookUrl
Write-Host "Response from Telegram: $response"

Write-Host "`n🎉 Congratulations! Your serverless bot is now 24/7 online!" -ForegroundColor Green
