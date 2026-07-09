# ZipLoot Windows 1-Click Serverless Telegram Bot Setup
try {
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "[ZipLoot] Windows Auto-Installer" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green

    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

    # 1. Check Node.js
    $nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeInstalled) {
        Write-Host "[WARN] Node.js not detected. Installing Node.js silently via winget..." -ForegroundColor Yellow
        winget install OpenJS.NodeJS --silent --accept-package-agreements --accept-source-agreements
        
        # Update PATH env in current session so npx works immediately
        $env:Path += ";$env:ProgramFiles\\nodejs"
        
        # Verify installation
        $nodeVerify = Get-Command node -ErrorAction SilentlyContinue
        if (-not $nodeVerify) {
            Write-Host "[ERROR] Silent Node.js installation failed. Please install Node.js manually." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            Exit
        }
        Write-Host "[SUCCESS] Node.js successfully installed!" -ForegroundColor Green
    } else {
        Write-Host "[SUCCESS] Node.js is already installed." -ForegroundColor Green
    }

    # Create project folder locally in the user's CURRENT directory
    $projectFolder = Join-Path $pwd "telegram-bot-cloudflare-project"
    if (Test-Path $projectFolder) {
        Write-Host "[WARN] Folder 'telegram-bot-cloudflare-project' already exists." -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $projectFolder -ErrorAction SilentlyContinue | Out-Null
    }

    # 2. Get Bot Code Option
    $useDefault = Read-Host "`n[INPUT] Do you want to use the default Echo Bot script? (Y/N)"
    
    if ($useDefault.Trim().ToUpper() -eq "N") {
        Write-Host "`n[INPUT] Paste your custom JavaScript bot code below." -ForegroundColor Cyan
        Write-Host "When finished, type 'EOF' on a new line and press Enter:" -ForegroundColor Yellow
        $codeLines = @()
        do {
            $line = Read-Host
            if ($line.Trim() -eq "EOF") { break }
            $codeLines += $line
        } while ($true)
        $botCode = $codeLines -join "`r`n"
        $botCode | Out-File -FilePath "$projectFolder\\index.js" -Encoding utf8 -Force
    } else {
        # Copy the default template index.js already packaged in the ZIP
        Copy-Item -Path "$scriptDir\\index.js" -Destination "$projectFolder\\index.js" -Force
    }

    # Copy package.json and wrangler.json already packaged in the ZIP
    Copy-Item -Path "$scriptDir\\wrangler.json" -Destination "$projectFolder\\wrangler.json" -Force
    Copy-Item -Path "$scriptDir\\package.json" -Destination "$projectFolder\\package.json" -Force

    Set-Location $projectFolder

    Write-Host "[INSTALL] Installing dependencies locally..." -ForegroundColor Cyan
    cmd.exe /c "npm install"

    Write-Host "[LOGIN] Logging in to Cloudflare..." -ForegroundColor Cyan
    cmd.exe /c "npx wrangler login"

    $token = Read-Host "`n[INPUT] Enter your Telegram Bot API Token from @BotFather"
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "[ERROR] Token cannot be empty." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        Exit
    }

    Write-Host "[SECURE] Saving Telegram token securely in Cloudflare..." -ForegroundColor Cyan
    cmd.exe /c "echo $token | npx wrangler secret put TELEGRAM_TOKEN"

    Write-Host "[DEPLOY] Deploying worker to Cloudflare..." -ForegroundColor Cyan
    $logFile = "$projectFolder\\deploy.log"
    cmd.exe /c "npx wrangler deploy" | Tee-Object -FilePath $logFile

    $deployOutput = Get-Content $logFile -Raw

    # Extract worker url
    $urlMatch = [regex]::Match($deployOutput, "https://[a-zA-Z0-9.-]+\\.workers\\.dev")
    if (-not $urlMatch.Success) {
        Write-Host "[ERROR] Deployment succeeded but URL could not be parsed from logs." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        Exit
    }
    $workerUrl = $urlMatch.Value
    Write-Host "[SUCCESS] Worker live at: $workerUrl" -ForegroundColor Green

    Write-Host "[LINK] Registering webhook with Telegram API..." -ForegroundColor Cyan
    $webhookUrl = "https://api.telegram.org/bot$($token.Trim())/setWebhook?url=$workerUrl"
    $response = Invoke-RestMethod -UserAgent $ua -Uri $webhookUrl
    Write-Host "Response from Telegram: $response"

    Write-Host "`n[SUCCESS] Congratulations! Your serverless bot is now 24/7 online!" -ForegroundColor Green
    Read-Host "`nSetup completed. Press Enter to exit..."
} catch {
    Write-Host "[ERROR] An unexpected error occurred: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
}
