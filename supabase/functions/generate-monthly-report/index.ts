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
  current_budget_history_local_id: number | null;
  categories_json: Array<{
    name?: string;
    badge?: string;
    budget?: number;
  }> | null;
};

type BudgetHistoryRow = {
  id: number;
  local_id: number;
  total_budget: number;
  total_expense: number;
  is_achieved: boolean;
  streak: number;
  best_streak: number;
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
    const localId = Number(body.budget_history_local_id);
    const useAi = Boolean(body.use_ai ?? true);
    const lang = normalizeLang(body.lang);

    console.log("[generate-monthly-report] request", {
      localId,
      useAi,
      lang,
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

    if (!localId) {
      return json({ error: "budget_history_local_id is required." }, 400);
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
      .eq("budget_history_local_id", localId)
      .maybeSingle();

    if (existingReport) {
      console.log("[generate-monthly-report] existing report found", {
        userId,
        localId,
      });
      return json(existingReport, 200);
    }

    // periodStart and periodEnd will be set after fetching history
    let periodStart: string | undefined;
    let periodEnd: string | undefined;

    // Fetch budget history using local_id
    const { data: history, error: historyError } = await supabase
      .from("budget_histories")
      .select("id, local_id, total_budget, total_expense, is_achieved, streak, best_streak, start_date, end_date")
      .eq("user_id", userId)
      .eq("local_id", localId)
      .maybeSingle();

    if (historyError) throw historyError;
    periodStart = history?.start_date ? toDateKey(history.start_date) : undefined;
    periodEnd = history?.end_date ? toDateKey(history.end_date) : undefined;
    console.log("[generate-monthly-report] target history fetched", {
      userId,
      found: !!history,
      periodStart,
      periodEnd,
    });

    if (!history) {
      return json({ error: "Closed budget history not found for this period." }, 400);
    }

    const { data: expenses, error: expensesError } = await supabase
      .from("expenses")
      .select("amount, category, store_name, created_at")
      .eq("user_id", userId)
      .gte("created_at", `${periodStart}T00:00:00`)
      .lt("created_at", `${periodEnd}T00:00:00`);

    if (expensesError) throw expensesError;
    console.log("[generate-monthly-report] expenses fetched", {
      userId,
      count: expenses?.length ?? 0,
      from: `${periodStart}T00:00:00`,
      toExclusive: `${periodEnd}T00:00:00`,
    });

    const { data: budgetSetting, error: budgetError } = await supabase
      .from("budget_settings")
      .select("total_budget, cycle_start_day, current_budget_history_local_id, categories_json")
      .eq("user_id", userId)
      .maybeSingle();

    if (budgetError) throw budgetError;
    console.log("[generate-monthly-report] budget setting fetched", {
      userId,
      found: !!budgetSetting,
    });

    if (
      budgetSetting?.current_budget_history_local_id != null &&
      history.local_id === budgetSetting.current_budget_history_local_id
    ) {
      return json({ error: "Current open budget history cannot be reported yet." }, 400);
    }

    const { data: allHistories, error: allHistoriesError } = await supabase
      .from("budget_histories")
      .select("id, local_id, total_budget, total_expense, is_achieved, streak, best_streak, start_date, end_date")
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

    const totalSpent = safeHistory.total_expense;
    const totalBudget = safeHistory.total_budget;
    const remainingAmount = totalBudget - totalSpent;
    const achieved = safeHistory.is_achieved;

    const rank = calculateRank(safeAllHistories, lang);

    const categoryMap = new Map<string, number>();
    for (const expense of safeExpenses) {
      const fallbackCategory = lang === "en" ? "Uncategorized" : "未分類";
      const key = (expense.category ?? fallbackCategory).trim() || fallbackCategory;
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
      ? lang === "en"
        ? `Status: ${safeHistory.is_achieved ? "within budget" : "over budget"} / current streak: ${safeHistory.streak}`
        : `達成状況: ${safeHistory.is_achieved ? "予算内" : "予算オーバー"} / 連続達成: ${safeHistory.streak}回`
      : lang === "en"
        ? "No history data"
        : "履歴情報なし";

    const summaryText = buildSummary({
      totalBudget,
      totalSpent,
      remainingAmount,
      achieved,
      topCategories: categoryJson.slice(0, 3),
      lang,
    });

    let adviceText = buildAdvice({
      lang,
      achieved,
      totalBudget,
      totalSpent,
      remainingAmount,
      topCategories: categoryJson.slice(0, 3),
    });

    let badges: BadgeResult[] = buildFallbackBadges({
      lang,
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
          lang,
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
          lang,
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
          lang,
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
      budget_history_local_id: localId,
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
      localId,
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
        onConflict: "user_id,budget_history_local_id",
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
  lang: "ja" | "en";
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
}) {
  const { lang, totalBudget, totalSpent, remainingAmount, achieved, topCategories } = args;

  const top = topCategories[0];
  const topText = top
    ? lang === "en"
      ? `Your biggest spending area was "${top.name}" at ${formatMoney(top.amount, lang)}.`
      : `最も支出が多かったのは「${top.name}」で${formatMoney(top.amount, lang)}です。`
    : lang === "en"
      ? "There was no major category imbalance this month."
      : "カテゴリ別の大きな偏りは見つかりませんでした。";

  if (lang === "en") {
    return achieved
      ? `You stayed within budget this month. Against a budget of ${formatMoney(totalBudget, lang)}, you spent ${formatMoney(totalSpent, lang)} and had ${formatMoney(remainingAmount, lang)} left. ${topText}`
      : `You went over budget this month. Against a budget of ${formatMoney(totalBudget, lang)}, you spent ${formatMoney(totalSpent, lang)}, which is ${formatMoney(Math.abs(remainingAmount), lang)} over. ${topText}`;
  }

  return achieved
    ? `今月は予算内でした。予算${formatMoney(totalBudget, lang)}に対して、支出は${formatMoney(totalSpent, lang)}、残りは${formatMoney(remainingAmount, lang)}です。${topText}`
    : `今月は予算を超えました。予算${formatMoney(totalBudget, lang)}に対して、支出は${formatMoney(totalSpent, lang)}で、${formatMoney(Math.abs(remainingAmount), lang)}オーバーです。${topText}`;
}

function buildAdvice(args: {
  lang: "ja" | "en";
  achieved: boolean;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
}) {
  const { lang, achieved, topCategories, remainingAmount } = args;
  const top = topCategories[0];

  if (lang === "en") {
    if (achieved) {
      if (top) {
        return `You stayed within budget. "${top.name}" took a larger share, so keeping that steady while trimming small waste in other areas could make things even more stable.`;
      }
      return "You stayed within budget. Keeping this pace should make your budgeting feel more stable over time.";
    }

    if (top) {
      return `"${top.name}" stands out as the main reason you went over budget. A small review of this category next time could make it easier to improve by ${formatMoney(Math.abs(remainingAmount), lang)}.`;
    }

    return "You went over budget this time. Looking back at the days with larger expenses should make the next period easier to adjust.";
  }

  if (achieved) {
    if (top) {
      return `予算内に収まっています。特に「${top.name}」の割合が大きいので、ここを維持しつつ他カテゴリの無駄遣いを抑えるとさらに安定しそうです。`;
    }
    return "予算内に収まっています。このペースを維持できると、やりくりがかなり安定していきます。";
  }

  if (top) {
    return `予算オーバーの主因として「${top.name}」が目立っています。次回はこのカテゴリの使い方を少しだけ見直すと、${formatMoney(Math.abs(remainingAmount), lang)}の改善につながりやすいです。`;
  }

  return "予算オーバーでした。高額な支出が出た日を振り返ると、次の期間で調整しやすくなります。";
}


function buildFallbackBadges(args: {
  lang: "ja" | "en";
  achieved: boolean;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
  history: BudgetHistoryRow | null;
}): BadgeResult[] {
  const lang = args.lang;
  const badges: BadgeResult[] = [];
  const spentRatio = args.totalBudget > 0 ? args.totalSpent / args.totalBudget : 0;
  const top = args.topCategories[0];

  if (args.achieved) {
    badges.push({
      badge_key: "budget_guardian",
      title: lang === "en" ? "Budget Guardian" : "予算ガーディアン",
      description: lang === "en" ? "You protected this month within budget." : "今月を予算内で守り切りました。",
      reason: lang === "en"
        ? `You landed at ${formatMoney(args.totalSpent, lang)} against a budget of ${formatMoney(args.totalBudget, lang)}.`
        : `予算${formatMoney(args.totalBudget, lang)}に対して支出${formatMoney(args.totalSpent, lang)}で着地しました。`,
      rarity: spentRatio <= 0.8 ? "rare" : "common",
    });
  }

  if (args.remainingAmount >= 3000) {
    badges.push({
      badge_key: "margin_master",
      title: lang === "en" ? "Margin Master" : "余白マスター",
      description: lang === "en" ? "You finished with solid room left." : "しっかり余裕を残して終えました。",
      reason: lang === "en"
        ? `You finished the period with ${formatMoney(args.remainingAmount, lang)} left.`
        : `${formatMoney(args.remainingAmount, lang)}を残して期間を終えました。`,
      rarity: args.remainingAmount >= 10000 ? "epic" : "rare",
    });
  }

  if (top && top.ratio >= 45) {
    badges.push({
      badge_key: "category_spotlight",
      title: lang === "en" ? `${top.name} Spotlight` : `${top.name}フォーカス`,
      description: lang === "en" ? `"${top.name}" was the main character of your budget this month.` : `今月は「${top.name}」が家計の主役でした。`,
      reason: lang === "en"
        ? `${top.name} made up ${top.ratio}% of your spending.`
        : `${top.name}が全体の${top.ratio}%を占めました。`,
      rarity: top.ratio >= 60 ? "epic" : "common",
    });
  }

  if (args.history && args.history.streak >= 3) {
    badges.push({
      badge_key: "steady_runner",
      title: lang === "en" ? "Steady Runner" : "堅実ランナー",
      description: lang === "en" ? "You are keeping your success streak going." : "連続達成の流れをしっかり継続中です。",
      reason: lang === "en"
        ? `Your current streak has reached ${args.history.streak}.`
        : `連続達成が${args.history.streak}回まで伸びています。`,
      rarity: args.history.streak >= 6 ? "epic" : "rare",
    });
  }

  return badges.slice(0, 3);
}

async function generateAiTitle(args: {
  apiKey: string;
  lang: "ja" | "en";
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
}): Promise<TitleResult | null> {
  const prompt = args.lang === "en"
    ? `
You are a title generator for a budgeting app with a gentle characterful tone.

Create exactly one short title that fits this user based on the data below.

Goal:
- Make the title memorable, slightly funny, and affectionate
- It may lightly hint at the app's character, but do not overuse the word "wallet"
- Keep it useful and based on the data, not random

Rules:
- Return JSON only
- Include title, reason, rarity
- title should be short and punchy, like "Close Call Champion", "Wallet Whisperer", "Still Breathing", or "Quiet Saver"
- reason should be natural English and mention the actual spending result
- rarity must be common / rare / epic
- Tone: 80% useful, 20% playful
- A little dry humor is welcome
- Do not be too silly, childish, mean, or dramatic
- Reflect categories or stores only when they are strongly relevant
- Avoid negative, critical, guilt-inducing, or aggressive wording
- Do not use medical, financial advice, or gambling-like wording
- Use the word "wallet" at most once across title and reason combined

Data:
Budget: ${formatMoney(args.totalBudget, args.lang)}
Spent: ${formatMoney(args.totalSpent, args.lang)}
Remaining: ${formatMoney(args.remainingAmount, args.lang)}
Achieved: ${args.achieved}
Categories: ${JSON.stringify(args.topCategories)}
`
    : `
あなたは少しキャラクター感のある家計アプリの称号生成AIです。

以下のデータから、その人にぴったりの称号を1つだけ作ってください。

目的:
- ただの節約称号ではなく、少しクスッとできて記憶に残る称号にする
- アプリのキャラクター感を少しだけ匂わせる。ただし「財布」という単語を多用しない
- ただしデータに基づいた納得感は必ず残す

ルール:
- JSONのみ返す
- title, reason, rarity を含む
- titleは短くて印象的（例: ギリギリ職人、財布の守護者、まだ息してる、静かなる節約家）
- reasonは自然な日本語で、実際の支出結果に触れる
- rarityは common / rare / epic

トーン:
- 8割まじめ、2割クセ
- 少しだけユーモアやキャラクター感を入れてよい
- ふざけすぎない
- ユーザーを責めない

店舗・カテゴリの扱い:
- カテゴリや店舗が強く偏っている場合のみ、それを称号に反映する
- 無理に店舗名を使わない

禁止:
- ネガティブすぎる表現
- 批判的・攻撃的な表現
- 不安を煽る表現
- 医療・金融助言っぽい表現
- titleとreasonを合わせて「財布」は最大1回まで

データ:
予算: ${formatMoney(args.totalBudget, args.lang)}
支出: ${formatMoney(args.totalSpent, args.lang)}
残額: ${formatMoney(args.remainingAmount, args.lang)}
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
  lang: "ja" | "en";
  periodStart: string;
  periodEnd: string;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
  historyText: string;
}): Promise<BadgeResult[]> {
  const prompt = args.lang === "en"
    ? `
You are a badge design assistant for a monthly budgeting report in a budgeting app with a gentle characterful tone.
Look at this period's budgeting data and create up to 3 fun, affectionate English badges.

Goal:
- Badges should feel like small trophies from the app's character, without repeating the word "wallet"
- Make them memorable, slightly witty, and still clearly based on the data
- Keep the tone kind, never mocking

Rules:
- Return a JSON array only
- Each item must have badge_key, title, description, reason, rarity
- badge_key must use only letters, numbers, and underscores
- rarity must be common / rare / epic
- title should be short and punchy
- description should be one short sentence
- reason should include a concrete basis from the data
- Tone: 80% useful, 20% playful
- A little dry humor is welcome, but keep the character flavor subtle
- Do not exaggerate too much
- Avoid guilt, fear, criticism, or aggressive wording
- Across all badges, use the word "wallet" at most once total

Examples of tone:
- "Wallet Whisperer"
- "Close Call Survivor"
- "Still Breathing"
- "Margin Keeper"
- "Snack Budget Diplomat"

Period: ${args.periodStart} to ${args.periodEnd}
Budget: ${formatMoney(args.totalBudget, args.lang)}
Spent: ${formatMoney(args.totalSpent, args.lang)}
Remaining: ${formatMoney(args.remainingAmount, args.lang)}
Within budget: ${args.achieved ? "yes" : "no"}
Top categories: ${JSON.stringify(args.topCategories)}
Context: ${args.historyText}
`
    : `
あなたは少しキャラクター感のある家計アプリの月次レポート用バッヂ設計アシスタントです。
この期間の家計データを見て、面白くて少し愛着が湧く日本語バッヂを最大3個考えてください。

目的:
- アプリのキャラクターからもらう小さなトロフィーのようなバッヂにする。ただし「財布」という単語を多用しない
- 少しクスッとできるが、ちゃんとデータに基づいた納得感を残す
- ユーザーを責めず、前向きにする

ルール:
- JSON配列だけを返す
- 各要素は badge_key, title, description, reason, rarity を持つ
- badge_key は英数字とアンダースコアのみ
- rarity は common / rare / epic のいずれか
- title は短く印象的
- description は一言
- reason は具体的な根拠を書く
- 8割まじめ、2割クセ
- 大げさすぎず、少しキャラクター感のあるユーモアにする

例の方向性:
- 財布の守護者
- ギリギリ生還
- 余白の民
- まだ息してる
- コンビニ外交官

禁止:
- ネガティブすぎる表現
- 批判的・攻撃的な表現
- 不安を煽る表現
- すべてのバッヂ全体で「財布」は最大1回まで

期間: ${args.periodStart} 〜 ${args.periodEnd}
予算: ${formatMoney(args.totalBudget, args.lang)}
支出: ${formatMoney(args.totalSpent, args.lang)}
残額: ${formatMoney(args.remainingAmount, args.lang)}
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

function formatMoney(value: number, lang: "ja" | "en") {
  if (lang === "en") {
    return `$${(value / 100).toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })}`;
  }

  return `${value.toLocaleString("ja-JP")}円`;
}

function formatYen(value: number) {
  return formatMoney(value, "ja");
}

function toDateKey(value: string) {
  if (!value) return "";
  return value.includes("T") ? value.slice(0, 10) : value;
}


function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}
function calculateRank(
  histories: BudgetHistoryRow[],
  lang: "ja" | "en" = "ja",
): RankResult {
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
    rank_label: rankLabel(rankKey, lang),
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

function rankLabel(rankKey: string, lang: "ja" | "en" = "ja"): string {
  if (lang === "en") {
    switch (rankKey) {
      case "diamond":
        return "Diamond";
      case "platinum":
        return "Platinum";
      case "gold":
        return "Gold";
      case "silver":
        return "Silver";
      case "bronze":
        return "Bronze";
      default:
        return "Starter";
    }
  }

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
  lang: "ja" | "en";
  periodStart: string;
  periodEnd: string;
  totalBudget: number;
  totalSpent: number;
  remainingAmount: number;
  achieved: boolean;
  topCategories: Array<{ name: string; amount: number; ratio: number }>;
  historyText: string;
}): Promise<string | null> {
  const prompt = args.lang === "en"
    ? `
You are a monthly reflection writer for a budgeting app with a gentle characterful tone.

Generate one short, gentle monthly reflection based on the data below.

Goal:
- Make it useful, warm, and a little memorable
- It can have a subtle characterful touch, but should mostly sound like a clean monthly reflection
- Keep it 80% practical reflection and 20% playful character

Rules:
- Natural English
- About 2 to 3 sentences
- Do not blame the user
- Keep it positive and slightly supportive
- Avoid repeating the word "wallet"; use it at most once, and only if it feels natural
- Do not overdo jokes
- Do not imply the app can chat, counsel, or provide ongoing personal support
- Do not say "feel free to ask", "talk to me anytime", or "I'm here to help"
- Make it factual and based on the data
- Avoid financial advice, medical advice, guilt, fear, or aggressive wording

Period: ${args.periodStart} to ${args.periodEnd}
Budget: ${formatMoney(args.totalBudget, args.lang)}
Spent: ${formatMoney(args.totalSpent, args.lang)}
Remaining: ${formatMoney(args.remainingAmount, args.lang)}
Achieved: ${args.achieved}
Categories: ${JSON.stringify(args.topCategories)}
History: ${args.historyText}
`
    : `
あなたは少しキャラクター感のある家計アプリの月次ふりかえり生成AIです。

以下のデータから、ユーザーに対する短くてやさしい月のふりかえりを1つ生成してください。

目的:
- ただの分析ではなく、少し記憶に残る言葉にする
- ほんの少しキャラクター感は出すが、基本は読みやすい月次レポートにする
- 8割は実用的な振り返り、2割だけキャラクター感を入れる

ルール:
- 日本語で自然な文章
- 2〜3文程度
- 責めない・前向き・少し寄り添うトーン
- 「財布」という単語は最大1回まで。無理に使わない
- ただし冗談を入れすぎない
- アプリや人が会話・相談対応できるような表現は禁止
- 「いつでも相談してください」「また相談してね」「気軽に話してください」などの文は禁止
- サポート窓口・伴走者・友達のように振る舞わない
- 事実に基づいた振り返りコメントにする

禁止:
- ユーザーを責める表現
- 不安を煽る表現
- 医療・金融助言っぽい表現
- 攻撃的な表現

期間: ${args.periodStart} 〜 ${args.periodEnd}
予算: ${formatMoney(args.totalBudget, args.lang)}
支出: ${formatMoney(args.totalSpent, args.lang)}
残額: ${formatMoney(args.remainingAmount, args.lang)}
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

function normalizeLang(value: unknown): "ja" | "en" {
  return value === "en" ? "en" : "ja";
}