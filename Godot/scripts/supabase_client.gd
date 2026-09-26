extends RefCounted
class_name SupabaseClient

# ==============================================================================
# Supabase REST & Auth Client for Spiritbound
# Connects to Supabase Auth and PostgREST for cross-platform cloud saves.
# ==============================================================================

const SUPABASE_URL: String = "https://jjfchkdbxwrjvxxiypen.supabase.co"
const SUPABASE_ANON_KEY: String = "sb_publishable_ntvm_D4g8ayE3G5TpY6JFw_IF-2ht2I"
const SESSION_PATH: String = "user://spiritbound_session.json"
const TABLE_PLAYER_SAVES: String = "player_saves"
const TABLE_LEADERBOARDS: String = "leaderboards"
const TABLE_CLIENT_EVENTS: String = "client_events"

static var _current_session: Dictionary = {}
static var _session_loaded: bool = false

# ------------------------------------------------------------------------------
# Session Storage & Token Management
# ------------------------------------------------------------------------------

static func load_session() -> Dictionary:
	if _session_loaded and not _current_session.is_empty():
		return _current_session
	_session_loaded = true
	if not FileAccess.file_exists(SESSION_PATH):
		_current_session = {}
		return _current_session
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_current_session = parsed
	else:
		_current_session = {}
	return _current_session

static func save_session(session: Dictionary) -> void:
	_current_session = session
	_session_loaded = true
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session, "  "))

static func clear_session() -> void:
	_current_session = {}
	_session_loaded = true
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)

static func is_authenticated() -> bool:
	var sess := load_session()
	var token := str(sess.get("access_token", ""))
	return not token.is_empty()

static func get_access_token() -> String:
	return str(load_session().get("access_token", ""))

static func get_refresh_token() -> String:
	return str(load_session().get("refresh_token", ""))

static func get_user_id() -> String:
	var sess := load_session()
	var user: Dictionary = sess.get("user", {})
	if user.has("id"):
		return str(user["id"])
	return str(sess.get("user_id", ""))

static func get_email() -> String:
	var sess := load_session()
	var user: Dictionary = sess.get("user", {})
	if user.has("email"):
		return str(user["email"])
	return str(sess.get("email", ""))

static func get_display_name() -> String:
	var sess := load_session()
	var user: Dictionary = sess.get("user", {})
	var meta: Dictionary = user.get("user_metadata", {})
	if meta.has("display_name") and not str(meta["display_name"]).is_empty():
		return str(meta["display_name"])
	var email_str := get_email()
	if not email_str.is_empty():
		return email_str.split("@")[0]
	return "驭灵者"

# ------------------------------------------------------------------------------
# Internal HTTP Dispatcher
# ------------------------------------------------------------------------------

static func _http_request(url: String, method: int, extra_headers: PackedStringArray = PackedStringArray(), body_json: Variant = null, node: Node = null) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "code": 0, "error": "Engine SceneTree unavailable", "data": null}

	var http := HTTPRequest.new()
	http.timeout = 10.0
	var parent: Node = node if (node != null and is_instance_valid(node) and node.is_inside_tree()) else tree.root
	parent.add_child(http)

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	])
	for h in extra_headers:
		headers.append(h)

	var body_payload := ""
	if body_json != null:
		if body_json is String:
			body_payload = body_json
		else:
			body_payload = JSON.stringify(body_json)

	var req_err := http.request(url, headers, method, body_payload)
	if req_err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "error": "HTTPRequest start failed: %d" % req_err, "data": null}

	var result: Array = await http.request_completed
	http.queue_free()

	var req_result: int = result[0]
	var code: int = result[1]
	var resp_body_raw: PackedByteArray = result[3]
	var resp_text: String = resp_body_raw.get_string_from_utf8()

	if req_result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "error": "Network error code: %d" % req_result, "data": null, "raw": resp_text}

	var data = null
	if not resp_text.is_empty():
		data = JSON.parse_string(resp_text)

	var is_ok := (code >= 200 and code < 300)
	var err_msg := ""
	if not is_ok:
		if data is Dictionary:
			err_msg = str(data.get("msg", data.get("message", data.get("error_description", data.get("error", "HTTP %d" % code)))))
		else:
			err_msg = "HTTP %d" % code

	return {
		"ok": is_ok,
		"code": code,
		"data": data,
		"error": err_msg,
		"raw": resp_text
	}

# ------------------------------------------------------------------------------
# Auth Endpoints
# ------------------------------------------------------------------------------

