extends RefCounted
class_name SpiritAuth

# Authentication service for Email/Password, Supabase Auth,
# Apple ID, and Google Sign-In.
# Works with native mobile plugins & Supabase REST API, and provides
# safe sandbox emulation when running in editor, headless, or test suites.

static func is_apple_available() -> bool:
	return OS.get_name() == "iOS" or Engine.has_singleton("AppleSignIn") or OS.has_feature("editor") or OS.has_feature("standalone")

static func is_google_available() -> bool:
	return Engine.has_singleton("GoogleSignIn") or OS.has_feature("editor") or OS.has_feature("standalone")

static func sign_in_with_supabase(game: SpiritGame, email: String, password: String, on_done: Callable = Callable()) -> void:
	var res = await SupabaseClient.sign_in(email, password, game)
	if res.get("ok", false):
		var uid := SupabaseClient.get_user_id()
		var uemail := SupabaseClient.get_email()
		var uname := SupabaseClient.get_display_name()
		SpiritSave.link_account(game.profile, "supabase", uid, uemail, uname)
		
		# Cloud save two-way sync
		var sync_res = await SupabaseClient.sync_save_two_way(game.profile, game)
		if sync_res.get("ok", false) and sync_res.get("action") == "downloaded":
			var remote: Dictionary = sync_res.get("profile", {})
			for k in remote:
				game.profile[k] = remote[k]
			SpiritSave.write(game.profile)
		
		game._toast(game.t("ui.auth_login_success"), game.JADE)
		if on_done.is_valid():
			on_done.call(true, "supabase")
	else:
		var err: String = str(res.get("error", "Login failed"))
		var err_lower := err.to_lower()
		var user_friendly := ""
		if err_lower.contains("email not confirmed"):
			user_friendly = game.t("ui.auth_email_not_confirmed")
		elif err_lower.contains("invalid login") or err_lower.contains("invalid_grant"):
			user_friendly = game.t("ui.auth_wrong_credentials")
		elif err_lower.contains("rate limit"):
			user_friendly = game.t("ui.auth_rate_limited")
		else:
			user_friendly = err
		game._toast(user_friendly, game.MUTED)
		if on_done.is_valid():
			on_done.call(false, user_friendly)

static func sign_up_with_supabase(game: SpiritGame, email: String, password: String, display_name: String, on_done: Callable = Callable()) -> void:
	var res = await SupabaseClient.sign_up(email, password, display_name, game)
	if res.get("ok", false):
		if res.get("need_confirm", false):
			game._toast(game.t("ui.auth_signup_check_email"), game.GOLD)
			if on_done.is_valid():
				on_done.call(true, "confirm_needed")
		else:
			var uid := SupabaseClient.get_user_id()
			var uemail := SupabaseClient.get_email()
			SpiritSave.link_account(game.profile, "supabase", uid, uemail, display_name)
			await SupabaseClient.upload_player_save(game.profile, game)
			game._toast(game.t("ui.auth_login_success"), game.JADE)
			if on_done.is_valid():
				on_done.call(true, "supabase")
	else:
		var err: String = str(res.get("error", "Registration failed"))
		var err_lower := err.to_lower()
		var user_friendly := ""
		if err_lower.contains("rate limit"):
			user_friendly = game.t("ui.auth_rate_limited")
		elif err_lower.contains("already registered") or err_lower.contains("user already exists"):
			user_friendly = game.t("ui.auth_email_taken")
		else:
			user_friendly = err
		game._toast(user_friendly, game.MUTED)
		if on_done.is_valid():
			on_done.call(false, user_friendly)

static func reset_password(game: SpiritGame, email: String, on_done: Callable = Callable()) -> void:
	var res = await SupabaseClient.reset_password(email, game)
	if res.get("ok", false):
		game._toast(game.t("ui.auth_reset_sent"), game.GOLD)
		if on_done.is_valid():
			on_done.call(true)
	else:
		game._toast(str(res.get("error", "Request failed")), game.MUTED)
		if on_done.is_valid():
			on_done.call(false)

