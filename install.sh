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

read -p "[INPUT] Do you want to use the default Echo Bot script? (Y/N): " use_default
bot_code=""

if [ "$use_default" = "N" ] || [ "$use_default" = "n" ]; then
    echo ""
    echo "✍️ Paste your custom JavaScript bot code below."
    echo "When finished, type 'EOF' on a new line and press Enter:"
    while IFS= read -r line; do
        if [ "$line" = "EOF" ]; then
            break
        fi
        bot_code+="$line
"
    done
else
    # Default Template
    bot_code=$(cat << 'EOF'
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

        let replyText = `You said: "${text}". Welcome to Serverless Telegram!`;
        if (text.startsWith("/start")) {
          replyText = "Hello! I am running 24/7 serverless on Cloudflare Workers edge network.

Created using ZipLoot Template.";
        }

        const botToken = env.TELEGRAM_TOKEN;
        const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
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
EOF
)
fi

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
