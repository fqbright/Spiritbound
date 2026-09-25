extends GutTest
# Tests for Authentication & Cloud Save linking:
# Covers Apple Sign-In, Google Sign-In, Email/Supabase auth, session storage,
# native plugin callbacks, error handling, persistent IDs, and UI flows.

var content: SpiritContent
var had_real_save: bool
var real_save_text: String
var had_real_session: bool
var real_session_text: String

func before_all():
	content = SpiritContent.new()
	had_real_save = FileAccess.file_exists(SpiritSave.PATH)
	if had_real_save:
		real_save_text = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()
	had_real_session = FileAccess.file_exists(SupabaseClient.SESSION_PATH)
	if had_real_session:
		real_session_text = FileAccess.open(SupabaseClient.SESSION_PATH, FileAccess.READ).get_as_text()

func after_all():
	if had_real_save:
		FileAccess.open(SpiritSave.PATH, FileAccess.WRITE).store_string(real_save_text)
	else:
		SpiritSave.reset()
	if had_real_session:
		FileAccess.open(SupabaseClient.SESSION_PATH, FileAccess.WRITE).store_string(real_session_text)
		SupabaseClient.load_session()
	else:
		SupabaseClient.clear_session()
	SpiritAuth.simulate_mode = false

func _create_test_game() -> SpiritGame:
	var g := SpiritGame.new()
	g.content = content
	g.lang = "zh-Hans"
	g.profile = SpiritSave.defaults(content)
	return g

func test_is_apple_and_google_available_return_booleans():
	var apple_avail = SpiritAuth.is_apple_available()
	var google_avail = SpiritAuth.is_google_available()
	assert_true(typeof(apple_avail) == TYPE_BOOL, "is_apple_available() returns a boolean")
	assert_true(typeof(google_avail) == TYPE_BOOL, "is_google_available() returns a boolean")

func test_apple_sign_in_simulation_flow_succeeds():
	var game := _create_test_game()
	var callback_result := {"called": false, "ok": false, "provider": ""}
	
	SpiritAuth.simulate_mode = true
	SpiritAuth.sign_in_with_apple(game, func(ok: bool, prov: String):
		callback_result["called"] = true
		callback_result["ok"] = ok
		callback_result["provider"] = prov
	)
	
	assert_true(callback_result["called"], "Apple login callback was invoked without blocking")
	assert_true(callback_result["ok"], "Apple login in simulate mode succeeded")
	assert_eq(callback_result["provider"], "apple", "Apple login returned provider 'apple'")
	
	var account: Dictionary = game.profile.get("account", {})
	assert_eq(account.get("provider"), "apple", "Profile account provider is set to 'apple'")
	assert_true(str(account.get("user_id", "")).begins_with("apple_"), "Profile user_id begins with 'apple_'")
	assert_true(str(account.get("email", "")).ends_with("@privaterelay.appleid.com"), "Profile email ends with Apple private relay domain")
	assert_true(int(account.get("linked_at", 0)) > 0, "Profile linked_at timestamp recorded")
	assert_true(SpiritSave.is_cloud_linked(game.profile), "SpiritSave.is_cloud_linked() recognizes linked Apple account")
	assert_eq(SpiritSave.account_provider(game.profile), "apple", "SpiritSave.account_provider() returns 'apple'")
	
	# Test unmocked production behavior does not fake login when native singleton is missing
	SpiritAuth.simulate_mode = false
	var unmocked_result := {"called": false, "ok": true}
	var game_unmocked := _create_test_game()
	SpiritAuth.sign_in_with_apple(game_unmocked, func(ok: bool, _p: String):
		unmocked_result["called"] = true
		unmocked_result["ok"] = ok
	)
	assert_true(unmocked_result["called"], "Unmocked sign-in returns callback")
	assert_false(unmocked_result["ok"], "Unmocked sign-in does not fake success without native plugin")
	assert_false(SpiritSave.is_cloud_linked(game_unmocked.profile), "Unmocked failed sign-in does not link profile")
	game_unmocked.free()
	
	game.free()

func test_apple_sign_in_persists_identity_across_re_logins():
	var game := _create_test_game()
	SpiritAuth.simulate_mode = true
	
	# First Apple login
	SpiritAuth.sign_in_with_apple(game)
	var first_user_id: String = str(game.profile.account.user_id)
	assert_true(first_user_id.begins_with("apple_"), "First login gets apple user_id")
	
	# Re-calling sign_in_with_apple on the same account retains the same user_id
	SpiritAuth.sign_in_with_apple(game)
	var second_user_id: String = str(game.profile.account.user_id)
	assert_eq(first_user_id, second_user_id, "Subsequent Apple logins preserve the same persistent user ID")
	
	SpiritAuth.simulate_mode = false
	game.free()

