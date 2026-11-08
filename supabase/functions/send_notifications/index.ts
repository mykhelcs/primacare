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
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase configuration environment variables.");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const timeCtx = getManilaTimeContext();

    // 1. Fetch pending notifications due for delivery up to the current Asia/Manila date boundary
    const { data: queue, error: fetchErr } = await supabase
      .from("notifications_queue")
      .select("id, patient_id, type, message, scheduled_for, patients(full_name, contact_number, email)")
      .eq("status", "pending")
      .lte("scheduled_for", timeCtx.manilaEndOfDayIso)
      .limit(50);

    if (fetchErr) throw fetchErr;

    // 2. Check expiring batches anchored to Asia/Manila date via RPC
    const { data: expiringBatches } = await supabase.rpc("get_expiring_batches", {
      days_ahead: 30,
    });

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
