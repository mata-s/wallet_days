import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;

    const authHeader = req.headers.get("Authorization")?.trim();
    if (!authHeader || authHeader !== `Bearer ${webhookSecret}`) {
      return json({ error: "Unauthorized" }, 401);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const body = await req.json();

    const event = body?.event ?? body;
    const eventType = String(event?.type ?? "").trim();
    const appUserId = String(
      event?.app_user_id ?? event?.appUserId ?? "",
    ).trim();

    console.log("[revenuecat-webhook] event received", {
      eventType,
      appUserId,
      originalAppUserId: event?.original_app_user_id ?? null,
      aliases: event?.aliases ?? null,
      productId: event?.product_id ?? null,
      environment: event?.environment ?? null,
    });

    if (!eventType) {
      return json({ error: "Missing event type" }, 400);
    }

    if (!appUserId) {
      console.log("[revenuecat-webhook] skip profile update: empty app_user_id", {
        eventType,
        originalAppUserId: event?.original_app_user_id ?? null,
        aliases: event?.aliases ?? null,
        productId: event?.product_id ?? null,
        environment: event?.environment ?? null,
      });

      return json({
        ok: true,
        skipped: true,
        reason: "empty app_user_id",
        event_type: eventType,
      });
    }

    const isPremiumActive = isPremiumEvent(eventType);

    const { data: updatedProfile, error: updateError } = await supabase
      .from("profiles")
      .update({
        is_premium_cached: isPremiumActive,
        premium_updated_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", appUserId)
      .select("id, is_premium_cached")
      .maybeSingle();

    if (updateError) {
      console.error("[revenuecat-webhook] profile update error", updateError);
      throw updateError;
    }

    if (!updatedProfile) {
      console.error("[revenuecat-webhook] profile not found for app_user_id", {
        appUserId,
      });
      return json(
        {
          error: "Profile not found for app_user_id",
          app_user_id: appUserId,
        },
        404,
      );
    }

    console.log("[revenuecat-webhook] profile updated", {
      appUserId,
      isPremiumActive,
      updatedProfile,
    });

    return json({
      ok: true,
      event_type: eventType,
      premium: isPremiumActive,
      app_user_id: appUserId,
    });
  } catch (error) {
    return json(
      {
        error: error instanceof Error ? error.message : "Unknown error",
      },
      500,
    );
  }
});

function isPremiumEvent(eventType: string) {
  const normalized = eventType.toUpperCase();

  const activeEvents = new Set([
    "INITIAL_PURCHASE",
    "NON_RENEWING_PURCHASE",
    "RENEWAL",
    "PRODUCT_CHANGE",
    "UNCANCELLATION",
    "SUBSCRIPTION_EXTENDED",
    "TEMPORARY_ENTITLEMENT_GRANT",
  ]);

  const inactiveEvents = new Set([
    "CANCELLATION",
    "EXPIRATION",
    "BILLING_ISSUE",
    "TRANSFER",
    "REFUND",
    "REVOKE",
  ]);

  if (activeEvents.has(normalized)) return true;
  if (inactiveEvents.has(normalized)) return false;

  return false;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}
