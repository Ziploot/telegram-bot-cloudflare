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

    # Create project folder locally
    $projectFolder = Join-Path $pwd "telegram-bot-cloudflare"
    if (Test-Path $projectFolder) {
        Write-Host "⚠️ Folder 'telegram-bot-cloudflare' already exists in this directory." -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $projectFolder -ErrorAction SilentlyContinue | Out-Null
    }

    Set-Location $projectFolder

    # 2. Get Bot Code Option
    $useDefault = Read-Host "`n❓ Do you want to use the default Echo Bot script? (Y/N)"
    $botCode = ""

    if ($useDefault.Trim().ToUpper() -eq "N") {
        Write-Host "`n✍️ Paste your custom JavaScript bot code below." -ForegroundColor Cyan
        Write-Host "When finished, type 'EOF' on a new line and press Enter:" -ForegroundColor Yellow
        $codeLines = @()
        do {
            $line = Read-Host
            if ($line.Trim() -eq "EOF") { break }
            $codeLines += $line
        } while ($true)
        $botCode = $codeLines -join "`r`n"
    } else {
        # Default Template
        $botCode = @"
export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("Send POST requests only.", { status: 405 });
    }
    try {
      const payload = await request.json();
      if (payload.message) {
        const chatId = payload.message.chat.id;
        const text = payload.message.text || "";

        let replyText = \`You said: "\${text}". Welcome to Serverless Telegram!\`;
        if (text.startsWith("/start")) {
          replyText = "Hello! I am running 24/7 serverless on Cloudflare Workers edge network.\n\nCreated using ZipLoot Template.";
        }

        const botToken = env.TELEGRAM_TOKEN;
        const url = \`https://api.telegram.org/bot\${botToken}/sendMessage\`;
        await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            chat_id: chatId,
            text: replyText,
          }),
        });
      }
      return new Response("OK", { status: 200 });
    } catch (err) {
      return new Response(err.toString(), { status: 500 });
    }
  }
};
"@
    }

    # Write bot code to local file
    $botCode | Out-File -FilePath "$projectFolder\index.js" -Encoding utf8 -Force

    Write-Host "📥 Fetching package metadata from Ziploot..." -ForegroundColor Cyan
    Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/wrangler.json?t=$(Get-Date -UFormat %s)" -OutFile "$projectFolder\wrangler.json"
    Invoke-WebRequest -UserAgent $ua -Uri "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/package.json?t=$(Get-Date -UFormat %s)" -OutFile "$projectFolder\package.json"

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
    Read-Host "`nSetup completed. Press Enter to exit..."
} catch {
    Write-Host "❌ An unexpected error occurred: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
}