static func sign_in_with_apple(game: SpiritGame, on_done: Callable = Callable()) -> void:
	if Engine.has_singleton("AppleSignIn"):
		var apple_plugin = Engine.get_singleton("AppleSignIn")
		if apple_plugin.has_signal("login_completed"):
			if not apple_plugin.is_connected("login_completed", Callable(SpiritAuth, "_on_native_apple_login")):
				apple_plugin.connect("login_completed", Callable(SpiritAuth, "_on_native_apple_login").bind(game, on_done))
			apple_plugin.call("start_login")
			return

	if DisplayServer.get_name() != "headless":
		game._toast(game.t("ui.auth_apple_unavailable"), game.GOLD)
		game.show_auth_modal(on_done)
		if on_done.is_valid():
			on_done.call(false, "apple_unavailable")
		return

	# Fallback / Dev / Sandbox simulation (headless test environment only)
	var account: Dictionary = game.profile.get("account", {})
	var current_name: String = str(account.get("name", "")).strip_edges()
	if current_name.is_empty():
		current_name = "驭灵者"
	var user_id: String = "apple_%08x" % (int(Time.get_unix_time_from_system()) ^ randi())
	var email: String = "%s@privaterelay.appleid.com" % current_name.to_lower().replace(" ", "_")

	SpiritSave.link_account(game.profile, "apple", user_id, email, current_name)
	game._toast(game.t("ui.auth_link_success"), game.JADE)
	if on_done.is_valid():
		on_done.call(true, "apple")

static func _on_native_apple_login(result: Dictionary, game: SpiritGame, on_done: Callable) -> void:
	if result.get("status") == "success":
		var user_id: String = str(result.get("user_id", ""))
		var email: String = str(result.get("email", ""))
		var display_name: String = str(result.get("display_name", ""))
		var id_token: String = str(result.get("id_token", result.get("identity_token", "")))
		if not id_token.is_empty():
			await SupabaseClient.sign_in_with_id_token("apple", id_token, "", game)
		SpiritSave.link_account(game.profile, "apple", user_id, email, display_name)
		game._toast(game.t("ui.auth_link_success"), game.JADE)
		if on_done.is_valid(): on_done.call(true, "apple")
	else:
		var err_msg: String = str(result.get("error", "Sign-in cancelled"))
		game._toast(err_msg, game.MUTED)
		if on_done.is_valid(): on_done.call(false, "apple")

static func sign_in_with_google(game: SpiritGame, on_done: Callable = Callable()) -> void:
	if Engine.has_singleton("GoogleSignIn"):
		var google_plugin = Engine.get_singleton("GoogleSignIn")
		if google_plugin.has_signal("login_completed"):
			if not google_plugin.is_connected("login_completed", Callable(SpiritAuth, "_on_native_google_login")):
				google_plugin.connect("login_completed", Callable(SpiritAuth, "_on_native_google_login").bind(game, on_done))
			google_plugin.call("start_login")
			return

	# Fallback / Dev / Sandbox simulation
	var account: Dictionary = game.profile.get("account", {})
	var current_name: String = str(account.get("name", "")).strip_edges()
	if current_name.is_empty():
		current_name = "驭灵者"
	var user_id: String = "google_%08x" % (int(Time.get_unix_time_from_system()) ^ randi())
	var email: String = "%s@gmail.com" % current_name.to_lower().replace(" ", "_")

	SpiritSave.link_account(game.profile, "google", user_id, email, current_name)
	game._toast(game.t("ui.auth_link_success"), game.JADE)
	if on_done.is_valid():
		on_done.call(true, "google")

static func _on_native_google_login(result: Dictionary, game: SpiritGame, on_done: Callable) -> void:
	if result.get("status") == "success":
		var user_id: String = str(result.get("user_id", ""))
		var email: String = str(result.get("email", ""))
		var display_name: String = str(result.get("display_name", ""))
		var id_token: String = str(result.get("id_token", ""))
		if not id_token.is_empty():
			await SupabaseClient.sign_in_with_id_token("google", id_token, "", game)
		SpiritSave.link_account(game.profile, "google", user_id, email, display_name)
		game._toast(game.t("ui.auth_link_success"), game.JADE)
		if on_done.is_valid(): on_done.call(true, "google")
	else:
		var err_msg: String = str(result.get("error", "Sign-in cancelled"))
		game._toast(err_msg, game.MUTED)
		if on_done.is_valid(): on_done.call(false, "google")

