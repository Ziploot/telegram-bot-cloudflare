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
          replyText = "Hello! I am running 24/7 serverless on Cloudflare Workers edge network.\n\nCreated using ZipLoot Template.";
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
