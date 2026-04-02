import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ExpenseRow = {
  amount: number;
  category: string | null;
  store_name: string | null;
  created_at: string;
};

type BudgetSettingRow = {
  total_budget: number;
  cycle_start_day: number;
  categories_json: Array<{
    name?: string;
    badge?: string;
    budget?: number;
  }> | null;
};

type BudgetHistoryRow = {
  total_budget: number;
  total_expense: number;
  is_achieved: boolean;
  streak: number;
  start_date: string;
  end_date: string;
};


type BadgeResult = {
  badge_key: string;
  title: string;
  description: string;
  reason: string;
  rarity: "common" | "rare" | "epic";
};


type RankResult = {
  rank_key: string;
  rank_label: string;
  total_count: number;
  achieved_count: number;
  success_rate: number;
  current_streak: number;
  best_streak: number;
};

type TitleResult = {
  title: string;
  reason: string;
  rarity: "common" | "rare" | "epic";
};

Deno.serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const openAiApiKey = Deno.env.get("OPENAI_API_KEY");

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const authHeader = req.headers.get("Authorization");
    const jwt = authHeader?.replace("Bearer ", "").trim();

    if (!jwt) {
      return json({ error: "Unauthorized" }, 401);
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
    });

    const body = await req.json();
    const rawPeriodStart = String(body.period_start ?? body.cycleStart ?? "").trim();
    const rawPeriodEnd = String(body.period_end ?? body.cycleEnd ?? "").trim();
    const periodStart = toDateKey(rawPeriodStart);
    const periodEnd = toDateKey(rawPeriodEnd);
    const useAi = Boolean(body.use_ai ?? true);
    console.log("[generate-monthly-report] request", {
      periodStart,
      periodEnd,
      useAi,
    });

    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser();

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const userId = user.id;
    console.log("[generate-monthly-report] user", {
      userId,
      email: user.email ?? null,
    });

    if (!periodStart || !periodEnd) {
      return json(
        { error: "period_start and period_end are required." },
        400,
      );
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError) throw profileError;
    if (!profile) {
      return json({ error: "Profile not found." }, 404);
    }

    console.log("[generate-monthly-report] profile", {
      userId,
      isPremiumCached: profile.is_premium_cached === true,
    });

    if (profile.is_premium_cached !== true) {
      return json({ error: "Premium required." }, 403);
    }

    const { data: existingReport } = await supabase
      .from("monthly_reports")
      .select("*")
      .eq("user_id", userId)
      .eq("period_start", periodStart)
      .eq("period_end", periodEnd)
      .maybeSingle();

    if (existingReport) {
      console.log("[generate-monthly-report] existing report found", {
        userId,
        periodStart,
        periodEnd,
      });
      return json(existingReport, 200);
    }

    const { data: expenses, error: expensesError } = await supabase
      .from("expenses")
      .select("amount, category, store_name, created_at")
      .eq("user_id", userId)
      .gte("created_at", `${periodStart}T00:00:00`)
      .lt("created_at", nextDayIso(periodEnd));

    if (expensesError) throw expensesError;
    console.log("[generate-monthly-report] expenses fetched", {
      userId,
      count: expenses?.length ?? 0,
      from: `${periodStart}T00:00:00`,
      toExclusive: nextDayIso(periodEnd),
    });

    const { data: budgetSetting, error: budgetError } = await supabase
      .from("budget_settings")
      .select("total_budget, cycle_start_day, categories_json")
      .eq("user_id", userId)
      .maybeSingle();

    if (budgetError) throw budgetError;
    console.log("[generate-monthly-report] budget setting fetched", {
      userId,
      found: !!budgetSetting,
    });

    const { data: history, error: historyError } = await supabase
      .from("budget_histories")
      .select("total_budget, total_expense, is_achieved, streak, start_date, end_date")
      .eq("user_id", userId)
      .eq("start_date", periodStart)
      .eq("end_date", periodEnd)
      .maybeSingle();

    if (historyError) throw historyError;
    console.log("[generate-monthly-report] target history fetched", {
      userId,
      found: !!history,
      periodStart,
      periodEnd,
    });

    const { data: allHistories, error: allHistoriesError } = await supabase
      .from("budget_histories")
      .select("total_budget, total_expense, is_achieved, streak, start_date, end_date")
      .eq("user_id", userId)
      .lte("end_date", periodEnd)
      .order("end_date");

    if (allHistoriesError) throw allHistoriesError;
    console.log("[generate-monthly-report] all histories fetched", {
      userId,
      count: allHistories?.length ?? 0,
      upTo: periodEnd,
    });

    const safeExpenses = (expenses ?? []) as ExpenseRow[];
    const safeBudgetSetting = (budgetSetting ?? null) as BudgetSettingRow | null;
    const safeHistory = (history ?? null) as BudgetHistoryRow | null;
    const safeAllHistories = (allHistories ?? []) as BudgetHistoryRow[];

    const totalSpent = safeExpenses.reduce((sum, e) => sum + (e.amount ?? 0), 0);
    const totalBudget =
      safeHistory?.total_budget ??
      safeBudgetSetting?.total_budget ??
      0;

    const remainingAmount = totalBudget - totalSpent;
    const achieved = totalBudget > 0 ? totalSpent <= totalBudget : false;

    const rank = calculateRank(safeAllHistories);

    const categoryMap = new Map<string, number>();
    for (const expense of safeExpenses) {
      const key = (expense.category ?? "未分類").trim() || "未分類";
      categoryMap.set(key, (categoryMap.get(key) ?? 0) + (expense.amount ?? 0));
    }

    const categoryJson = Array.from(categoryMap.entries())
      .map(([name, amount]) => ({
        name,
        amount,
        ratio: totalSpent > 0 ? Math.round((amount / totalSpent) * 100) : 0,
      }))
      .sort((a, b) => b.amount - a.amount);

    const prevText = safeHistory
      ? `達成状況: ${safeHistory.is_achieved ? "予算内" : "予算オーバー"} / 連続達成: ${safeHistory.streak}回`
      : "履歴情報なし";

    const summaryText = buildSummary({
      totalBudget,
      totalSpent,
      remainingAmount,
      achieved,
      topCategories: categoryJson.slice(0, 3),
    });

    let adviceText = buildAdvice({
      achieved,
      totalBudget,
      totalSpent,
      remainingAmount,
      topCategories: categoryJson.slice(0, 3),
    });

    let badges: BadgeResult[] = buildFallbackBadges({
      achieved,
      totalBudget,
      totalSpent,
      remainingAmount,
      topCategories: categoryJson.slice(0, 5),
      history: safeHistory,
    });
    let aiTitle: TitleResult | null = null;

    if (useAi && openAiApiKey) {
      try {
        const aiText = await generateAiAdvice({
          apiKey: openAiApiKey,
          periodStart,
          periodEnd,
          totalBudget,
          totalSpent,
          remainingAmount,
          achieved,
          topCategories: categoryJson.slice(0, 5),
          historyText: prevText,
        });

        if (aiText) {
          adviceText = aiText;
        }

        const aiBadges = await generateAiBadges({
          apiKey: openAiApiKey,
          periodStart,
          periodEnd,
          totalBudget,
          totalSpent,
          remainingAmount,
          achieved,
          topCategories: categoryJson.slice(0, 5),
          historyText: prevText,
        });

        if (aiBadges.length > 0) {
          badges = aiBadges;
        }

        aiTitle = await generateAiTitle({
          apiKey: openAiApiKey,
          totalBudget,
          totalSpent,
          remainingAmount,
          achieved,
          topCategories: categoryJson.slice(0, 5),
        });
      } catch (error) {
        console.log("[generate-monthly-report] AI block failed", {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    const payload = {
      user_id: userId,
      period_start: periodStart,
      period_end: periodEnd,
      total_budget: totalBudget,
      total_spent: totalSpent,
      remaining_amount: remainingAmount,
      achieved,
      rank_json: rank,
      category_json: categoryJson,
      badges_json: badges,
      summary_text: summaryText,
      advice_text: adviceText,
      updated_at: new Date().toISOString(),
    };
    console.log("[generate-monthly-report] payload prepared", {
      userId,
      periodStart,
      periodEnd,
      totalBudget,
      totalSpent,
      remainingAmount,
      achieved,
      categoryCount: categoryJson.length,
      badgeCount: badges.length,
    });

    const { data: saved, error: saveError } = await supabase
      .from("monthly_reports")
      .upsert(payload, {
        onConflict: "user_id,period_start,period_end",
      })
      .select()
      .single();

    if (saveError) throw saveError;
    console.log("[generate-monthly-report] monthly_reports upserted", {
      userId,
      periodStart,
      periodEnd,
      savedId: saved?.id ?? null,
    });

    if (aiTitle) {
      const { error: profileUpdateError } = await supabase
        .from("profiles")
        .update({
          current_title: aiTitle.title,
          current_title_reason: aiTitle.reason,
          current_title_rarity: aiTitle.rarity,
          current_title_updated_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (profileUpdateError) throw profileUpdateError;
      console.log("[generate-monthly-report] profile title updated", {
        userId,
        title: aiTitle.title,
        rarity: aiTitle.rarity,
      });
    }

    if (badges.length > 0) {
      const badgeRows = badges.map((badge) => ({
        user_id: userId,
        period_start: periodStart,
        period_end: periodEnd,
        badge_key: badge.badge_key,
        title: badge.title,
        description: badge.description,
        reason: badge.reason,
        rarity: badge.rarity,
      }));

      const { error: badgeSaveError } = await supabase
        .from("earned_badges")
        .upsert(badgeRows, {
          onConflict: "user_id,period_start,period_end,badge_key",
        });

      if (badgeSaveError) throw badgeSaveError;
      console.log("[generate-monthly-report] earned_badges upserted", {
        userId,
        periodStart,
        periodEnd,
        count: badgeRows.length,
      });
    }

    return json(saved, 201);
  } catch (error) {
    console.error("[generate-monthly-report] fatal error", {
      error,
      message: error instanceof Error ? error.message : null,
      stack: error instanceof Error ? error.stack : null,
      serialized: (() => {
        try {
          return JSON.stringify(error);
        } catch (_) {
          return String(error);
        }
      })(),
    });

    return json(
      {
        error: error instanceof Error
          ? error.message
          : (() => {
              try {
                return JSON.stringify(error);
              } catch (_) {
                return String(error);
              }
            })(),
      },
      500,
    );
  }
});

function buildSummary(args: {
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
}) {
  const { totalBudget, totalSpent, remainingAmount, achieved, topCategories } =
    args;

  const top = topCategories[0];
  const topText = top
    ? `最も支出が多かったのは「${top.name}」で${formatYen(top.amount)}です。`
    : "カテゴリ別の大きな偏りは見つかりませんでした。";

  return achieved
    ? `今月は予算内でした。予算${formatYen(totalBudget)}に対して、支出は${formatYen(totalSpent)}、残りは${formatYen(remainingAmount)}です。${topText}`
    : `今月は予算を超えました。予算${formatYen(totalBudget)}に対して、支出は${formatYen(totalSpent)}で、${formatYen(Math.abs(remainingAmount))}オーバーです。${topText}`;
}

function buildAdvice(args: {
  achieved: boolean;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
}) {
  const { achieved, topCategories, remainingAmount } = args;
  const top = topCategories[0];

  if (achieved) {
    if (top) {
      return `予算内に収まっています。特に「${top.name}」の割合が大きいので、ここを維持しつつ他カテゴリの無駄遣いを抑えるとさらに安定しそうです。`;
    }
    return "予算内に収まっています。このペースを維持できると、やりくりがかなり安定していきます。";
  }

  if (top) {
    return `予算オーバーの主因として「${top.name}」が目立っています。次回はこのカテゴリの使い方を少しだけ見直すと、${formatYen(Math.abs(remainingAmount))}の改善につながりやすいです。`;
  }

  return "予算オーバーでした。高額な支出が出た日を振り返ると、次の期間で調整しやすくなります。";
}


function buildFallbackBadges(args: {
  achieved: boolean;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
  history: BudgetHistoryRow | null;
}): BadgeResult[] {
  const badges: BadgeResult[] = [];
  const spentRatio = args.totalBudget > 0 ? args.totalSpent / args.totalBudget : 0;
  const top = args.topCategories[0];

  if (args.achieved) {
    badges.push({
      badge_key: "budget_guardian",
      title: "予算ガーディアン",
      description: "今月を予算内で守り切りました。",
      reason: `予算${formatYen(args.totalBudget)}に対して支出${formatYen(args.totalSpent)}で着地しました。`,
      rarity: spentRatio <= 0.8 ? "rare" : "common",
    });
  }

  if (args.remainingAmount >= 3000) {
    badges.push({
      badge_key: "margin_master",
      title: "余白マスター",
      description: "しっかり余裕を残して終えました。",
      reason: `${formatYen(args.remainingAmount)}を残して期間を終えました。`,
      rarity: args.remainingAmount >= 10000 ? "epic" : "rare",
    });
  }

  if (top && top.ratio >= 45) {
    badges.push({
      badge_key: "category_spotlight",
      title: `${top.name}フォーカス`,
      description: `今月は「${top.name}」が家計の主役でした。`,
      reason: `${top.name}が全体の${top.ratio}%を占めました。`,
      rarity: top.ratio >= 60 ? "epic" : "common",
    });
  }

  if (args.history && args.history.streak >= 3) {
    badges.push({
      badge_key: "steady_runner",
      title: "堅実ランナー",
      description: "連続達成の流れをしっかり継続中です。",
      reason: `連続達成が${args.history.streak}回まで伸びています。`,
      rarity: args.history.streak >= 6 ? "epic" : "rare",
    });
  }

  return badges.slice(0, 3);
}

async function generateAiTitle(args: {
  apiKey: string;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
}): Promise<TitleResult | null> {
  const prompt = `
あなたは家計アプリの称号生成AIです。

以下のデータから、その人にぴったりの称号を1つだけ作ってください。

ルール:
- JSONのみ返す
- title, reason, rarity を含む
- titleは短くて印象的（例: 静かなる節約家）
- reasonは自然な日本語で
- rarityは common / rare / epic

トーン:
- 「かっこいい / やさしい / 少しユーモア」のどれかにする
- クスッとできる軽い面白さを含めても良い
- ただしふざけすぎない（あくまで愛着が湧くレベル）

店舗・カテゴリの扱い:
- カテゴリや店舗が強く偏っている場合のみ、それを称号に反映する
- 無理に店舗名を使わない

禁止:
- ネガティブすぎる表現
- 批判的・攻撃的な表現

データ:
予算: ${args.totalBudget}
支出: ${args.totalSpent}
残額: ${args.remainingAmount}
達成: ${args.achieved}
カテゴリ: ${JSON.stringify(args.topCategories)}
`;

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${args.apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      input: prompt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.log("[generateAiTitle] request failed", {
      status: response.status,
      body: errorText,
    });
    throw new Error("OpenAI title request failed");
  }

  const jsonResponse = await response.json();
  const text =
    jsonResponse.output?.[0]?.content?.[0]?.text ??
    jsonResponse.output_text ??
    null;

  console.log("[generateAiTitle] raw text", text);

  if (typeof text !== "string" || !text.trim()) {
    return null;
  }

  try {
    const cleaned = text
      .trim()
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/, "")
      .trim();

    const parsed = JSON.parse(cleaned);
    const title = String(parsed?.title ?? "").trim();
    const reason = String(parsed?.reason ?? "").trim();

    if (!title || !reason) return null;

    return {
      title,
      reason,
      rarity: normalizeRarity(parsed?.rarity),
    };
  } catch (error) {
    console.log("[generateAiTitle] parse failed", {
      error: error instanceof Error ? error.message : String(error),
      text,
    });
    return null;
  }
}

async function generateAiBadges(args: {
  apiKey: string;
  periodStart: string;
  periodEnd: string;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
  historyText: string;
}): Promise<BadgeResult[]> {
  const prompt = `
あなたは家計アプリの月次レポート用バッヂ設計アシスタントです。
この期間の家計データを見て、面白くて少し愛着が湧く日本語バッヂを最大3個考えてください。

ルール:
- JSON配列だけを返す
- 各要素は badge_key, title, description, reason, rarity を持つ
- badge_key は英数字とアンダースコアのみ
- rarity は common / rare / epic のいずれか
- title は短く、description は一言、reason は具体的な根拠を書く
- 大げさすぎず、前向きで、少し遊び心があること

期間: ${args.periodStart} 〜 ${args.periodEnd}
予算: ${args.totalBudget}
支出: ${args.totalSpent}
残額: ${args.remainingAmount}
予算達成: ${args.achieved ? "はい" : "いいえ"}
上位カテゴリ: ${JSON.stringify(args.topCategories)}
補足: ${args.historyText}
`;

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${args.apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      input: prompt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.log("[generateAiBadges] request failed", {
      status: response.status,
      body: errorText,
    });
    throw new Error("OpenAI badge request failed");
  }

  const jsonResponse = await response.json();
  const text =
    jsonResponse.output?.[0]?.content?.[0]?.text ??
    jsonResponse.output_text ??
    null;

  if (typeof text !== "string" || !text.trim()) {
    return [];
  }

  try {
    const parsed = JSON.parse(text.trim());
    if (!Array.isArray(parsed)) return [];

    return parsed
      .map((item) => ({
        badge_key: String(item?.badge_key ?? "").trim(),
        title: String(item?.title ?? "").trim(),
        description: String(item?.description ?? "").trim(),
        reason: String(item?.reason ?? "").trim(),
        rarity: normalizeRarity(item?.rarity),
      }))
      .filter(
        (item) =>
          item.badge_key &&
          item.title &&
          item.description &&
          item.reason,
      )
      .slice(0, 3);
  } catch (_) {
    return [];
  }
}

function normalizeRarity(value: unknown): "common" | "rare" | "epic" {
  const rarity = String(value ?? "common").trim().toLowerCase();
  if (rarity === "rare") return "rare";
  if (rarity === "epic") return "epic";
  return "common";
}

function formatYen(value: number) {
  return `${value.toLocaleString("ja-JP")}円`;
}

function toDateKey(value: string) {
  if (!value) return "";
  return value.includes("T") ? value.slice(0, 10) : value;
}

function nextDayIso(date: string) {
  const normalized = date.includes("T") ? date : `${date}T00:00:00`;
  const d = new Date(normalized);
  if (Number.isNaN(d.getTime())) {
    throw new Error(`Invalid date: ${date}`);
  }
  d.setDate(d.getDate() + 1);
  return d.toISOString();
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}
function calculateRank(histories: BudgetHistoryRow[]): RankResult {
  const totalCount = histories.length;
  const achievedCount = histories.filter((item) => item.is_achieved).length;
  const successRate = totalCount > 0 ? achievedCount / totalCount : 0;
  const currentStreak = calculateCurrentStreak(histories);
  const bestStreak = calculateBestStreak(histories);

  const rankKey = resolveRankKey({
    totalCount,
    successRate,
  });

  return {
    rank_key: rankKey,
    rank_label: rankLabel(rankKey),
    total_count: totalCount,
    achieved_count: achievedCount,
    success_rate: Number(successRate.toFixed(4)),
    current_streak: currentStreak,
    best_streak: bestStreak,
  };
}

function calculateCurrentStreak(histories: BudgetHistoryRow[]): number {
  let streak = 0;

  for (let i = histories.length - 1; i >= 0; i--) {
    if (histories[i].is_achieved) {
      streak += 1;
    } else {
      break;
    }
  }

  return streak;
}

function calculateBestStreak(histories: BudgetHistoryRow[]): number {
  let current = 0;
  let best = 0;

  for (const history of histories) {
    if (history.is_achieved) {
      current += 1;
      if (current > best) {
        best = current;
      }
    } else {
      current = 0;
    }
  }

  return best;
}

function resolveRankKey(args: {
  totalCount: number;
  successRate: number;
}): string {
  const { totalCount, successRate } = args;

  if (totalCount >= 12 && successRate >= 0.9) return "diamond";
  if (totalCount >= 9 && successRate >= 0.8) return "platinum";
  if (totalCount >= 6 && successRate >= 0.7) return "gold";

  if (totalCount >= 2 && successRate >= 0.5) return "silver";
  if (totalCount >= 1 && successRate > 0) return "bronze";

  return "starter";
}

function rankLabel(rankKey: string): string {
  switch (rankKey) {
    case "diamond":
      return "ダイヤ";
    case "platinum":
      return "プラチナ";
    case "gold":
      return "ゴールド";
    case "silver":
      return "シルバー";
    case "bronze":
      return "ブロンズ";
    default:
      return "スターター";
  }
}

async function generateAiAdvice(args: {
  apiKey: string;
  periodStart: string;
  periodEnd: string;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
  historyText: string;
}): Promise<string | null> {
  const prompt = `
あなたは家計アプリのアドバイス生成AIです。

以下のデータから、ユーザーに対する短くてやさしいアドバイスを1つ生成してください。

ルール:
- 日本語で自然な文章
- 2〜3文程度
- 責めない・前向き・少し寄り添うトーン

期間: ${args.periodStart} 〜 ${args.periodEnd}
予算: ${args.totalBudget}
支出: ${args.totalSpent}
残額: ${args.remainingAmount}
達成: ${args.achieved}
カテゴリ: ${JSON.stringify(args.topCategories)}
履歴: ${args.historyText}
`;

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${args.apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      input: prompt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.log("[generateAiAdvice] request failed", {
      status: response.status,
      body: errorText,
    });
    throw new Error("OpenAI advice request failed");
  }

  const jsonResponse = await response.json();
  const text =
    jsonResponse.output?.[0]?.content?.[0]?.text ??
    jsonResponse.output_text ??
    null;

  if (typeof text !== "string" || !text.trim()) {
    return null;
  }

  return text.trim();
}