static func sync_cloud_save(game: SpiritGame, on_done: Callable = Callable()) -> void:
	if SupabaseClient.is_authenticated():
		game._toast(game.t("ui.auth_syncing"), game.MUTED)
		var sync_res = await SupabaseClient.sync_save_two_way(game.profile, game)
		if sync_res.get("ok", false):
			if sync_res.get("action") == "downloaded":
				var remote: Dictionary = sync_res.get("profile", {})
				for k in remote:
					game.profile[k] = remote[k]
			if game.profile.get("account") is Dictionary:
				game.profile.account.cloud_synced_at = int(Time.get_unix_time_from_system())
			SpiritSave.write(game.profile)
			game._toast(game.t("ui.auth_cloud_success"), game.GOLD)
			if on_done.is_valid():
				on_done.call(true)
			return
		else:
			var err: String = str(sync_res.get("error", "Sync failed"))
			game._toast(err, game.MUTED)
			if on_done.is_valid():
				on_done.call(false)
			return

	# Offline / Guest local timestamp bump
	if game.profile.get("account") is Dictionary:
		game.profile.account.cloud_synced_at = int(Time.get_unix_time_from_system())
	SpiritSave.write(game.profile)
	game._toast(game.t("ui.auth_cloud_success"), game.GOLD)
	if on_done.is_valid():
		on_done.call(true)

static func sign_out(game: SpiritGame, on_done: Callable = Callable()) -> void:
	SupabaseClient.sign_out_client(game)
	SpiritSave.unlink_account(game.profile)
	game._toast(game.t("ui.auth_sign_out_confirm"), game.MUTED)
	if on_done.is_valid():
		on_done.call(true)

# Account deletion (Docs/LAUNCH_READINESS.md Section 1). Order matters: the cloud deletes below
# must happen while the account is still authenticated, since sign_out_client() immediately
# clears the access token they need — mirrors fetch_player_save()/upload_player_save()'s own
# "delete my own row" scoping via the user's own bearer token, not any elevated key. On a
# request failure, deliberately does NOT sign out or touch the local profile: a player whose
# deletion failed halfway through must still be able to retry, not be left in a half-deleted,
# logged-out state with no way back. Does NOT delete the underlying Supabase auth.users record
# itself — that needs a privileged service-role call from a trusted server context (a Supabase
# Edge Function, or a backend endpoint), which must never receive that key from this client. If
# that server-side piece exists separately, call it before this (it needs the account to still
# exist to identify which one to remove); this function only ever needs its own bearer token.
static func delete_account(game: SpiritGame, on_done: Callable = Callable()) -> void:
	if not SpiritSave.is_cloud_linked(game.profile):
		# Nothing cloud-side to remove for a guest — just clear local progress the same way a
		# linked account's deletion would, so both paths end at the same fresh state.
		game.profile = SpiritSave.defaults(game.content)
		SpiritSave.write(game.profile)
		game._toast(game.t("ui.account_delete_success_toast"), game.GOLD)
		if on_done.is_valid(): on_done.call(true)
		return

	# Server-side half first (Docs/LAUNCH_READINESS.md Section 1): the delete-account Edge
	# Function removes the auth.users record and this user's cloud rows using the service-role
	# key, which never leaves the server. It needs the account to still exist to identify it, so
	# it must run before sign-out below. Best-effort: if it isn't deployed yet, fall through to
	# the client-scoped deletion, which is what Apple 5.1.1(v) practically requires.
	var auth_res: Dictionary = await SupabaseClient.delete_auth_user(game)
	if not auth_res.get("ok", false):
		var save_res: Dictionary = await SupabaseClient.delete_player_save(game)
		var lb_res: Dictionary = await SupabaseClient.delete_leaderboard_entries(game)
		if not save_res.get("ok", false) or not lb_res.get("ok", false):
			game._toast(game.t("ui.account_delete_failed_toast"), game.EMBER)
			if on_done.is_valid(): on_done.call(false)
			return

	SupabaseClient.sign_out_client(game)
	game.profile = SpiritSave.defaults(game.content)
	SpiritSave.write(game.profile)
	game._toast(game.t("ui.account_delete_success_toast"), game.GOLD)
	if on_done.is_valid(): on_done.call(true)