func test_google_sign_in_simulation_flow_succeeds():
	var game := _create_test_game()
	var callback_result := {"called": false, "ok": false, "provider": ""}
	
	SpiritAuth.simulate_mode = true
	SpiritAuth.sign_in_with_google(game, func(ok: bool, prov: String):
		callback_result["called"] = true
		callback_result["ok"] = ok
		callback_result["provider"] = prov
	)
	
	assert_true(callback_result["called"], "Google login callback was invoked without blocking")
	assert_true(callback_result["ok"], "Google login in simulate mode succeeded")
	assert_eq(callback_result["provider"], "google", "Google login returned provider 'google'")
	
	var account: Dictionary = game.profile.get("account", {})
	assert_eq(account.get("provider"), "google", "Profile account provider is set to 'google'")
	assert_true(str(account.get("user_id", "")).begins_with("google_"), "Profile user_id begins with 'google_'")
	assert_true(str(account.get("email", "")).ends_with("@gmail.com"), "Profile email ends with @gmail.com")
	assert_true(int(account.get("linked_at", 0)) > 0, "Profile linked_at timestamp recorded")
	assert_true(SpiritSave.is_cloud_linked(game.profile), "SpiritSave.is_cloud_linked() recognizes linked Google account")
	assert_eq(SpiritSave.account_provider(game.profile), "google", "SpiritSave.account_provider() returns 'google'")
	
	SpiritAuth.simulate_mode = false
	
	game.free()

func test_google_sign_in_persists_identity_across_re_logins():
	var game := _create_test_game()
	SpiritAuth.simulate_mode = true
	
	# First Google login
	SpiritAuth.sign_in_with_google(game)
	var first_user_id: String = str(game.profile.account.user_id)
	assert_true(first_user_id.begins_with("google_"), "First login gets google user_id")
	
	# Re-calling sign_in_with_google on the same account retains the same user_id
	SpiritAuth.sign_in_with_google(game)
	var second_user_id: String = str(game.profile.account.user_id)
	assert_eq(first_user_id, second_user_id, "Subsequent Google logins preserve the same persistent user ID")
	
	SpiritAuth.simulate_mode = false
	game.free()

func test_native_apple_login_callback_success():
	var game := _create_test_game()
	var callback_result := {"called": false, "ok": false, "provider": ""}
	
	var mock_payload := {
		"status": "success",
		"user_id": "001234.apple.uuid",
		"email": "hero@privaterelay.appleid.com",
		"display_name": "灵界剑客",
		"id_token": ""
	}
	
	SpiritAuth._on_native_apple_login(mock_payload, game, func(ok: bool, prov: String):
		callback_result["called"] = true
		callback_result["ok"] = ok
		callback_result["provider"] = prov
	)
	
	assert_true(callback_result["called"], "Native Apple callback invoked on_done")
	assert_true(callback_result["ok"], "Native Apple callback reported success")
	assert_eq(callback_result["provider"], "apple", "Provider reported as 'apple'")
	
	var account: Dictionary = game.profile.get("account", {})
	assert_eq(account.get("provider"), "apple", "Account provider is 'apple'")
	assert_eq(account.get("user_id"), "001234.apple.uuid", "Native user_id properly saved")
	assert_eq(account.get("email"), "hero@privaterelay.appleid.com", "Native email properly saved")
	assert_true(SpiritSave.is_cloud_linked(game.profile), "SpiritSave.is_cloud_linked() returns true")
	
	game.free()

func test_native_apple_login_callback_failure_or_cancellation():
	var game := _create_test_game()
	var callback_result := {"called": false, "ok": true, "provider": ""}
	
	var mock_cancel_payload := {
		"status": "cancelled",
		"error": "User cancelled authorization"
	}
	
	SpiritAuth._on_native_apple_login(mock_cancel_payload, game, func(ok: bool, prov: String):
		callback_result["called"] = true
		callback_result["ok"] = ok
		callback_result["provider"] = prov
	)
	
	assert_true(callback_result["called"], "Native callback invoked on cancel")
	assert_false(callback_result["ok"], "Native callback reported failure on cancel")
	assert_false(SpiritSave.is_cloud_linked(game.profile), "Account remains unlinked on cancelled Apple login")
	assert_eq(SpiritSave.account_provider(game.profile), "guest", "Account provider remains 'guest'")
	
	game.free()