static func sign_up(email: String, password: String, display_name: String = "", node: Node = null) -> Dictionary:
	var url := SUPABASE_URL + "/auth/v1/signup"
	var body := {
		"email": email.strip_edges(),
		"password": password,
		"data": {
			"display_name": display_name.strip_edges()
		}
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, PackedStringArray(), body, node)
	if res.get("ok", false):
		var d: Dictionary = res.get("data", {})
		if d.has("access_token"):
			var sess := _extract_session(d, "email")
			save_session(sess)
			return {"ok": true, "session": sess, "need_confirm": false, "error": ""}
		else:
			# Email confirmation is required by Supabase project
			return {"ok": true, "session": {}, "need_confirm": true, "error": ""}
	return {"ok": false, "session": {}, "need_confirm": false, "error": str(res.get("error", "Sign up failed"))}

static func sign_in(email: String, password: String, node: Node = null) -> Dictionary:
	var url := SUPABASE_URL + "/auth/v1/token?grant_type=password"
	var body := {
		"email": email.strip_edges(),
		"password": password
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, PackedStringArray(), body, node)
	if res.get("ok", false):
		var d: Dictionary = res.get("data", {})
		if d.has("access_token"):
			var sess := _extract_session(d, "email")
			save_session(sess)
			return {"ok": true, "session": sess, "error": ""}
	return {"ok": false, "session": {}, "error": str(res.get("error", "Invalid login credentials"))}

static func sign_in_with_id_token(provider: String, id_token: String, nonce: String = "", node: Node = null) -> Dictionary:
	var url := SUPABASE_URL + "/auth/v1/token?grant_type=id_token"
	var body := {
		"provider": provider,
		"id_token": id_token
	}
	if not nonce.is_empty():
		body["nonce"] = nonce
	var res = await _http_request(url, HTTPClient.METHOD_POST, PackedStringArray(), body, node)
	if res.get("ok", false):
		var d: Dictionary = res.get("data", {})
		if d.has("access_token"):
			var sess := _extract_session(d, provider)
			save_session(sess)
			return {"ok": true, "session": sess, "error": ""}
	return {"ok": false, "session": {}, "error": str(res.get("error", "Third-party login failed"))}

static func refresh_session(node: Node = null) -> Dictionary:
	var r_token := get_refresh_token()
	if r_token.is_empty():
		return {"ok": false, "error": "No refresh token available"}
	var url := SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var body := {
		"refresh_token": r_token
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, PackedStringArray(), body, node)
	if res.get("ok", false):
		var d: Dictionary = res.get("data", {})
		if d.has("access_token"):
			var old_sess := load_session()
			var prov := str(old_sess.get("provider", "supabase"))
			var sess := _extract_session(d, prov)
			save_session(sess)
			return {"ok": true, "session": sess, "error": ""}
	return {"ok": false, "error": str(res.get("error", "Session refresh failed"))}

static func get_device_credentials() -> Dictionary:
	var dev_uuid := OS.get_unique_id().strip_edges()
	if dev_uuid.is_empty():
		var sess := load_session()
		if sess.has("device_seed") and not str(sess["device_seed"]).is_empty():
			dev_uuid = str(sess["device_seed"])
		else:
			dev_uuid = "%08x%08x" % [int(Time.get_unix_time_from_system()), randi()]
			sess["device_seed"] = dev_uuid
			save_session(sess)
	var safe_id := dev_uuid.sha256_text().substr(0, 20)
	var email := "device_%s@guest.spiritbound.game" % safe_id
	var password := "DevPass_%s_SpBound" % safe_id
	return {
		"email": email,
		"password": password,
		"device_id": dev_uuid,
		"display_name": "驭灵仙友_%s" % safe_id.substr(0, 6)
	}

static func sign_in_with_device(node: Node = null) -> Dictionary:
	var creds := get_device_credentials()
	var res := await sign_in(creds.email, creds.password, node)
	if res.get("ok", false):
		return res
	var up_res := await sign_up(creds.email, creds.password, creds.display_name, node)
	return up_res

static func sign_in_anonymously(node: Node = null) -> Dictionary:
	var dev_uuid := OS.get_unique_id().strip_edges()
	if dev_uuid.is_empty():
		dev_uuid = "%08x%08x" % [int(Time.get_unix_time_from_system()), randi()]
	var url := SUPABASE_URL + "/auth/v1/signup"
	var body := {
		"data": {
			"anonymous": true,
			"device_id": dev_uuid
		}
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, PackedStringArray(), body, node)
	if res.get("ok", false):
		var d: Dictionary = res.get("data", {})
		if d.has("access_token"):
			var sess := _extract_session(d, "device")
			save_session(sess)
			return {"ok": true, "session": sess, "error": ""}
	return {"ok": false, "session": {}, "error": str(res.get("error", "Anonymous login failed"))}

