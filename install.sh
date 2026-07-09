#!/bin/bash
# ZipLoot Linux/macOS 1-Click Serverless Telegram Bot Setup
echo "=============================================="
echo "⚡ ZipLoot - Linux/macOS Auto-Installer ⚡"
echo "=============================================="

# 1. Check Node.js
if ! command -v node &> /dev/null; then
    echo "⚠️ Node.js not detected. Attempting to install Node.js..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y nodejs npm
    elif command -v brew &> /dev/null; then
        brew install node
    elif command -v yum &> /dev/null; then
        sudo yum install -y nodejs npm
    else
        echo "❌ Unsupported package manager. Please install Node.js manually."
        exit 1
    fi
    echo "✅ Node.js successfully installed!"
else
    echo "✅ Node.js is already installed."
fi

# Clone template to temp folder
TEMP_DIR="/tmp/telegram-bot-cloudflare"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "📥 Fetching template code from Ziploot repo..."
curl -sL "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/index.js" -o index.js
curl -sL "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/wrangler.json" -o wrangler.json
curl -sL "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/package.json" -o package.json

echo "📦 Installing dependencies locally..."
npm install

echo "🔑 Logging in to Cloudflare..."
npx wrangler login

echo ""
read -p "🔑 Enter your Telegram Bot API Token from @BotFather: " TELEGRAM_TOKEN
if [ -z "$TELEGRAM_TOKEN" ]; then
    echo "❌ Token cannot be empty."
    exit 1
fi

echo "🔒 Saving Telegram token securely in Cloudflare..."
echo "$TELEGRAM_TOKEN" | npx wrangler secret put TELEGRAM_TOKEN

echo "🚀 Deploying worker to Cloudflare..."
DEPLOY_OUTPUT=$(npx wrangler deploy)
echo "$DEPLOY_OUTPUT"

# Extract URL
WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -oE "https://[a-zA-Z0-9.-]+\.workers\.dev" | head -n 1)

if [ -z "$WORKER_URL" ]; then
    echo "❌ Deployment failed or URL could not be parsed."
    exit 1
fi

echo "✅ Worker live at: $WORKER_URL"

echo "🔗 Registering webhook with Telegram API..."
WEBHOOK_URL="https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook?url=${WORKER_URL}"
curl -s "$WEBHOOK_URL"
echo ""
echo "🎉 Congratulations! Your serverless bot is now 24/7 online!"
