extends RefCounted
class_name PurchaseService

# ==============================================================================
# Real-money purchase gate for the season pass (Docs/LAUNCH_READINESS.md Section 2)
# ==============================================================================
# WHAT THIS IS: the single verified code path allowed to flip `season_pass.is_premium` to true.
# Before this, every profile was seeded premium for free (game.gd's season_pass default and
# SpiritSave.defaults both said `true`); the default is now `false`, and this file is the only
# thing that can unlock the premium track. Nothing else may write that flag.
#
# WHAT THIS IS NOT: it is not, by itself, a StoreKit/Play Billing integration. Godot ships no
# built-in billing on either platform, so the platform half sits behind `set_provider()` below:
# assign an object exposing `purchase(product_id) -> Dictionary` (and optionally
# `restore() -> Array` / `restore_purchases()`) from whichever Godot 4.7-compatible billing
# plugin you vendor. Until a provider is wired up AND server-side verification succeeds,
# `purchase()` returns an error and grants nothing. There is deliberately no local-only
# "assume the plugin said yes" path: whatever a billing plugin reports on-device is spoofable by
# a jailbroken/rooted device, so the client never decides on its own that a purchase is real.
#
# VERIFICATION: receipts go to the `verify-purchase` Supabase Edge Function
# (supabase/functions/verify-purchase/), which is where the Apple App Store Server API /
# Google Play Developer API credentials live. No secret is ever held in the Godot client — same
# constraint as Section 1's account deletion. If that function isn't deployed or the network is
# down, the result is "not verified", which means no unlock. Failing closed is the point.

const PRODUCT_SEASON_PASS := "spiritbound_season_pass_1"
const RECEIPT_PATH := "user://purchases.json"
# Entitlement flag recorded on the profile alongside season_pass.is_premium, so a future second
# product doesn't have to overload the season-pass dictionary.
const ENTITLEMENT_SEASON_PASS := "season_pass_premium"

# Platform billing hand-off: an object from the vendored billing plugin, or null. The Godot
# client cannot reach StoreKit / Play Billing without one of these; see the file header.
static var _provider: Object = null
# Test seam for the verification step. Real builds leave this empty so every receipt really does
# go to the Edge Function; the headless suites cannot call a real Apple/Google server, so they
# install a stub here instead — the same "assert the call is attempted with the right shape,
# don't assert against a real backend" pattern the rest of this repo's Supabase tests use.
static var _verify_override: Callable = Callable()

static func set_provider(provider: Object) -> void:
	_provider = provider

static func clear_provider() -> void:
	_provider = null

static func provider_available() -> bool:
	return _provider != null

static func set_verify_override(override: Callable) -> void:
	_verify_override = override

static func clear_verify_override() -> void:
	_verify_override = Callable()

# ------------------------------------------------------------------------------
# Entitlement state
# ------------------------------------------------------------------------------

static func has_premium(profile: Dictionary) -> bool:
	var sp: Dictionary = profile.get("season_pass", {})
	return bool(sp.get("is_premium", false))

# The ONLY writer of the premium flag. Callers: a server-verified purchase, and a restore that
# re-derived the same verified answer. Never call this from anywhere else (grep before you do).
static func apply_entitlement(profile: Dictionary, premium: bool) -> void:
	if not (profile.get("season_pass") is Dictionary):
		profile.season_pass = {
			"season_id": 1, "season_name": "灵火初醒", "xp": 0,
			"claimed_free": [], "claimed_premium": [], "is_premium": false,
		}
	var sp: Dictionary = profile.season_pass
	sp.is_premium = premium
	profile.season_pass = sp
	if not (profile.get("entitlements") is Dictionary):
		profile.entitlements = {}
	var ent: Dictionary = profile.entitlements
	ent[ENTITLEMENT_SEASON_PASS] = premium
	profile.entitlements = ent
	SpiritSave.write(profile)

# ------------------------------------------------------------------------------
# Local receipt cache
# ------------------------------------------------------------------------------
# Kept so a reinstall / device switch can re-verify the same receipt instead of needing the
# player to buy again ("Restore Purchases"). It is a cache of what to *ask* about, never a
# grant in itself — an entitlement is only ever applied from a verified answer.

static func save_receipt(product_id: String, transaction_id: String, receipt: String) -> void:
	var all := load_receipts()
	all[product_id] = {"transaction_id": transaction_id, "receipt": receipt, "saved_at": int(Time.get_unix_time_from_system())}
	var f := FileAccess.open(RECEIPT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all))

