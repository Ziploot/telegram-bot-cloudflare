# ZipLoot Windows 1-Click Serverless Telegram Bot Setup
try {
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
            Read-Host "Press Enter to exit..."
            Exit
        }
        Write-Host "✅ Node.js successfully installed!" -ForegroundColor Green
    } else {
        Write-Host "✅ Node.js is already installed." -ForegroundColor Green
    }

    # Create project folder locally in the user's CURRENT directory instead of Temp
    $projectFolder = Join-Path $pwd "telegram-bot-cloudflare"
    if (Test-Path $projectFolder) {
        Write-Host "⚠️ Folder 'telegram-bot-cloudflare' already exists in this directory." -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $projectFolder -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host "📥 Fetching template code from Ziploot repo..." -ForegroundColor Cyan
    Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/index.js?t=$(Get-Date -UFormat %s)" -OutFile "$projectFolder\index.js"
    Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/wrangler.json?t=$(Get-Date -UFormat %s)" -OutFile "$projectFolder\wrangler.json"
    Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/package.json?t=$(Get-Date -UFormat %s)" -OutFile "$projectFolder\package.json"

    Set-Location $projectFolder

    Write-Host "📦 Installing dependencies locally..." -ForegroundColor Cyan
    cmd.exe /c "npm install"

    Write-Host "🔑 Logging in to Cloudflare..." -ForegroundColor Cyan
    cmd.exe /c "npx wrangler login"

    $token = Read-Host "`n🔑 Enter your Telegram Bot API Token from @BotFather"
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "❌ Token cannot be empty." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        Exit
    }

    Write-Host "🔒 Saving Telegram token securely in Cloudflare..." -ForegroundColor Cyan
    cmd.exe /c "echo $token | npx wrangler secret put TELEGRAM_TOKEN"

    Write-Host "🚀 Deploying worker to Cloudflare..." -ForegroundColor Cyan
    $deployOutput = cmd.exe /c "npx wrangler deploy"
    Write-Host $deployOutput

    # Extract worker url
    $urlMatch = [regex]::Match($deployOutput, "https://[a-zA-Z0-9.-]+\.workers\.dev")
    if (-not $urlMatch.Success) {
        Write-Host "❌ Deployment succeeded but URL could not be parsed." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        Exit
    }
    $workerUrl = $urlMatch.Value
    Write-Host "✅ Worker live at: $workerUrl" -ForegroundColor Green

    Write-Host "🔗 Registering webhook with Telegram API..." -ForegroundColor Cyan
    $webhookUrl = "https://api.telegram.org/bot$($token.Trim())/setWebhook?url=$workerUrl"
    $response = Invoke-RestMethod -UserAgent $ua -Uri $webhookUrl
    Write-Host "Response from Telegram: $response"

    Write-Host "`n🎉 Congratulations! Your serverless bot is now 24/7 online!" -ForegroundColor Green
    Write-Host "`n📁 Project Folder: $projectFolder" -ForegroundColor Cyan
    Write-Host "✍️  To edit/paste your custom bot code, open '$projectFolder\index.js' in VS Code, modify the logic, and run 'npx wrangler deploy' in the terminal to update!" -ForegroundColor Yellow
    Read-Host "`nSetup completed. Press Enter to exit..."
} catch {
    Write-Host "❌ An unexpected error occurred: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
}
