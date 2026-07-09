# ⚡ Serverless Telegram Bot on Cloudflare Workers

A ready-made, serverless Telegram bot template that runs 24/7 on Cloudflare Workers for $0.

## 🚀 1-Click Automated Setup

Run the following command in your terminal to automatically install, deploy, and register your bot:

```bash
curl -sL https://raw.githubusercontent.com/Ziploot/telegram-bot-cloudflare/main/setup.sh | bash
```

## 🛠️ Requirements
- Node.js installed
- Cloudflare Account
- Telegram Bot API Token from [@BotFather](https://t.me/BotFather)

## 📁 Repository Structure
- `index.js`: The worker script containing bot logic.
- `wrangler.json`: Cloudflare configuration file.
- `setup.sh`: Interactive deployment script.
