// Spiritbound — Supabase Edge Function: verify-purchase
// Docs/LAUNCH_READINESS.md Section 2, the server-side half of the season-pass purchase gate.
//
// WHY THIS EXISTS: whatever an on-device billing plugin reports is spoofable on a
// jailbroken/rooted device. The Godot client therefore never decides by itself that a purchase
// is real — it sends the receipt here, and only a verified answer unlocks the premium track.
// This function is also the only writer of `public.entitlements` (service-role key stays
// server-side; the client can read only its own row, and cannot mint one).
//
// TWO CALLS, ONE ENDPOINT:
//   * body { product_id, receipt, transaction_id } — verify a receipt with Apple/Google, record
//     the entitlement, answer { ok: true, premium: true }.
//   * body { product_id } with no receipt — "what does this account already own?", used by
//     Restore Purchases on a fresh install where the local receipt cache is gone. Answers from
//     the entitlements table only; it never invents an entitlement.
//
// FAIL CLOSED. Missing credentials, an unreachable Apple/Google API, or a receipt that doesn't
// verify all return premium:false. Never "assume it's fine because the client said so".
//
// DEPLOY: see this folder's README.md. Until it is deployed, `PurchaseService` gets
// "not verified" and grants nothing — the premium track stays locked, which is the intended
// behavior for an unconfigured store, not a bug to work around.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Store verification — INTEGRATION POINTS, not a finished integration.
// ---------------------------------------------------------------------------
// Both return { verified: boolean, detail: string }. They deliberately return verified:false
// (rather than throwing something a caller might swallow into a "true") whenever the credentials
// aren't configured, so an unconfigured deployment can never grant a paid entitlement.
//
// Apple: App Store Server API. Needs APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (ES256
// .p8), APPLE_BUNDLE_ID, APPLE_ENVIRONMENT. `receipt` is the JWS transaction representation from
// StoreKit 2; verify its signature chain against Apple's root CAs and read
// `transactionId`/`productId`/`revocationDate` out of the payload. Do not trust unverified
// claims decoded from the JWS.
// Google: Play Developer API. Needs GOOGLE_SERVICE_ACCOUNT_JSON, GOOGLE_PACKAGE_NAME.
// GET /androidpublisher/v3/applications/{package}/purchases/subscriptionsv2/tokens/{token}
// (or products/{sku}/tokens/{token} for a one-off), then check purchaseState/completionTime.
//
// Vendor the SDKs (`npm:apple-store-server-api`, `npm:googleapis`) at the top and fill these in
// when the store credentials exist. Until then they are honest stubs, and the gate stays shut.

interface VerifyResult {
  verified: boolean;
  detail: string;
}

async function verifyWithApple(_receipt: string, _transactionId: string): Promise<VerifyResult> {
  if (!Deno.env.get("APPLE_PRIVATE_KEY")) {
    return { verified: false, detail: "apple_credentials_not_configured" };
  }
  return { verified: false, detail: "apple_verification_not_implemented" };
}

async function verifyWithGoogle(_receipt: string, _transactionId: string): Promise<VerifyResult> {
  if (!Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")) {
    return { verified: false, detail: "google_credentials_not_configured" };
  }
  return { verified: false, detail: "google_verification_not_implemented" };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ ok: false, error: "Missing bearer token" }, 401);
  }

  let body: { product_id?: string; receipt?: string; transaction_id?: string; platform?: string };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "Invalid JSON body" }, 400);
  }

  const productId = body.product_id;
  if (!productId) return json({ ok: false, error: "Missing product_id" }, 400);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Identity comes from the caller's own token, never from the body.
  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ ok: false, error: "Invalid or expired token" }, 401);
  }
  const userId = userData.user.id;

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Restore path: answer from what has already been verified for this account.
  if (!body.receipt) {
    const { data, error } = await admin
      .from("entitlements")
      .select("product_id, verified_at")
      .eq("user_id", userId)
      .eq("product_id", productId)
      .limit(1);
    if (error) return json({ ok: false, error: error.message }, 500);
    const owns = Array.isArray(data) && data.length > 0;
    return json({ ok: true, premium: owns, source: "entitlements_lookup" });
  }

  const platform = body.platform === "android" ? "android" : "ios";
  const result = platform === "android"
    ? await verifyWithGoogle(body.receipt, body.transaction_id ?? "")
    : await verifyWithApple(body.receipt, body.transaction_id ?? "");

  if (!result.verified) {
    // Authoritative "no": the client must not unlock on this.
    return json({ ok: true, premium: false, detail: result.detail });
  }

  const { error: insErr } = await admin.from("entitlements").upsert(
    {
      user_id: userId,
      product_id: productId,
      platform,
      transaction_id: body.transaction_id ?? null,
      source: "purchase",
      verified_at: new Date().toISOString(),
    },
    { onConflict: "user_id,product_id,transaction_id" },
  );
  if (insErr) return json({ ok: false, error: insErr.message }, 500);

  return json({ ok: true, premium: true, detail: result.detail });
});
