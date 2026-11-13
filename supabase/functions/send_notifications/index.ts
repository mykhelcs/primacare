// PrimaCare Smart Clinic — Automated Notifications & Expiry Watcher Edge Function
// Stack: Deno / TypeScript (Supabase Edge Functions)
// Timezone: Strictly anchored to Asia/Manila (UTC+08:00) to prevent off-by-one
//           date errors between midnight (00:00) and 08:00 AM PHT.
// Dispatches queued SMS reminders (Twilio), Email alerts (Resend), and evaluates
// near-expiry batches using the Philippine calendar date.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

/**
 * Computes the exact calendar date (YYYY-MM-DD) and end-of-day cutoff timestamp
 * in Asia/Manila (UTC+08:00), eliminating UTC midnight-to-8AM off-by-one drift.
 */
function getManilaTimeContext(referenceDate: Date = new Date()) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Manila",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const manilaDateStr = formatter.format(referenceDate); // YYYY-MM-DD in Asia/Manila
  const manilaEndOfDayIso = `${manilaDateStr}T23:59:59.999+08:00`;
  return {
    timezone: "Asia/Manila",
    manilaDateStr,
    manilaEndOfDayIso,
    nowIso: referenceDate.toISOString(),
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const expectedCronSecret = Deno.env.get("CRON_SECRET") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase configuration environment variables.");
    }

    const authHeader = req.headers.get("authorization") ?? "";
    const cronSecret = req.headers.get("x-cron-secret") ?? "";
    const bearerToken = authHeader.toLowerCase().startsWith("bearer ")
      ? authHeader.slice(7).trim()
      : "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Require either a valid CRON_SECRET, the service role key, or an authenticated Supabase user JWT
    const hasValidCronSecret =
      expectedCronSecret.length > 0 && cronSecret === expectedCronSecret;
    const hasServiceKey = bearerToken.length > 0 && bearerToken === supabaseServiceKey;
    let hasAuthenticatedUser = false;

    if (!hasValidCronSecret && !hasServiceKey && bearerToken.length > 0) {
      const { data: userData, error: userErr } = await supabase.auth.getUser(bearerToken);
      hasAuthenticatedUser = !userErr && Boolean(userData?.user);
    }

    if (!hasValidCronSecret && !hasServiceKey && !hasAuthenticatedUser) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized invocation." }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        }
      );
    }

    const timeCtx = getManilaTimeContext();
    const manilaStartOfDayIso = `${timeCtx.manilaDateStr}T00:00:00.000+08:00`;

    // 1. Fetch pending notifications due for delivery up to the current Asia/Manila date boundary
    const { data: queue, error: fetchErr } = await supabase
      .from("notifications_queue")
      .select("id, patient_id, type, message, scheduled_for, patients(full_name, contact_number, email)")
      .eq("status", "pending")
      .lte("scheduled_for", timeCtx.manilaEndOfDayIso)
      .limit(50);

    if (fetchErr) throw fetchErr;

    // 2. Check expiring batches anchored to Asia/Manila date via RPC and enqueue deduplicated daily alerts
    const { data: expiringBatches } = await supabase.rpc("get_expiring_batches", {
      days_ahead: 30,
    });

    let expiryAlertsEnqueued = 0;
    if (Array.isArray(expiringBatches) && expiringBatches.length > 0) {
      const { data: existingTodayAlerts } = await supabase
        .from("notifications_queue")
        .select("message")
        .eq("type", "expiry_alert")
        .gte("created_at", manilaStartOfDayIso);

      const existingMessages = new Set(
        (existingTodayAlerts ?? []).map((row: { message: string }) => row.message)
      );

      const newAlertRows = expiringBatches
        .map((batch: {
          item_name: string;
          batch_number: string;
          quantity_remaining: number;
          expiry_date: string;
          days_remaining: number;
        }) => {
          const message =
            `[${timeCtx.manilaDateStr}] Expiry Alert: ${batch.item_name} ` +
            `(Batch ${batch.batch_number}) — ${batch.quantity_remaining} unit(s) ` +
            `expiring on ${batch.expiry_date} (${batch.days_remaining}d remaining).`;
          return {
            patient_id: null,
            type: "expiry_alert",
            message,
            scheduled_for: timeCtx.nowIso,
            status: "pending",
          };
        })
        .filter((row) => !existingMessages.has(row.message));

      if (newAlertRows.length > 0) {
        const { error: insertAlertErr } = await supabase
          .from("notifications_queue")
          .insert(newAlertRows);
        if (!insertAlertErr) {
          expiryAlertsEnqueued = newAlertRows.length;
        }
      }
    }

    const results = [];
    const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
    const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");
    const twilioFromNumber = Deno.env.get("TWILIO_PHONE_NUMBER");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    for (const item of queue ?? []) {
      const patient = item.patients;
      const recipientPhone = patient?.contact_number;
      const recipientEmail = patient?.email;
      let dispatchSuccess = false;

      // 3A. Dispatch SMS via Twilio if configured
      if (twilioAccountSid && twilioAuthToken && recipientPhone) {
        try {
          const authHeader = "Basic " + btoa(`${twilioAccountSid}:${twilioAuthToken}`);
          const body = new URLSearchParams({
            To: recipientPhone,
            From: twilioFromNumber ?? "+1234567890",
            Body: item.message,
          });

          const twilioRes = await fetch(
            `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`,
            {
              method: "POST",
              headers: {
                Authorization: authHeader,
                "Content-Type": "application/x-www-form-urlencoded",
              },
              body: body.toString(),
            }
          );

          dispatchSuccess = twilioRes.ok;
        } catch (smsErr) {
          console.error(`Twilio SMS dispatch failed for notification ${item.id}:`, smsErr);
        }
      }

      // 3B. Dispatch Email via Resend if configured and recipient has email
      if (!dispatchSuccess && resendApiKey && recipientEmail) {
        try {
          const emailRes = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${resendApiKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: "PrimaCare Clinic <notifications@primacare.ph>",
              to: [recipientEmail],
              subject: `PrimaCare Reminder (${timeCtx.manilaDateStr})`,
              text: item.message,
            }),
          });
          dispatchSuccess = emailRes.ok;
        } catch (emailErr) {
          console.error(`Resend Email dispatch failed for notification ${item.id}:`, emailErr);
        }
      }

      // In local/test mode without external provider keys, mark as processed
      if (!twilioAccountSid && !resendApiKey) {
        dispatchSuccess = true;
      }

      // 4. Update status in database
      const updatePayload = dispatchSuccess
        ? { status: "sent", sent_at: timeCtx.nowIso }
        : { status: "failed" };

      await supabase
        .from("notifications_queue")
        .update(updatePayload)
        .eq("id", item.id);

      results.push({ id: item.id, status: updatePayload.status });
    }

    return new Response(
      JSON.stringify({
        success: true,
        timezone: timeCtx.timezone,
        manila_date: timeCtx.manilaDateStr,
        processed: results.length,
        expiring_batches_count: (expiringBatches ?? []).length,
        expiry_alerts_enqueued: expiryAlertsEnqueued,
        dispatches: results,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
