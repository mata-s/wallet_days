import OpenAI from "https://deno.land/x/openai@v4.24.0/mod.ts";

const openai = new OpenAI({
  apiKey: Deno.env.get("OPENAI_API_KEY"),
});

Deno.serve(async (req) => {
  try {
    const { image } = await req.json();

    if (!image) {
      return new Response(
        JSON.stringify({ error: "No image provided" }),
        { status: 400 }
      );
    }

    const response = await openai.chat.completions.create({
      model: "gpt-4.1-mini",
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: `
レシート画像から以下を抽出してJSONで返してください。
必ずJSONのみ返してください。

{
  "store": "店名",
  "amount": 1234
}

・amountは合計金額
・数字のみ（円やカンマなし）
・不明なら null
              `,
            },
            {
              type: "image_url",
              image_url: {
                url: `data:image/jpeg;base64,${image}`,
              },
            },
          ],
        },
      ],
      temperature: 0,
      response_format: { type: "json_object" },
    });

    const text = response.choices[0]?.message?.content ?? "";

    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch (_) {
      parsed = {
        store: null,
        amount: null,
      };
    }

    return new Response(JSON.stringify(parsed), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500 }
    );
  }
});