static func load_receipts() -> Dictionary:
	if not FileAccess.file_exists(RECEIPT_PATH):
		return {}
	var f := FileAccess.open(RECEIPT_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

static func receipt_for(product_id: String) -> Dictionary:
	var all := load_receipts()
	var entry: Dictionary = all.get(product_id, {})
	return entry

static func clear_receipts() -> void:
	if FileAccess.file_exists(RECEIPT_PATH):
		DirAccess.remove_absolute(RECEIPT_PATH)

# ------------------------------------------------------------------------------
# Purchase / restore
# ------------------------------------------------------------------------------

# Returns {"ok": bool, "verified": bool, "error": String}. `ok` means "the flow completed and
# the answer was a verified yes"; every other outcome (no provider, declined sheet, network
# error, server said no) is a plain failure with a reason, and grants nothing.
static func purchase(profile: Dictionary, node: Node = null) -> Dictionary:
	if _provider == null:
		return {"ok": false, "verified": false, "error": "no_provider"}
	var raw = _provider.call("purchase", PRODUCT_SEASON_PASS)
	if not (raw is Dictionary):
		return {"ok": false, "verified": false, "error": "provider_bad_result"}
	var res: Dictionary = raw
	if not bool(res.get("ok", false)):
		return {"ok": false, "verified": false, "error": str(res.get("error", "provider_failed"))}
	var receipt := str(res.get("receipt", ""))
	var txid := str(res.get("transaction_id", ""))
	if receipt.is_empty():
		# No receipt means nothing to verify. A billing plugin that reports success without one
		# is not usable for a gated product; fail closed rather than trusting its word.
		return {"ok": false, "verified": false, "error": "no_receipt"}
	save_receipt(PRODUCT_SEASON_PASS, txid, receipt)
	return await _verify_and_apply(profile, PRODUCT_SEASON_PASS, receipt, txid, node)

# Re-derives premium from account state rather than from local optimism: a stored receipt is
# re-verified, and if there is none (fresh install, new device) the server is asked what this
# account already owns. Apple review requires this flow for any non-consumable purchase.
static func restore(profile: Dictionary, node: Node = null) -> Dictionary:
	# Give the platform plugin its own store-side restore a chance to hand back receipts first —
	# that's how a reinstall recovers the receipt that this device never had cached.
	if _provider != null and _provider.has_method("restore"):
		var owned = _provider.call("restore")
		if owned is Array:
			for item in owned:
				if item is Dictionary:
					var d: Dictionary = item
					if str(d.get("product_id", "")) == PRODUCT_SEASON_PASS:
						save_receipt(PRODUCT_SEASON_PASS, str(d.get("transaction_id", "")), str(d.get("receipt", "")))
	var stored := receipt_for(PRODUCT_SEASON_PASS)
	var res: Dictionary = await verify_receipt(
		PRODUCT_SEASON_PASS, str(stored.get("receipt", "")), str(stored.get("transaction_id", "")), node
	)
	if bool(res.get("ok", false)) and bool(res.get("premium", false)):
		apply_entitlement(profile, true)
		return {"ok": true, "verified": true, "error": ""}
	if bool(res.get("ok", false)):
		# Server answered authoritatively and the answer was "you don't own this" — reflect that:
		# a refund or a revoked transaction must take the entitlement away again.
		apply_entitlement(profile, false)
		return {"ok": false, "verified": true, "error": "not_owned"}
	return {"ok": false, "verified": false, "error": str(res.get("error", "verify_failed"))}

static func _verify_and_apply(profile: Dictionary, product_id: String, receipt: String, txid: String, node: Node) -> Dictionary:
	var res: Dictionary = await verify_receipt(product_id, receipt, txid, node)
	if bool(res.get("ok", false)) and bool(res.get("premium", false)):
		apply_entitlement(profile, true)
		return {"ok": true, "verified": true, "error": ""}
	return {"ok": false, "verified": false, "error": str(res.get("error", "verification_failed"))}

# Returns {"ok": bool, "premium": bool, "error": String}. "ok" = the server gave an authoritative
# answer; "premium" = that answer was "this account owns the season pass".
static func verify_receipt(product_id: String, receipt: String, transaction_id: String, node: Node = null) -> Dictionary:
	if _verify_override.is_valid():
		return _verify_override.call(product_id, receipt, transaction_id)
	return await SupabaseClient.verify_purchase(product_id, receipt, transaction_id, node)
