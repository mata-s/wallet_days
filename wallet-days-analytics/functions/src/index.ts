import {setGlobalOptions} from "firebase-functions/v2/options";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {createClient} from "@supabase/supabase-js";

setGlobalOptions({
  timeoutSeconds: 540,
  memory: "512MiB",
});

type LatestUserStreakState = {
  user_id: string;
  best_streak: number | null;
  current_streak: number | null;
  history_created_at: string;
  cohort_month: string | null;
};

type DistributionInsert = {
  snapshot_date: string;
  metric_key: string;
  segment_key: string;
  metric_value: number;
  user_count: number;
  sample_size: number;
};

/**
 * Builds distribution rows for a given metric.
 *
 * Groups users by the specified metric value and returns rows formatted for
 * insertion into the user_metric_distributions table.
 *
 * @param {LatestUserStreakState[]} users Latest streak state rows.
 * @param {("best_streak"|"current_streak")} metricKey Metric to aggregate.
 * @param {string} segmentKey Segment identifier such as "all"
 * or "cohort:2026-04".
 * @return {DistributionInsert[]} Distribution rows ready to insert.
 */
function buildDistributionRows(
  users: LatestUserStreakState[],
  metricKey: "best_streak" | "current_streak",
  segmentKey: string
): DistributionInsert[] {
  const distribution: Record<number, number> = {};

  users.forEach((user) => {
    const rawValue = user[metricKey];
    if (rawValue == null || rawValue < 1) return;

    const value = Number(rawValue);
    distribution[value] = (distribution[value] || 0) + 1;
  });

  const sampleSize = users.length;
  const snapshotDate = new Date().toISOString().slice(0, 10);

  return Object.entries(distribution).map(([metricValue, count]) => ({
    snapshot_date: snapshotDate,
    metric_key: metricKey,
    segment_key: segmentKey,
    metric_value: Number(metricValue),
    user_count: count,
    sample_size: sampleSize,
  }));
}

export const updateStreakDistribution = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "Asia/Tokyo",
  },
  async () => {
    try {
      const supabaseUrl = process.env.SUPABASE_URL;
      const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

      if (!supabaseUrl || !supabaseServiceRoleKey) {
        console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
        return;
      }

      const supabase =
      createClient(supabaseUrl, supabaseServiceRoleKey);
      const cutoff =
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

      const {data, error} = await supabase.rpc(
        "get_latest_user_streak_states_with_cohort",
        {
          cutoff_at: cutoff,
        }
      );

      if (error) throw error;

      const users = (data ?? []) as LatestUserStreakState[];

      if (users.length === 0) {
        console.log("No target users found");
        return;
      }

      const allRows: DistributionInsert[] = [
        ...buildDistributionRows(users, "best_streak", "all"),
        ...buildDistributionRows(users, "current_streak", "all"),
      ];

      const cohortRows: DistributionInsert[] = [];
      const cohortMap = new Map<string, LatestUserStreakState[]>();

      users.forEach((user) => {
        if (!user.cohort_month) return;
        const segmentKey = `cohort:${user.cohort_month}`;
        const existing = cohortMap.get(segmentKey) ?? [];
        existing.push(user);
        cohortMap.set(segmentKey, existing);
      });

      cohortMap.forEach((cohortUsers, segmentKey) => {
        cohortRows.push(
          ...buildDistributionRows(cohortUsers, "best_streak", segmentKey),
          ...buildDistributionRows(cohortUsers, "current_streak", segmentKey)
        );
      });

      const inserts = [...allRows, ...cohortRows];

      const {error: deleteError} = await supabase
        .from("user_metric_distributions")
        .delete()
        .in("metric_key", ["best_streak", "current_streak"]);

      if (deleteError) throw deleteError;

      if (inserts.length === 0) {
        console.log("No distribution rows generated");
        return;
      }

      const {error: insertError} = await supabase
        .from("user_metric_distributions")
        .insert(inserts);

      if (insertError) throw insertError;

      console.log("updateStreakDistribution success", {
        userCount: users.length,
        insertCount: inserts.length,
        cohortCount: cohortMap.size,
      });
    } catch (e) {
      console.error(e);
    }
  }
);
