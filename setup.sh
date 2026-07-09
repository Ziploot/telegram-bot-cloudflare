#!/bin/bash
# -------------------------------------------------------------
# ZipLoot - 1-Click Serverless Telegram Bot Installer
# -------------------------------------------------------------
echo "=============================================="
echo "⚡ ZipLoot - Serverless Telegram Bot Setup ⚡"
echo "=============================================="

# Check node
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed. Please install it first."
    exit 1
fi

echo "📦 Installing Wrangler CLI and dependencies..."
npm install

# Login to Cloudflare if not logged in
echo "🔑 Logging in to Cloudflare..."
npx wrangler login

# Prompt for Telegram token
echo ""
read -p "🔑 Enter your Telegram Bot API Token from @BotFather: " TELEGRAM_TOKEN
if [ -z "$TELEGRAM_TOKEN" ]; then
    echo "❌ Error: Token cannot be empty."
    exit 1
fi

# Set the token secret in Cloudflare
echo "🔒 Saving Telegram token securely in Cloudflare..."
echo "$TELEGRAM_TOKEN" | npx wrangler secret put TELEGRAM_TOKEN

# Deploying
echo "🚀 Deploying worker to Cloudflare..."
DEPLOY_OUTPUT=$(npx wrangler deploy)
echo "$DEPLOY_OUTPUT"

# Extract URL using grep/sed
WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -oE "https://[a-zA-Z0-9.-]+\.workers\.dev" | head -n 1)

if [ -z "$WORKER_URL" ]; then
    echo "❌ Deployment failed or URL could not be parsed."
    exit 1
fi

echo "✅ Worker live at: $WORKER_URL"

# Register Webhook with Telegram
echo "🔗 Registering webhook with Telegram API..."
WEBHOOK_URL="https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook?url=${WORKER_URL}"
curl -s "$WEBHOOK_URL"
echo ""
echo "🎉 Congratulations! Your bot is 24/7 online!"
