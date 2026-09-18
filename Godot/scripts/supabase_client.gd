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
		"updated_at": Time.get_datetime_string_from_system(true, true)
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