static func reset_password(email: String, node: Node = null) -> Dictionary:
	var url := SUPABASE_URL + "/auth/v1/recover"
	var body := {
		"email": email.strip_edges()
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, PackedStringArray(), body, node)
	return {"ok": res.get("ok", false), "error": str(res.get("error", ""))}

static func sign_out_client(node: Node = null) -> void:
	var token := get_access_token()
	clear_session()
	if not token.is_empty():
		var url := SUPABASE_URL + "/auth/v1/logout"
		var headers := PackedStringArray(["Authorization: Bearer " + token])
		_http_request(url, HTTPClient.METHOD_POST, headers, null, node)

static func _extract_session(d: Dictionary, provider: String) -> Dictionary:
	var user_dict: Dictionary = d.get("user", {})
	return {
		"access_token": str(d.get("access_token", "")),
		"refresh_token": str(d.get("refresh_token", "")),
		"expires_in": int(d.get("expires_in", 3600)),
		"expires_at": int(d.get("expires_at", int(Time.get_unix_time_from_system()) + 3600)),
		"provider": provider,
		"user": user_dict,
		"user_id": str(user_dict.get("id", "")),
		"email": str(user_dict.get("email", ""))
	}

# ------------------------------------------------------------------------------
# Cloud Save Synchronization (PostgREST /player_saves)
# ------------------------------------------------------------------------------

static func fetch_player_save(node: Node = null) -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "error": "Not authenticated", "save": {}}
	var uid := get_user_id()
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_PLAYER_SAVES + "?user_id=eq." + uid + "&select=*"
	var headers := PackedStringArray(["Authorization: Bearer " + get_access_token()])
	var res = await _http_request(url, HTTPClient.METHOD_GET, headers, null, node)

	# Auto-refresh token if expired (HTTP 401)
	if int(res.get("code", 0)) == 401:
		var ref = await refresh_session(node)
		if ref.get("ok", false):
			headers = PackedStringArray(["Authorization: Bearer " + get_access_token()])
			res = await _http_request(url, HTTPClient.METHOD_GET, headers, null, node)

	if res.get("ok", false):
		var data = res.get("data")
		if data is Array and not data.is_empty():
			var row: Dictionary = data[0]
			var save_dict: Dictionary = row.get("save_data", {})
			return {"ok": true, "save": save_dict, "remote_row": row, "error": ""}
		else:
			return {"ok": true, "save": {}, "remote_row": {}, "error": ""}
	return {"ok": false, "save": {}, "error": str(res.get("error", "Failed to fetch cloud save"))}

static func upload_player_save(save_dict: Dictionary, node: Node = null) -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "error": "Not authenticated"}
	var uid := get_user_id()
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_PLAYER_SAVES + "?on_conflict=user_id"
	var headers := PackedStringArray([
		"Authorization: Bearer " + get_access_token(),
		"Prefer: resolution=merge-duplicates,return=representation"
	])
	var body := {
		"user_id": uid,
		"save_data": save_dict,
		"updated_at": int(Time.get_unix_time_from_system())
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, headers, body, node)

	# Auto-refresh token if expired (HTTP 401)
	if int(res.get("code", 0)) == 401:
		var ref = await refresh_session(node)
		if ref.get("ok", false):
			headers = PackedStringArray([
				"Authorization: Bearer " + get_access_token(),
				"Prefer: resolution=merge-duplicates,return=representation"
			])
			res = await _http_request(url, HTTPClient.METHOD_POST, headers, body, node)

	if res.get("ok", false):
		return {"ok": true, "error": ""}
	return {"ok": false, "error": str(res.get("error", "Failed to upload cloud save"))}

