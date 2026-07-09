#!/usr/bin/env node
const { execSync, spawn } = require('child_process');
const readline = require('readline');
const https = require('https');

console.log("==============================================");
echo = console.log;
echo("⚡ ZipLoot - Serverless Telegram Bot Setup ⚡");
echo("==============================================");

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function runCmd(cmd, stdio = 'inherit') {
    try {
        execSync(cmd, { stdio });
    } catch (e) {
        console.error(`❌ Failed executing: ${cmd}`);
        process.exit(1);
    }
}

async function startSetup() {
    echo("📦 Installing dependencies locally...");
    runCmd("npm install");

    echo("🔑 Logging in to Cloudflare...");
    runCmd("npx wrangler login");

    rl.question("\n🔑 Enter your Telegram Bot API Token from @BotFather: ", (token) => {
        if (!token.trim()) {
            echo("❌ Token cannot be empty.");
            process.exit(1);
        }

        echo("🔒 Saving Telegram token securely in Cloudflare...");
        
        // Pass token to stdin of wrangler secret put to ensure Windows/Linux compatibility
        const wranglerSecret = spawn('npx', ['wrangler', 'secret', 'put', 'TELEGRAM_TOKEN'], {
            stdio: ['pipe', 'inherit', 'inherit'],
            shell: true
        });
        wranglerSecret.stdin.write(token.trim() + "\n");
        wranglerSecret.stdin.end();

        wranglerSecret.on('close', (code) => {
            if (code !== 0) {
                echo("❌ Failed to save Telegram token secret.");
                process.exit(1);
            }

            echo("🚀 Deploying worker to Cloudflare...");
            let deployOutput = "";
            try {
                deployOutput = execSync("npx wrangler deploy", { encoding: 'utf-8', shell: true });
                console.log(deployOutput);
            } catch (err) {
                console.error("❌ Wrangler deployment failed.");
                process.exit(1);
            }

            // Parse URL
            const urlMatch = deployOutput.match(/https:\/\/[a-zA-Z0-9.-]+\.workers\.dev/);
            if (!urlMatch) {
                echo("❌ Deployment succeeded but URL could not be parsed.");
                process.exit(1);
            }
            const workerUrl = urlMatch[0];
            echo(`✅ Worker live at: ${workerUrl}`);

            echo("🔗 Registering webhook with Telegram API...");
            const webhookUrl = `https://api.telegram.org/bot${token.trim()}/setWebhook?url=${workerUrl}`;
            
            https.get(webhookUrl, (res) => {
                let data = '';
                res.on('data', (chunk) => { data += chunk; });
                res.on('end', () => {
                    echo(`Response from Telegram: ${data}`);
                    echo("\n🎉 Congratulations! Your serverless bot is now 24/7 online!");
                    process.exit(0);
                });
            }).on("error", (err) => {
                echo(`❌ Failed to register webhook: ${err.message}`);
                process.exit(1);
            });
        });
    });
}

startSetup();
