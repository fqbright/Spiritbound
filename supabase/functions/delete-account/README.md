# delete-account Edge Function

Server-side half of account deletion (`Docs/LAUNCH_READINESS.md` §1). Deletes the caller's
`auth.users` record, which the Godot client deliberately cannot do (it needs the service-role
key, which must never ship in the app).

## One-time deploy

Requires the Supabase CLI and a project login. Run from the **repo root** (the folder that
contains `supabase/`):

```bash
supabase login
supabase link --project-ref <your-project-ref>      # ref is in the project URL
supabase functions deploy delete-account
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected by the
platform automatically — **do not** set the service-role key anywhere in this repo.

## Verify it works

```bash
# Should 401 (no token):
curl -i -X POST https://<project-ref>.supabase.co/functions/v1/delete-account

# Should 200 {"ok":true,...} once called with a real user's access token:
curl -i -X POST https://<project-ref>.supabase.co/functions/v1/delete-account \
  -H "Authorization: Bearer <user-access-token>"
```

## Wiring it into the client (optional follow-up)

`SpiritAuth.delete_account()` (`Godot/scripts/auth_service.gd`) currently deletes the
`player_saves`/`leaderboards` rows with the user's own token and signs out. To also remove the
`auth.users` record, POST to this function with the same access token **before** the two
Supabase DELETEs (the account must still exist to be identified), tolerating failure the same
way the existing calls do — a failed privileged delete must not strand the player in a
half-deleted state.

## Security notes

- The user id is taken from the caller's verified JWT, never from the request body, so a caller
  can only delete their own account.
- Never commit the service-role key. Never pass it to the Godot client. Grep the diff for
  `service_role` before shipping.
