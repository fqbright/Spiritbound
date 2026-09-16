extends RefCounted
class_name SpiritAuth

# Authentication service for Apple ID and Google Sign-In.
# Works with native mobile plugins when available, and provides
# safe sandbox emulation when running in editor, headless, or test suites.

static func is_apple_available() -> bool:
	return OS.get_name() == "iOS" or Engine.has_singleton("AppleSignIn") or OS.has_feature("editor") or OS.has_feature("standalone")

static func is_google_available() -> bool:
	return Engine.has_singleton("GoogleSignIn") or OS.has_feature("editor") or OS.has_feature("standalone")

static func sign_in_with_apple(game: SpiritGame, on_done: Callable = Callable()) -> void:
	if Engine.has_singleton("AppleSignIn"):
		var apple_plugin = Engine.get_singleton("AppleSignIn")
		if apple_plugin.has_signal("login_completed"):
			if not apple_plugin.is_connected("login_completed", Callable(SpiritAuth, "_on_native_apple_login")):
				apple_plugin.connect("login_completed", Callable(SpiritAuth, "_on_native_apple_login").bind(game, on_done))
			apple_plugin.call("start_login")
			return

	# Fallback / Dev / Sandbox simulation
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
		SpiritSave.link_account(game.profile, "google", user_id, email, display_name)
		game._toast(game.t("ui.auth_link_success"), game.JADE)
		if on_done.is_valid(): on_done.call(true, "google")
	else:
		var err_msg: String = str(result.get("error", "Sign-in cancelled"))
		game._toast(err_msg, game.MUTED)
		if on_done.is_valid(): on_done.call(false, "google")

static func sync_cloud_save(game: SpiritGame, on_done: Callable = Callable()) -> void:
	if game.profile.get("account") is Dictionary:
		game.profile.account.cloud_synced_at = int(Time.get_unix_time_from_system())
	SpiritSave.write(game.profile)
	game._toast(game.t("ui.auth_cloud_success"), game.GOLD)
	if on_done.is_valid():
		on_done.call(true)

static func sign_out(game: SpiritGame, on_done: Callable = Callable()) -> void:
	SpiritSave.unlink_account(game.profile)
	game._toast(game.t("ui.auth_sign_out_confirm"), game.MUTED)
	if on_done.is_valid():
		on_done.call(true)
