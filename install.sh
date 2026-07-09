#!/bin/bash
# ZipLoot Linux/macOS 1-Click Serverless Telegram Bot Setup
echo "=============================================="
echo "⚡ ZipLoot - Linux/macOS Auto-Installer ⚡"
echo "=============================================="

# --- COLLECT ALL INPUTS UPFRONT ---

TELEGRAM_TOKEN=""
while [ -z "$TELEGRAM_TOKEN" ]; do
    read -p "[INPUT] Enter your Telegram Bot API Token from @BotFather: " TELEGRAM_TOKEN
done

SUBDOMAIN=""
while [ -z "$SUBDOMAIN" ]; do
    read -p "[INPUT] Enter your Cloudflare workers.dev subdomain (e.g. 'ziploot'): " SUBDOMAIN_INPUT
    SUBDOMAIN=$(echo "$SUBDOMAIN_INPUT" | sed 's/\.workers\.dev//g' | xargs)
done

echo ""
echo "[INPUT] Paste your custom JavaScript bot code below."
echo "When finished, type 'EOF' on a new line and press Enter:"
bot_code=""
while IFS= read -r line; do
    if [ "$line" = "EOF" ]; then
        break
    fi
    bot_code+="$line
"
done

echo -e "
[INFO] All inputs collected! Starting automatic setup, please wait...
"

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

# Create project folder locally
PROJECT_DIR="$(pwd)/telegram-bot-cloudflare-project"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo -e "$bot_code" > index.js

echo "📥 Fetching package metadata from Ziploot..."
curl -sL "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/wrangler.json" -o wrangler.json
curl -sL "https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/package.json" -o package.json

echo "📦 Installing dependencies locally..."
npm install

echo "🔑 Logging in to Cloudflare..."
npx wrangler login

echo "🔒 Saving Telegram token securely in Cloudflare..."
echo "$TELEGRAM_TOKEN" | npx wrangler secret put TELEGRAM_TOKEN

echo "🚀 Deploying worker to Cloudflare..."
npx wrangler deploy

WORKER_URL="https://telegram-bot-cloudflare.${SUBDOMAIN}.workers.dev"
echo "✅ Worker live at: $WORKER_URL"

echo "🔗 Registering webhook with Telegram API..."
WEBHOOK_URL="https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook?url=${WORKER_URL}"
curl -s "$WEBHOOK_URL"
echo ""
echo "🎉 Congratulations! Your serverless bot is now 24/7 online!"
