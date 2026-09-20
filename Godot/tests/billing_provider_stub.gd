extends RefCounted
class_name BillingProviderStub

# Test double for a vendored native billing plugin, used by test_runner.gd.
#
# WHY THIS IS A REAL FILE AND NOT AN INNER CLASS: PurchaseService.bootstrap_provider() finds
# scripted providers through ProjectSettings.get_global_class_list(), which only contains
# scripts declared with a project-wide `class_name` — an inner class (`class Fake::` inside
# another script) is never in that list, so an inner class could not exercise the lookup path
# it is supposed to cover. This exposes the same `purchase()` contract a real adapter would, and
# nothing else: it exists so "vendoring a plugin needs no code edit" is verified rather than
# assumed.
#
# Like the rest of Godot/tests/, this ships inside the exported PCK today (the iOS preset uses
# `export_filter="all_resources"`). It is inert there — nothing in the game references it by
# name, and bootstrap_provider() only adopts it if a real build listed it as a candidate.

var _result: Dictionary = {}

func _init(result: Dictionary = {"ok": true, "receipt": "stub-receipt", "transaction_id": "stub-tx"}) -> void:
	_result = result

func purchase(_product_id: String) -> Dictionary:
	return _result
