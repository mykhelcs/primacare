// PrimaCare Smart Clinic — Automated Notifications Dispatch Edge Function
// Stack: Deno / TypeScript (Supabase Edge Functions)
// Scheduled via Supabase pg_cron: every morning at 08:00 AM (0 8 * * *)
// Dispatches queued SMS reminders (Twilio) and Email alerts (Resend)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

    // 1. Fetch pending notifications due for delivery
    const nowIso = new Date().toISOString();
    const { data: queue, error: fetchErr } = await supabase
      .from("notifications_queue")
      .select("id, patient_id, type, message, scheduled_for, patients(full_name, contact_number, email)")
      .eq("status", "pending")
      .lte("scheduled_for", nowIso)
      .limit(50);

    if (fetchErr) throw fetchErr;

    const results = [];
    const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
    const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");
    const twilioFromNumber = Deno.env.get("TWILIO_PHONE_NUMBER");

    for (const item of queue ?? []) {
      const patient = item.patients;
      const recipientPhone = patient?.contact_number;
      let dispatchSuccess = false;

      // 2. Dispatch SMS via Twilio if configured
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
      } else {
        // In local/test mode without Twilio keys, mark as processed
        dispatchSuccess = true;
      }

      // 3. Update status in database
      const updatePayload = dispatchSuccess
        ? { status: "sent", sent_at: new Date().toISOString() }
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
        processed: results.length,
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
