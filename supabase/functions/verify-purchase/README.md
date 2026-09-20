# Edge Function: verify-purchase

Server-side half of the season-pass purchase gate (`Docs/LAUNCH_READINESS.md` Section 2).

Read `index.ts`'s own header first — it explains why this exists and what it deliberately does
*not* do yet (the Apple/Google verification calls are honest stubs; the gate stays shut until
real credentials are configured).

## One-time setup (needs Supabase project access)

1. Create the entitlements table:
   - Supabase dashboard → SQL editor, paste `Docs/sql/2026_entitlements.sql`, run it.
   - Or: `supabase db execute -f Docs/sql/2026_entitlements.sql`
2. Deploy this function:
   ```bash
   supabase functions deploy verify-purchase
   ```
   `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected by the
   Supabase platform automatically — do not add them by hand and never put the service-role key
   anywhere in the Godot client.
3. When store credentials exist, set them as function secrets and fill in
   `verifyWithApple` / `verifyWithGoogle` in `index.ts`:
   ```bash
   supabase secrets set APPLE_ISSUER_ID=... APPLE_KEY_ID=... APPLE_PRIVATE_KEY=... \
                        APPLE_BUNDLE_ID=com.jiacong.spiritbound APPLE_ENVIRONMENT=Production
   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON=... GOOGLE_PACKAGE_NAME=...
   ```
   Until those are set, both verifiers return `verified:false` and the client's
   `PurchaseService` reports "not verified" — i.e. nothing unlocks.

## Behavior

| Request body | Meaning | Response |
| --- | --- | --- |
| `{ product_id, receipt, transaction_id, platform? }` | Verify a receipt with the store | `{ ok: true, premium: true|false, detail }` |
| `{ product_id }` | "What does this account already own?" (Restore Purchases) | `{ ok: true, premium: bool, source: "entitlements_lookup" }` |

Identity always comes from the caller's own bearer token, never from the request body, so a
caller can only ever ask about or record entitlements for their own account. Nothing here is
reachable with the anon key alone.

## What the client does with the answer

`Godot/scripts/purchase_service.gd` is the only writer of `profile.season_pass.is_premium`, and
it only writes `true` on a `premium: true` answer from this function. A `premium: false` answer on
the restore path actively revokes the flag (refund / revoked transaction).