# Account deletion (Docs/LAUNCH_READINESS.md Section 1): removes this user's own rows from
# both cloud tables. Must be called BEFORE sign_out_client()/clear_session() — it needs the
# still-valid access token so the request is scoped to "delete my own row" by the user's own
# auth, the same way fetch_player_save()/upload_player_save() already work, rather than needing
# any elevated key. Deleting the underlying auth.users record itself needs a privileged
# service-role call from a trusted server context and is deliberately NOT done here — see this
# function's own call site in game.gd for why that boundary matters.
static func delete_player_save(node: Node = null) -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "error": "Not authenticated"}
	var uid := get_user_id()
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_PLAYER_SAVES + "?user_id=eq." + uid
	var headers := PackedStringArray(["Authorization: Bearer " + get_access_token()])
	var res = await _http_request(url, HTTPClient.METHOD_DELETE, headers, null, node)
	if int(res.get("code", 0)) == 401:
		var ref = await refresh_session(node)
		if ref.get("ok", false):
			headers = PackedStringArray(["Authorization: Bearer " + get_access_token()])
			res = await _http_request(url, HTTPClient.METHOD_DELETE, headers, null, node)
	if res.get("ok", false):
		return {"ok": true, "error": ""}
	return {"ok": false, "error": str(res.get("error", "Failed to delete cloud save"))}

# submit_score() inserts a new row per submission (no on_conflict upsert), so a single account
# can have accumulated many rows across categories/attempts over time — this deletes all of
# them in one request via the same user_id filter, not just the most recent one.
static func delete_leaderboard_entries(node: Node = null) -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "error": "Not authenticated"}
	var uid := get_user_id()
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_LEADERBOARDS + "?user_id=eq." + uid
	var headers := PackedStringArray(["Authorization: Bearer " + get_access_token()])
	var res = await _http_request(url, HTTPClient.METHOD_DELETE, headers, null, node)
	if int(res.get("code", 0)) == 401:
		var ref = await refresh_session(node)
		if ref.get("ok", false):
			headers = PackedStringArray(["Authorization: Bearer " + get_access_token()])
			res = await _http_request(url, HTTPClient.METHOD_DELETE, headers, null, node)
	if res.get("ok", false):
		return {"ok": true, "error": ""}
	return {"ok": false, "error": str(res.get("error", "Failed to delete leaderboard entries"))}

