import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type AiResult = {
  store_type: string;
  tone: string;
  reason: string;
  suggested_tags: string[];
  suggested_category?: string | null;
  confidence?: number | null;
  is_known_pattern: boolean;
};

Deno.serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const openAiApiKey = Deno.env.get("OPENAI_API_KEY");

    const authHeader = req.headers.get("Authorization");
    const jwt = authHeader?.replace("Bearer ", "").trim();
    let userId: string | null = null;

    if (!jwt) {
      console.log("[classify-unknown-expense] no JWT (dev mode)");
    } else {
      const authClient = createClient(supabaseUrl, anonKey, {
        global: {
          headers: {
            Authorization: `Bearer ${jwt}`,
          },
        },
      });

      const {
        data: { user },
        error: authError,
      } = await authClient.auth.getUser();

      if (authError || !user) {
        console.log("[classify-unknown-expense] invalid JWT (dev mode)");
      } else {
        userId = user.id;
      }
    }

    const body = await req.json();
    const storeName = String(body.store_name ?? "").trim();
    const normalizedStoreName = String(
      body.normalized_store_name ?? storeName.toLowerCase(),
    ).trim();
    const category = String(body.category ?? "").trim();
    const amount =
      typeof body.amount === "number"
        ? body.amount
        : Number(body.amount ?? 0) || 0;
    const spentAt = String(body.spent_at ?? "").trim();
    const spentHour =
      typeof body.spent_hour === "number"
        ? body.spent_hour
        : Number(body.spent_hour ?? -1);
    const spentWeekday =
      typeof body.spent_weekday === "number"
        ? body.spent_weekday
        : Number(body.spent_weekday ?? -1);

    if (!storeName) {
      return json({ error: "store_name is required" }, 400);
    }

    console.log("[classify-unknown-expense] request", {
      userId,
      storeName,
      normalizedStoreName,
      category,
      amount,
      spentAt,
      spentHour,
      spentWeekday,
      hasOpenAiKey: !!openAiApiKey,
    });

    const ruleFirst = buildRuleFirstResult({
      storeName,
      normalizedStoreName,
      category,
      amount,
      spentAt,
      spentHour,
      spentWeekday,
    });

    if (ruleFirst.is_known_pattern) {
      return json({ result: ruleFirst }, 200);
    }

    if (!openAiApiKey) {
      const fallback = buildFallbackResult(storeName, category);
      return json({ result: fallback }, 200);
    }

    const prompt = `
あなたは家計アプリの支出分類アシスタントです。
与えられた店名・カテゴリ・金額・時間帯から、その支出がどのタイプに近いかを慎重に推定してください。

返答ルール:
- JSONオブジェクトだけ返す
- キーは store_type, tone, reason, suggested_tags, suggested_category, confidence, is_known_pattern
- store_type は次の候補のいずれか:
  convenience, cafe, dining, supermarket, hobby, beauty, kids, family, transport, health, luxury, gambling, ceremony, online_shopping, unknown
- tone は次の候補のいずれか:
  neutral, light_warning, warning, gentle_ignore
- suggested_tags は文字列配列
- suggested_category は日本語カテゴリ名を1つ返す。候補例:
  コンビニ, カフェ, 外食, スーパー, 趣味, 美容, 子ども, 家族, 交通, 医療, 高級品, ギャンブル, 冠婚葬祭, ネットショッピング, その他
- confidence は 0 から 1 の数値
- is_known_pattern は true か false
- わからない場合は store_type を unknown、suggested_category を その他 にする
- 危険な断定をしすぎない
- 店名から推測しづらい場合でも、reason は短く根拠を書く
- 既知の有名店だと確信できる場合のみ is_known_pattern を true にする

推定のヒント:
- 深夜の online / payment / sq / visa などはネット購入や決済代行の可能性があります
- 朝はカフェ、夜や週末は外食や娯楽の文脈が強まることがあります
- amount が大きい場合は luxury や ceremony の可能性も検討してください

入力:
店名: ${storeName}
正規化店名: ${normalizedStoreName || "不明"}
カテゴリ: ${category || "未指定"}
金額: ${amount}
日時: ${spentAt || "不明"}
時間帯: ${spentHour >= 0 ? spentHour : "不明"}
曜日: ${spentWeekday >= 1 && spentWeekday <= 7 ? spentWeekday : "不明"}
`;

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openAiApiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        input: prompt,
        text: {
          format: {
            type: "json_schema",
            name: "unknown_expense_classification",
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                store_type: {
                  type: "string",
                  enum: [
                    "convenience",
                    "cafe",
                    "dining",
                    "supermarket",
                    "hobby",
                    "beauty",
                    "kids",
                    "family",
                    "transport",
                    "health",
                    "luxury",
                    "gambling",
                    "ceremony",
                    "online_shopping",
                    "unknown",
                  ],
                },
                tone: {
                  type: "string",
                  enum: [
                    "neutral",
                    "light_warning",
                    "warning",
                    "gentle_ignore",
                  ],
                },
                reason: { type: "string" },
                suggested_tags: {
                  type: "array",
                  items: { type: "string" },
                },
                suggested_category: {
                  type: ["string", "null"],
                },
                confidence: {
                  type: ["number", "null"],
                  minimum: 0,
                  maximum: 1,
                },
                is_known_pattern: { type: "boolean" },
              },
              required: [
                "store_type",
                "tone",
                "reason",
                "suggested_tags",
                "suggested_category",
                "confidence",
                "is_known_pattern",
              ],
            },
          },
        },
      }),
    });

    if (!response.ok) {
      console.error("[classify-unknown-expense] openai failed", {
        status: response.status,
      });
      const fallback = buildFallbackResult(storeName, category);
      return json({ result: fallback }, 200);
    }

    const jsonResponse = await response.json();
    const text =
      jsonResponse.output?.[0]?.content?.[0]?.text ??
      jsonResponse.output_text ??
      null;

    if (typeof text !== "string" || !text.trim()) {
      const fallback = buildFallbackResult(storeName, category);
      return json({ result: fallback }, 200);
    }

    try {
      const parsed = JSON.parse(text.trim());
      const result = normalizeAiResult(parsed);

      console.log("[classify-unknown-expense] success", {
        userId,
        storeName,
        result,
      });

      return json({ result }, 200);
    } catch (e) {
      console.error("[classify-unknown-expense] parse failed", {
        error: e instanceof Error ? e.message : String(e),
        text,
      });

      const fallback = buildFallbackResult(storeName, category);
      return json({ result: fallback }, 200);
    }
  } catch (error) {
    console.error("[classify-unknown-expense] fatal error", {
      message: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : null,
    });

    return json(
      {
        error: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});

function buildFallbackResult(storeName: string, category: string): AiResult {
  return buildRuleFirstResult({
    storeName,
    normalizedStoreName: storeName.toLowerCase(),
    category,
    amount: 0,
    spentAt: "",
    spentHour: -1,
    spentWeekday: -1,
  });
}

type RuleFirstInput = {
  storeName: string;
  normalizedStoreName: string;
  category: string;
  amount: number;
  spentAt: string;
  spentHour: number;
  spentWeekday: number;
};

function buildRuleFirstResult(input: RuleFirstInput): AiResult {
  const lowerStore = input.normalizedStoreName.toLowerCase();
  const lowerCategory = input.category.toLowerCase();
  const isWeekend = input.spentWeekday === 6 || input.spentWeekday === 7;
  const isLateNight = input.spentHour >= 22 || (input.spentHour >= 0 && input.spentHour <= 2);
  const isMorning = input.spentHour >= 5 && input.spentHour <= 10;

  if (
    lowerStore.includes("セブン") ||
    lowerStore.includes("ﾌｧﾐﾏ") ||
    lowerStore.includes("ファミマ") ||
    lowerStore.includes("ファミリーマート") ||
    lowerStore.includes("ローソン") ||
    lowerStore.includes("lawson") ||
    lowerStore.includes("7-eleven") ||
    lowerStore.includes("seven")
  ) {
    return {
      store_type: "convenience",
      tone: isLateNight ? "light_warning" : "neutral",
      reason: isLateNight
        ? "店名からコンビニ系で、深夜利用の可能性があります。"
        : "店名からコンビニ系の可能性が高いです。",
      suggested_tags: ["convenience"],
      suggested_category: "コンビニ",
      confidence: 0.96,
      is_known_pattern: true,
    };
  }

  if (
    lowerStore.includes("スタバ") ||
    lowerStore.includes("starbucks") ||
    lowerStore.includes("ドトール") ||
    lowerStore.includes("タリーズ") ||
    lowerCategory.includes("カフェ")
  ) {
    return {
      store_type: "cafe",
      tone: isMorning ? "neutral" : "light_warning",
      reason: isMorning
        ? "店名や時間帯から朝カフェ系の可能性があります。"
        : "店名やカテゴリからカフェ系と考えられます。",
      suggested_tags: ["cafe"],
      suggested_category: "カフェ",
      confidence: 0.93,
      is_known_pattern: true,
    };
  }

  if (
    lowerStore.includes("イオン") ||
    lowerStore.includes("西友") ||
    lowerStore.includes("イトーヨーカドー") ||
    lowerStore.includes("業務スーパー") ||
    lowerCategory.includes("スーパー")
  ) {
    return {
      store_type: "supermarket",
      tone: "neutral",
      reason: "店名やカテゴリからスーパー系の可能性が高いです。",
      suggested_tags: ["supermarket"],
      suggested_category: "スーパー",
      confidence: 0.92,
      is_known_pattern: true,
    };
  }

  if (
    lowerCategory.includes("外食") ||
    lowerCategory.includes("食費") ||
    lowerStore.includes("マクドナルド") ||
    lowerStore.includes("すき家") ||
    lowerStore.includes("吉野家") ||
    lowerStore.includes("松屋") ||
    lowerStore.includes("サイゼ") ||
    lowerStore.includes("ガスト") ||
    lowerStore.includes("スシロー") ||
    lowerStore.includes("くら寿司")
  ) {
    return {
      store_type: "dining",
      tone: isWeekend ? "neutral" : "light_warning",
      reason: isWeekend
        ? "店名や曜日から週末外食の可能性があります。"
        : "カテゴリ情報や店名から飲食系の可能性があります。",
      suggested_tags: ["dining"],
      suggested_category: "外食",
      confidence: 0.9,
      is_known_pattern: true,
    };
  }

  if (
    lowerStore.includes("amazon") ||
    lowerStore.includes("楽天") ||
    lowerStore.includes("rakuten") ||
    lowerStore.includes("yahoo") ||
    lowerStore.includes("zozo") ||
    lowerStore.includes("qoo10") ||
    lowerStore.includes("メルカリ") ||
    lowerStore.includes("mercari")
  ) {
    return {
      store_type: "online_shopping",
      tone: input.amount >= 5000 || isLateNight ? "light_warning" : "neutral",
      reason: isLateNight
        ? "店名からネットショッピングで、深夜購入の可能性があります。"
        : "店名からネットショッピングの可能性があります。",
      suggested_tags: ["online_shopping"],
      suggested_category: "ネットショッピング",
      confidence: 0.95,
      is_known_pattern: true,
    };
  }

  if (
    lowerStore.includes("イオンシネマ") ||
    lowerStore.includes("toho") ||
    lowerStore.includes("109シネマ")
  ) {
    return {
      store_type: "hobby",
      tone: "neutral",
      reason: "店名から映画館系の可能性があります。",
      suggested_tags: ["movie", "hobby"],
      suggested_category: "映画",
      confidence: 0.9,
      is_known_pattern: true,
    };
  }

  if (
    lowerStore.includes("ビッグエコー") ||
    lowerStore.includes("まねきねこ") ||
    lowerStore.includes("ジャンカラ") ||
    lowerStore.includes("カラオケ")
  ) {
    return {
      store_type: "hobby",
      tone: "neutral",
      reason: "店名からカラオケ系の可能性があります。",
      suggested_tags: ["karaoke", "hobby"],
      suggested_category: "カラオケ",
      confidence: 0.9,
      is_known_pattern: true,
    };
  }

  if (
    lowerStore.includes("ラウンドワン") ||
    lowerStore.includes("namco") ||
    lowerStore.includes("タイトー")
  ) {
    return {
      store_type: "hobby",
      tone: "light_warning",
      reason: "店名から遊び・アミューズメント系の可能性があります。",
      suggested_tags: ["arcade", "hobby"],
      suggested_category: "ゲームセンター",
      confidence: 0.88,
      is_known_pattern: true,
    };
  }

  if (
    lowerStore.includes("suica") ||
    lowerStore.includes("pasmo") ||
    lowerStore.includes("jr") ||
    lowerStore.includes("地下鉄") ||
    lowerStore.includes("バス") ||
    lowerStore.includes("タクシー") ||
    lowerStore.includes("eneos") ||
    lowerStore.includes("apollostation") ||
    lowerStore.includes("出光")
  ) {
    return {
      store_type: "transport",
      tone: "gentle_ignore",
      reason: "店名から交通・移動系の可能性があります。",
      suggested_tags: ["transport"],
      suggested_category: "交通",
      confidence: 0.9,
      is_known_pattern: true,
    };
  }

  return {
    store_type: "unknown",
    tone: "neutral",
    reason: "店名だけでは十分に判定できませんでした。",
    suggested_tags: [],
    suggested_category: "その他",
    confidence: 0.2,
    is_known_pattern: false,
  };
}

function normalizeAiResult(value: unknown): AiResult {
  const map = typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : {};

  const allowedStoreTypes = new Set([
    "convenience",
    "cafe",
    "dining",
    "supermarket",
    "hobby",
    "beauty",
    "kids",
    "family",
    "transport",
    "health",
    "luxury",
    "gambling",
    "ceremony",
    "online_shopping",
    "unknown",
  ]);

  const allowedTones = new Set([
    "neutral",
    "light_warning",
    "warning",
    "gentle_ignore",
  ]);

  const storeTypeRaw = String(map["store_type"] ?? "unknown").trim().toLowerCase();
  const toneRaw = String(map["tone"] ?? "neutral").trim().toLowerCase();

  const confidenceRaw = map["confidence"];
  const confidence = typeof confidenceRaw === "number"
    ? Math.max(0, Math.min(1, confidenceRaw))
    : Number.isFinite(Number(confidenceRaw))
    ? Math.max(0, Math.min(1, Number(confidenceRaw)))
    : null;

  const suggestedCategoryRaw = String(map["suggested_category"] ?? "").trim();

  return {
    store_type: allowedStoreTypes.has(storeTypeRaw) ? storeTypeRaw : "unknown",
    tone: allowedTones.has(toneRaw) ? toneRaw : "neutral",
    reason: String(map["reason"] ?? "").trim(),
    suggested_tags: Array.isArray(map["suggested_tags"])
      ? map["suggested_tags"]
          .map((e) => String(e).trim())
          .filter((e) => e.length > 0)
      : [],
    suggested_category: suggestedCategoryRaw || null,
    confidence,
    is_known_pattern: map["is_known_pattern"] === true,
  };
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}