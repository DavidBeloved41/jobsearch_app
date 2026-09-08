import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-notification-worker-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

type SmsRow = {
  id: string;
  notification_id: string;
  recipient_id: string;
  phone_number: string;
  attempts: number;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = Deno.env.get("SMS_PROVIDER_API_KEY");
  const senderId = Deno.env.get("SMS_PROVIDER_SENDER_ID");
  const workerSecret = Deno.env.get("NOTIFICATION_WORKER_SECRET");
  if (!serviceRoleKey || !apiKey || !senderId || !workerSecret) {
    return json({ error: "SMS provider is not configured" }, 503);
  }
  if (request.headers.get("x-notification-worker-secret") !== workerSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) return json({ error: "Supabase URL is not configured" }, 503);
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: rows, error } = await admin
    .from("notification_sms_outbox")
    .select("id, notification_id, recipient_id, phone_number, attempts")
    .in("status", ["pending", "failed"])
    .lt("attempts", 5)
    .order("created_at", { ascending: true })
    .limit(25);
  if (error) return json({ error: "Could not read SMS queue" }, 500);

  let sent = 0;
  let failed = 0;
  for (const row of (rows ?? []) as SmsRow[]) {
    if (!(await claim(admin, row))) continue;
    try {
      const { data: notification } = await admin
        .from("notifications")
        .select("title, body, user_id")
        .eq("id", row.notification_id)
        .eq("user_id", row.recipient_id)
        .maybeSingle();
      if (!notification) throw new Error("Notification not found");

      const response = await fetch("https://api.ng.termii.com/api/sms/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          api_key: apiKey,
          to: row.phone_number,
          from: senderId,
          sms: `${notification.title}: ${notification.body}`,
          type: "plain",
          channel: "generic",
        }),
      });
      if (!response.ok) throw new Error(`SMS provider returned ${response.status}`);

      await admin.from("notification_sms_outbox").update({
        status: "sent",
        sent_at: new Date().toISOString(),
        last_error: null,
      }).eq("id", row.id);
      sent++;
    } catch (error) {
      await admin.from("notification_sms_outbox").update({
        status: "failed",
        last_error: error instanceof Error ? error.message : "SMS delivery failed",
      }).eq("id", row.id);
      failed++;
    }
  }
  return json({ sent, failed });
});

async function claim(admin: ReturnType<typeof createClient>, row: SmsRow): Promise<boolean> {
  const { data, error } = await admin
    .from("notification_sms_outbox")
    .update({
      status: "processing",
      attempts: row.attempts + 1,
      processing_started_at: new Date().toISOString(),
    })
    .eq("id", row.id)
    .in("status", ["pending", "failed"])
    .select("id");
  return !error && Array.isArray(data) && data.length === 1;
}

function json(value: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(value), { status, headers: jsonHeaders });
}