# ------------------------------------------------------------------------------
# Client events (Docs/LAUNCH_READINESS.md Section 3)
# ------------------------------------------------------------------------------
# Crash-adjacent errors and a small funnel, both into one insert-only table (see
# Docs/sql/2026_client_events.sql). Fire-and-forget by design: a logging call must never block
# or crash gameplay, so callers may ignore the returned dictionary entirely. The table is
# insert-only under RLS — this never reads events back. user_id is nullable so guest /
# pre-sign-in events still land.
static func post_client_event(kind: String, name: String, detail: Dictionary = {}, node: Node = null) -> Dictionary:
	if name.is_empty():
		return {"ok": false, "error": "Empty event name"}
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_CLIENT_EVENTS
	var token := get_access_token()
	var headers := PackedStringArray(["Prefer: return=minimal"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var uid := get_user_id()
	var body := {
		"user_id": uid if not uid.is_empty() else null,
		"kind": kind,
		"name": name,
		"detail": detail,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"platform": OS.get_name()
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, headers, body, node)
	return {"ok": res.get("ok", false), "error": str(res.get("error", ""))}

static func verify_purchase(product_id: String, receipt: String, transaction_id: String = "", node: Node = null) -> Dictionary:
	# Calls the verify-purchase Edge Function (supabase/functions/verify-purchase/). That function
	# holds the Apple/Google API credentials and is the only writer of public.entitlements - the
	# client only ever sends its own bearer token and the receipt. See PurchaseService for why the
	# client must not decide on its own that a purchase is legitimate.
	# Returns {"ok": bool, "premium": bool, "error": String}: "ok" = the server answered
	# authoritatively; "premium" = that answer was "this account owns the product". An unreachable
	# function is ok:false, i.e. not verified, which unlocks nothing (failing closed on purpose).
	var token := get_access_token()
	var headers := PackedStringArray()
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var body := {
		"product_id": product_id,
		"receipt": receipt,
		"transaction_id": transaction_id,
		"platform": "android" if OS.get_name() == "Android" else "ios"
	}
	var res = await _http_request(SUPABASE_URL + "/functions/v1/verify-purchase", HTTPClient.METHOD_POST, headers, body, node)
	if not res.get("ok", false):
		return {"ok": false, "premium": false, "error": str(res.get("error", "Verify request failed"))}
	var data = res.get("data", null)
	if not (data is Dictionary):
		return {"ok": false, "premium": false, "error": "Malformed verify response"}
	var d: Dictionary = data
	if not bool(d.get("ok", false)):
		return {"ok": false, "premium": false, "error": str(d.get("error", "Verification rejected"))}
	return {"ok": true, "premium": bool(d.get("premium", false)), "error": str(d.get("detail", ""))}

static func delete_auth_user(node: Node = null) -> Dictionary:
	# Calls the delete-account Edge Function (supabase/functions/delete-account/), the only place
	# that ever touches the service-role key - it stays server-side and never ships in the client.
	# Deliberately best-effort: the caller's account-deletion flow still completes locally when
	# this isn't deployed yet or the network is down, which is what Apple 5.1.1(v) requires of the
	# shipped client. Sends only the caller's own bearer token; the function derives the user id
	# from that token, never from this request body.
	var token := get_access_token()
	if token.is_empty():
		return {"ok": false, "error": "Not authenticated"}
	var url := SUPABASE_URL + "/functions/v1/delete-account"
	var headers := PackedStringArray(["Authorization: Bearer " + token])
	var res = await _http_request(url, HTTPClient.METHOD_POST, headers, {}, node)
	return {"ok": res.get("ok", false), "error": str(res.get("error", ""))}

static func sync_save_two_way(local_profile: Dictionary, node: Node = null) -> Dictionary:
	# Returns: {"ok": bool, "action": "none"|"uploaded"|"downloaded", "profile": Dictionary, "error": String}
	if not is_authenticated():
		return {"ok": false, "action": "none", "profile": local_profile, "error": "Not authenticated"}

	var fetch_res = await fetch_player_save(node)
	if not fetch_res.get("ok", false):
		return {"ok": false, "action": "none", "profile": local_profile, "error": str(fetch_res.get("error", "Fetch failed"))}

	var remote_save: Dictionary = fetch_res.get("save", {})
	var remote_row: Dictionary = fetch_res.get("remote_row", {})

	if remote_save.is_empty():
		# No remote save exists yet: upload local save to Supabase
		var up_res = await upload_player_save(local_profile, node)
		if up_res.get("ok", false):
			local_profile.get("account", {})["cloud_synced_at"] = int(Time.get_unix_time_from_system())
			return {"ok": true, "action": "uploaded", "profile": local_profile, "error": ""}
		else:
			return {"ok": false, "action": "none", "profile": local_profile, "error": str(up_res.get("error", "Upload failed"))}

	# Both exist: Compare timestamps
	var local_updated: int = int(local_profile.get("updated_at", 0))
	var remote_updated: int = int(remote_save.get("updated_at", 0))

	if remote_updated > local_updated:
		# Remote is newer: take remote save and preserve account metadata
		if local_profile.has("account") and not remote_save.has("account"):
			remote_save["account"] = local_profile["account"].duplicate(true)
		remote_save.get("account", {})["cloud_synced_at"] = int(Time.get_unix_time_from_system())
		return {"ok": true, "action": "downloaded", "profile": remote_save, "error": ""}
	else:
		# Local is newer or equal: upload local save
		var up_res2 = await upload_player_save(local_profile, node)
		if up_res2.get("ok", false):
			local_profile.get("account", {})["cloud_synced_at"] = int(Time.get_unix_time_from_system())
			return {"ok": true, "action": "uploaded", "profile": local_profile, "error": ""}
		else:
			return {"ok": false, "action": "none", "profile": local_profile, "error": str(up_res2.get("error", "Upload failed"))}

# ------------------------------------------------------------------------------
# Leaderboard Endpoints (PostgREST /leaderboards)
# ------------------------------------------------------------------------------

static func fetch_leaderboard(category: String, limit: int = 50, node: Node = null) -> Dictionary:
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_LEADERBOARDS + "?category=eq." + category + "&order=score.desc,created_at.asc&limit=" + str(limit)
	var token := get_access_token()
	var headers := PackedStringArray()
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var res = await _http_request(url, HTTPClient.METHOD_GET, headers, null, node)

	if res.get("ok", false):
		var data = res.get("data")
		if data is Array and not data.is_empty():
			return {"ok": true, "entries": data, "error": "", "offline": false}

	# Fallback to predefined seed master records if network error or table is empty
	return {"ok": true, "entries": _get_fallback_leaderboard(category), "error": str(res.get("error", "")), "offline": true}

static func submit_score(category: String, score: int, player_name: String, character_id: String, extra: Dictionary = {}, node: Node = null) -> Dictionary:
	var uid := get_user_id()
	if uid.is_empty(): uid = "local_" + str(Time.get_unix_time_from_system())
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_LEADERBOARDS
	var token := get_access_token()
	var headers := PackedStringArray([
		"Prefer: return=representation"
	])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)

	var body := {
		"category": category,
		"score": score,
		"player_name": player_name if not player_name.is_empty() else "驭灵者",
		"character_id": character_id if not character_id.is_empty() else "fox",
		"user_id": uid,
		"extra": extra,
		"created_at": Time.get_datetime_string_from_system(true, true)
	}
	var res = await _http_request(url, HTTPClient.METHOD_POST, headers, body, node)
	return {"ok": res.get("ok", false), "data": res.get("data"), "error": str(res.get("error", ""))}

# Friend-scoped leaderboard view (E3 Part 2): same table and row shape as fetch_leaderboard(),
# just filtered to a specific set of user_ids (a player's own id plus their added friends')
# instead of the global top-N. No new table needed — profile.friends (save_store.gd) is a
# plain local/cloud-synced list of {user_id, name} the player builds by pasting each other's
# account.user_id, and this only ever reads rows that fetch_leaderboard()'s own public listing
# already exposes to anyone. Unlike fetch_leaderboard(), an empty or failed result must NOT
# fall back to the seeded sample data — showing fabricated "friends" would be actively
# misleading, so callers render the real empty state instead (see show_leaderboard()).
static func fetch_leaderboard_for_users(category: String, user_ids: Array, node: Node = null) -> Dictionary:
	if user_ids.is_empty():
		return {"ok": true, "entries": [], "error": "", "offline": false}
	var encoded: Array = []
	for uid in user_ids:
		encoded.append(str(uid).uri_encode())
	var id_list := ",".join(encoded)
	var url := SUPABASE_URL + "/rest/v1/" + TABLE_LEADERBOARDS + "?category=eq." + category + "&user_id=in.(" + id_list + ")&order=score.desc,created_at.asc"
	var token := get_access_token()
	var headers := PackedStringArray()
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var res = await _http_request(url, HTTPClient.METHOD_GET, headers, null, node)
	if res.get("ok", false):
		var data = res.get("data")
		if data is Array:
			return {"ok": true, "entries": data, "error": "", "offline": false}
	return {"ok": false, "entries": [], "error": str(res.get("error", "")), "offline": true}

static func _get_fallback_leaderboard(category: String) -> Array:
	var list: Array = []
	if category == "daily_trial":
		var seeds := [
			["无极剑仙", "sentinel", 3280],
			["幻月灵狐", "fox", 3050],
			["碧落丹圣", "miasma_witch", 2840],
			["扶摇子", "crane", 2690],
			["金乌天尊", "phoenix", 2510],
			["霸刀狂生", "ironclad", 2380],
			["玄都道长", "sentinel", 2220],
			["落霞仙子", "fox", 2090],
			["万劫毒尊", "miasma_witch", 1930],
			["弈秋居士", "crane", 1780],
		]
		for i in seeds.size():
			list.append({
				"player_name": seeds[i][0],
				"character_id": seeds[i][1],
				"score": int(seeds[i][2]),
				"rank": i + 1,
				"category": category
			})
	elif category == "samsara":
		var seeds := [
			["通天教主", "sentinel", 55],
			["九灵元圣", "fox", 54],
			["玄冥鬼母", "miasma_witch", 45],
			["广成子", "crane", 43],
			["哪吒三太子", "phoenix", 41],
			["巨灵神将", "ironclad", 38],
			["赤松子", "sentinel", 35],
			["涂山红红", "fox", 32],
			["千手罗汉", "ironclad", 28],
			["浮屠游仙", "crane", 25],
		]
		for i in seeds.size():
			list.append({
				"player_name": seeds[i][0],
				"character_id": seeds[i][1],
				"score": int(seeds[i][2]),
				"rank": i + 1,
				"category": category
			})
	else: # abyss default
		var seeds := [
			["清虚道尊", "sentinel", 58],
			["九尾天狐", "fox", 52],
			["幽冥蛊仙", "miasma_witch", 47],
			["白鹤真人", "crane", 43],
			["断魂魔尊", "ironclad", 39],
			["紫微星君", "phoenix", 36],
			["太乙剑仙", "sentinel", 32],
			["青丘夜月", "fox", 29],
			["寒渊灵主", "miasma_witch", 25],
			["凌云散人", "crane", 21],
		]
		for i in seeds.size():
			list.append({
				"player_name": seeds[i][0],
				"character_id": seeds[i][1],
				"score": int(seeds[i][2]),
				"rank": i + 1,
				"category": category
			})
	return list