func test_native_google_login_callback_success():
	var game := _create_test_game()
	var callback_result := {"called": false, "ok": false, "provider": ""}
	
	var mock_payload := {
		"status": "success",
		"user_id": "google_10987654321",
		"email": "player@gmail.com",
		"display_name": "天命玄鸟",
		"id_token": ""
	}
	
	SpiritAuth._on_native_google_login(mock_payload, game, func(ok: bool, prov: String):
		callback_result["called"] = true
		callback_result["ok"] = ok
		callback_result["provider"] = prov
	)
	
	assert_true(callback_result["called"], "Native Google callback invoked on_done")
	assert_true(callback_result["ok"], "Native Google callback reported success")
	assert_eq(callback_result["provider"], "google", "Provider reported as 'google'")
	
	var account: Dictionary = game.profile.get("account", {})
	assert_eq(account.get("provider"), "google", "Account provider is 'google'")
	assert_eq(account.get("user_id"), "google_10987654321", "Native user_id properly saved")
	assert_eq(account.get("email"), "player@gmail.com", "Native email properly saved")
	assert_true(SpiritSave.is_cloud_linked(game.profile), "SpiritSave.is_cloud_linked() returns true")
	
	game.free()

func test_native_google_login_callback_failure_or_cancellation():
	var game := _create_test_game()
	var callback_result := {"called": false, "ok": true, "provider": ""}
	
	var mock_cancel_payload := {
		"status": "error",
		"error": "Google sign-in cancelled by user"
	}
	
	SpiritAuth._on_native_google_login(mock_cancel_payload, game, func(ok: bool, prov: String):
		callback_result["called"] = true
		callback_result["ok"] = ok
		callback_result["provider"] = prov
	)
	
	assert_true(callback_result["called"], "Native callback invoked on cancel")
	assert_false(callback_result["ok"], "Native callback reported failure on cancel")
	assert_false(SpiritSave.is_cloud_linked(game.profile), "Account remains unlinked on cancelled Google login")
	assert_eq(SpiritSave.account_provider(game.profile), "guest", "Account provider remains 'guest'")
	
	game.free()

func test_email_login_unconfirmed_fallback_links_and_logs_in():
	var game := _create_test_game()
	
	# Simulate signing in with an unconfirmed email
	var fake_clean_email := "tester_immortal@gmail.com"
	var fake_uid := "email_" + fake_clean_email.replace("@", "_").replace(".", "_")
	
	SpiritSave.link_account(game.profile, "email", fake_uid, fake_clean_email, "tester_immortal")
	assert_true(SpiritSave.is_cloud_linked(game.profile), "Email profile is cloud-linked")
	assert_eq(SpiritSave.account_provider(game.profile), "email", "Account provider is 'email'")
	assert_eq(game.profile.account.email, fake_clean_email, "Profile email recorded")
	assert_eq(game.profile.account.user_id, fake_uid, "Profile user_id recorded")
	
	game.free()

func test_sign_out_unlinks_account_and_clears_session():
	var game := _create_test_game()
	
	# First link account
	SpiritSave.link_account(game.profile, "apple", "apple_test_uid", "test@apple.com", "Tester")
	assert_true(SpiritSave.is_cloud_linked(game.profile), "Pre-condition: account is linked")
	
	# Put mock session into SupabaseClient
	SupabaseClient.save_session({
		"access_token": "mock_token_123",
		"refresh_token": "mock_refresh_456",
		"user": {"id": "apple_test_uid", "email": "test@apple.com"}
	})
	assert_true(SupabaseClient.is_authenticated(), "Pre-condition: Supabase session is active")
	
	# Sign out
	var sign_out_result := {"called": false, "ok": false}
	SpiritAuth.sign_out(game, func(ok): sign_out_result["called"] = true; sign_out_result["ok"] = ok)
	
	assert_true(sign_out_result["called"], "sign_out on_done callback was invoked")
	assert_false(SpiritSave.is_cloud_linked(game.profile), "Profile is no longer cloud-linked")
	assert_eq(SpiritSave.account_provider(game.profile), "guest", "Account provider reset to 'guest'")
	assert_eq(game.profile.account.user_id, "", "Profile user_id cleared")
	assert_eq(game.profile.account.email, "", "Profile email cleared")
	assert_false(SupabaseClient.is_authenticated(), "SupabaseClient session was cleared")
	
	game.free()

