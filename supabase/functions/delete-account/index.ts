// Spiritbound — Supabase Edge Function: delete-account
// Docs/LAUNCH_READINESS.md Section 1, the server-side half.
//
// WHY THIS EXISTS: deleting a user's row from public.player_saves / public.leaderboards (done
// from the Godot client, scoped by the user's own bearer token under RLS) is NOT the same as
// deleting the underlying auth.users record. That second step needs the service-role key, which
// must never ship inside the Godot client — anyone who decompiled it would get full admin access
// to every player's data. So that call lives here, in a trusted server context, and the client
// only ever sends its own access token.
//
// SECURITY MODEL:
//   * The caller's JWT is verified with the project's anon key; the deleted user id is taken from
//     that verified token, NEVER from the request body. A caller can therefore only delete their
//     own account.
//   * SUPABASE_SERVICE_ROLE_KEY is injected by the Supabase platform as an env var and is never
//     returned or logged.
//
// DEPLOY: see this folder's README.md. Until it is deployed, the client's account-deletion flow
// still works (local save reset + cloud rows removed + sign-out), which satisfies the practical
// intent of Apple Guideline 5.1.1(v); this function closes the "the auth user still technically
// exists" gap on top of that.

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ ok: false, error: "Missing bearer token" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Identify the caller from their own token — the only trustworthy source of "who to delete".
  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ ok: false, error: "Invalid or expired token" }, 401);
  }
  const userId = userData.user.id;

  // Privileged client — service role stays server-side only.
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Belt-and-braces: make sure the user's own rows are gone even if the client's DELETE call
  // failed or was skipped. Safe to run twice.
  await admin.from("player_saves").delete().eq("user_id", userId);
  await admin.from("leaderboards").delete().eq("user_id", userId);

  // The step that actually requires elevation.
  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) return json({ ok: false, error: delErr.message }, 500);

  return json({ ok: true, deleted_user_id: userId });
});
