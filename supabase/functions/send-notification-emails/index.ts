import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-notification-worker-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

type OutboxRow = {
  id: string;
  notification_id: string;
  recipient_id: string;
  attempts: number;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const fromEmail = Deno.env.get("RESEND_FROM_EMAIL");
  const workerSecret = Deno.env.get("NOTIFICATION_WORKER_SECRET");
  if (!serviceRoleKey || !resendApiKey || !fromEmail || !workerSecret) {
    return json({ error: "Notification email worker is not configured" }, 503);
  }
  if (request.headers.get("x-notification-worker-secret") !== workerSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) return json({ error: "Supabase URL is not configured" }, 503);
  const admin = createClient(supabaseUrl, serviceRoleKey);

  // Recover rows left in processing by a crashed worker so delivery remains
  // retryable instead of permanently stranded.
  await admin
    .from("notification_email_outbox")
    .update({ status: "failed", last_error: "Recovered stale processing attempt" })
    .eq("status", "processing")
    .lt("processing_started_at", new Date(Date.now() - 15 * 60 * 1000).toISOString());

  const { data: rows, error: queueError } = await admin
    .from("notification_email_outbox")
    .select("id, notification_id, recipient_id, attempts")
    .in("status", ["pending", "failed"])
    .lt("attempts", 5)
    .order("created_at", { ascending: true })
    .limit(25);
  if (queueError) return json({ error: "Could not read email queue" }, 500);

  let sent = 0;
  let failed = 0;
  for (const row of (rows ?? []) as OutboxRow[]) {
    const claimed = await claim(admin, row);
    if (!claimed) continue;

    try {
      const { data: notification, error: notificationError } = await admin
        .from("notifications")
        .select("id, user_id, type, title, body")
        .eq("id", row.notification_id)
        .eq("user_id", row.recipient_id)
        .maybeSingle();
      if (notificationError || !notification) throw new Error("Notification not found");

      const { data: authUser, error: authError } = await admin.auth.admin.getUserById(row.recipient_id);
      const recipientEmail = authUser?.user?.email;
      if (authError || !recipientEmail) throw new Error("Recipient email not found");

      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: fromEmail,
          to: [recipientEmail],
          subject: notification.title,
          text: notification.body,
        }),
      });
      if (!response.ok) throw new Error(`Email provider returned ${response.status}`);

      await admin.from("notification_email_outbox").update({
        status: "sent",
        sent_at: new Date().toISOString(),
        last_error: null,
      }).eq("id", row.id);
      sent++;
    } catch (error) {
      await admin.from("notification_email_outbox").update({
        status: "failed",
        last_error: error instanceof Error ? error.message : "Email delivery failed",
      }).eq("id", row.id);
      failed++;
    }
  }

  return json({ sent, failed });
});

async function claim(admin: ReturnType<typeof createClient>, row: OutboxRow): Promise<boolean> {
  const { data, error } = await admin
    .from("notification_email_outbox")
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