func test_supabase_session_storage_and_token_management():
	SupabaseClient.clear_session()
	assert_false(SupabaseClient.is_authenticated(), "is_authenticated is false after clear_session")
	assert_eq(SupabaseClient.get_access_token(), "", "access token is empty")
	
	var fixture_session := {
		"access_token": "jwt.access.token.abc",
		"refresh_token": "jwt.refresh.token.def",
		"expires_in": 7200,
		"user": {
			"id": "usr_998877",
			"email": "cultivator@immortal.io",
			"user_metadata": {
				"display_name": "剑仙"
			}
		}
	}
	
	SupabaseClient.save_session(fixture_session)
	assert_true(SupabaseClient.is_authenticated(), "is_authenticated is true after saving session")
	assert_eq(SupabaseClient.get_access_token(), "jwt.access.token.abc", "get_access_token() matches")
	assert_eq(SupabaseClient.get_refresh_token(), "jwt.refresh.token.def", "get_refresh_token() matches")
	assert_eq(SupabaseClient.get_user_id(), "usr_998877", "get_user_id() matches")
	assert_eq(SupabaseClient.get_email(), "cultivator@immortal.io", "get_email() matches")
	assert_eq(SupabaseClient.get_display_name(), "剑仙", "get_display_name() matches user_metadata")
	
	SupabaseClient.clear_session()
	assert_false(SupabaseClient.is_authenticated(), "is_authenticated is false after second clear")

func test_supabase_extract_session_contract():
	var raw_supabase_auth_response := {
		"access_token": "auth_token_xyz",
		"refresh_token": "refresh_xyz",
		"expires_in": 3600,
		"user": {
			"id": "supabase_uuid_123",
			"email": "user@spiritbound.game"
		}
	}
	
	var extracted := SupabaseClient._extract_session(raw_supabase_auth_response, "apple")
	assert_eq(extracted.get("access_token"), "auth_token_xyz", "Extracted access_token")
	assert_eq(extracted.get("refresh_token"), "refresh_xyz", "Extracted refresh_token")
	assert_eq(extracted.get("provider"), "apple", "Extracted provider")
	assert_eq(extracted.get("user_id"), "supabase_uuid_123", "Extracted user_id")
	assert_eq(extracted.get("email"), "user@spiritbound.game", "Extracted email")
	assert_true(int(extracted.get("expires_at", 0)) > int(Time.get_unix_time_from_system()), "expires_at is in the future")

func test_account_persistence_survives_save_and_reload():
	var test_profile := SpiritSave.defaults(content)
	SpiritSave.link_account(test_profile, "apple", "apple_permanent_id_123", "cloud@icloud.com", "持久化测试")
	SpiritSave.write(test_profile)
	
	var loaded_profile := SpiritSave.load_profile(content)
	assert_true(SpiritSave.is_cloud_linked(loaded_profile), "Loaded profile recognizes linked account")
	assert_eq(SpiritSave.account_provider(loaded_profile), "apple", "Loaded provider is 'apple'")
	assert_eq(loaded_profile.account.user_id, "apple_permanent_id_123", "Loaded user_id matches")
	assert_eq(loaded_profile.account.email, "cloud@icloud.com", "Loaded email matches")
	assert_eq(loaded_profile.account.name, "持久化测试", "Loaded name matches")
	
	# Now link to Google and re-save
	SpiritSave.link_account(loaded_profile, "google", "google_permanent_id_456", "cloud@gmail.com", "谷歌测试")
	SpiritSave.write(loaded_profile)
	
	var loaded_profile2 := SpiritSave.load_profile(content)
	assert_true(SpiritSave.is_cloud_linked(loaded_profile2), "Loaded profile recognizes Google linked account")
	assert_eq(SpiritSave.account_provider(loaded_profile2), "google", "Loaded provider is 'google'")
	assert_eq(loaded_profile2.account.user_id, "google_permanent_id_456", "Loaded Google user_id matches")
	assert_eq(loaded_profile2.account.email, "cloud@gmail.com", "Loaded Google email matches")

func test_auth_localization_keys_exist_in_all_languages():
	var required_auth_keys := [
		"ui.auth_apple_unavailable",
		"ui.auth_google_unavailable",
		"ui.auth_login_success",
		"ui.auth_link_success",
		"ui.auth_email_not_confirmed",
		"ui.auth_wrong_credentials",
		"ui.auth_email_taken",
		"ui.auth_title_account_status",
		"ui.auth_switch_to_login",
		"ui.auth_switch_to_signup"
	]
	
	for key in required_auth_keys:
		var zh_text := content.ui(key, "zh-Hans")
		var en_text := content.ui(key, "en")
		assert_false(zh_text.is_empty(), "Localization key '%s' has non-empty zh-Hans text" % key)
		assert_false(en_text.is_empty(), "Localization key '%s' has non-empty en text" % key)
		assert_false(zh_text == key, "Localization key '%s' is translated in zh-Hans" % key)
		assert_false(en_text == key, "Localization key '%s' is translated in en" % key)
