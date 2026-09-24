extends RefCounted
class_name ShopDeckScreen

# Composition, not inheritance — see MapScreen's header comment (game_map_screen.gd) for
# why. `g` is the live SpiritGame instance; every reference to shared state or another
# screen's function goes through it.
var g: SpiritGame

func _init(game: SpiritGame) -> void:
	g = game

func show_deck_purge(return_callback: Callable, cost := 0, on_done := Callable()) -> void:
	g._clear(); g._play_music(false)
	g._back_action = return_callback
	var page := g._create_page(12)

	var sub: String = g.t("ui.purge_sub") + (" · " + g.tf("ui.shop_gold", cost) if cost > 0 else "")
	var header := g._header(g.t("ui.purge_title"), sub)
	var back_btn := g._button("←", return_callback, Color("17363e"), Vector2(36, 34))
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back_btn)
	page.add_child(header)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var seen_ids: Array[String] = []
	for card_id in g.profile.deck:
		if card_id in seen_ids: continue
		seen_ids.append(card_id)
		var card: Dictionary = g.content.card(card_id)
		if card.is_empty(): continue
		var count: int = g.profile.deck.count(card_id)

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(340, 56)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := g._card_color(card)
		row.add_theme_stylebox_override("panel", g._panel(Color("10242b"), 10, accent))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var badge := _cost_badge(int(card.cost), accent)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(badge)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(texts)

		var name_lbl := g._label("%s  ×%d" % [g.content.text(card.nameKey, g.lang), count], 13, g.TEXT)
		texts.add_child(name_lbl)
		var kind_lbl := g._label("%s · %s" % [g.t("kind.%s" % card.get("kind", "Skill")), g.t("rarity.%s" % card.get("rarity", "Common"))], 10, g.GOLD)
		texts.add_child(kind_lbl)

		var purge_btn := g._button(g.t("ui.purge_confirm"), func():
			if cost > 0 and int(g.profile.gold) < cost:
				g._toast(g.t("ui.shop_no_gold"))
				return
			if cost > 0: g.profile.gold -= cost
			var replacement_id := "foxfire" if card.id == "strike" else ("mirrorWard" if card.id == "ward" else "wildSpark")
			var idx: int = g.profile.deck.find(card.id)
			if idx >= 0: g.profile.deck[idx] = replacement_id
			if int(g.profile.collection.get(card.id, 0)) > 0:
				g.profile.collection[card.id] = maxi(0, int(g.profile.collection[card.id]) - 1)
			g.profile.collection[replacement_id] = int(g.profile.collection.get(replacement_id, 0)) + 1
			SpiritSave.write(g.profile)
			g._haptic("heavy")
			g._toast(g.tf("ui.purged_toast", [g.content.text(card.nameKey, g.lang), g.content.text(g.content.card(replacement_id).nameKey, g.lang)]), g.JADE)
			if on_done.is_valid(): on_done.call()
			else: return_callback.call()
		, g.EMBER, Vector2(88, 38))
		purge_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(purge_btn)

		list.add_child(row)

func show_deck_upgrade(return_callback: Callable, on_done := Callable()) -> void:
	g._clear(); g._play_music(false)
	g._back_action = return_callback
	var page := g._create_page(12)

	var header := g._header(g.t("ui.upgrade_title"), g.t("ui.upgrade_sub"))
	var back_btn := g._button("←", return_callback, Color("17363e"), Vector2(36, 34))
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back_btn)
	page.add_child(header)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var seen_ids: Array[String] = []
	for card_id in g.profile.deck:
		if card_id in seen_ids: continue
		seen_ids.append(card_id)
		var card: Dictionary = g.content.card(card_id)
		if card.is_empty(): continue
		var up_lvl: int = int(g.profile.upgrades.get(card_id, 0))
		var maxed: bool = up_lvl >= SpiritContent.MAX_CARD_UPGRADE

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(340, 56)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := g._card_color(card)
		var row_accent := accent if up_lvl == 0 else (g.EMBER if maxed else g.GOLD)
		row.add_theme_stylebox_override("panel", g._panel(Color("10242b"), 10, row_accent))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var badge := _cost_badge(int(card.cost), accent)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(badge)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(texts)

		var card_name: String = g.content.text(card.nameKey, g.lang)
		var name_lbl := g._label("%s%s" % [card_name, " +%d" % up_lvl if up_lvl > 0 else ""], 13, g.TEXT)
		texts.add_child(name_lbl)
		var kind_lbl := g._label("%s · %s" % [g.t("kind.%s" % card.get("kind", "Skill")), g.t("rarity.%s" % card.get("rarity", "Common"))], 10, g.GOLD)
		texts.add_child(kind_lbl)

		if not maxed:
			var next_lvl := up_lvl + 1
			var btn_label := "+1" if up_lvl == 0 else g.t("ui.awaken_btn")
			var btn_color := g.GOLD if up_lvl == 0 else g.EMBER
			var up_btn := g._button(btn_label, func():
				g.profile.upgrades[card_id] = next_lvl
				SpiritSave.write(g.profile)
				g._haptic("heavy")
				if next_lvl >= SpiritContent.MAX_CARD_UPGRADE: g._toast(g.tf("ui.awakened_toast_fmt", [card_name]), g.EMBER)
				else: g._toast(g.tf("ui.upgraded_toast", [card_name, card_name]), g.GOLD)
				if on_done.is_valid(): on_done.call()
				else: return_callback.call()
			, btn_color, Vector2(56, 38))
			up_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(up_btn)
		else:
			var done_lbl := g._label(g.t("ui.awakened_label"), 11, g.JADE, HORIZONTAL_ALIGNMENT_CENTER)
			done_lbl.custom_minimum_size = Vector2(56, 38)
			done_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hbox.add_child(done_lbl)

		list.add_child(row)

const SHOP_STOCK_COUNT := 10

# Stock and the day's sale slot are derived from the day number rather than stored, so
# they need no save-file field and can't drift out of sync with the daily quest reset.
func _shop_period() -> Dictionary:
	var day: int = g._current_day()
	return g.content.roll_shop_stock(day, SHOP_STOCK_COUNT)

func _shop_reset_at() -> int:
	var day: int = g._current_day()
	return (day + 1) * g.DAY_SECONDS

# Escalating cost is the direct fix for "just buy the same card forever": each copy already
# owned raises the price of the next one, the same shape as Slay the Spire's card-removal
# cost climbing with each use, rather than a flat price with no friction on repeat buys.
func _shop_price(card: Dictionary, owned: int) -> int:
	var base := 90 if card.rarity == "Rare" else 60 if card.rarity == "Uncommon" else 40
	return int(round(float(base) * (1.0 + float(owned) * 0.35) / 5.0)) * 5

# The shop's "◆X / ✧Y" prices let a purchase fall back to Spirit Jade when gold runs short. That
# fallback used to live inline in six different buy handlers, each re-deciding it slightly
# differently; it lives here once so the confirm dialog can name the currency that will actually
# be charged *before* the player commits, instead of the player finding out from the toast.
func _resolve_payment(gold_cost: int, jade_cost: int) -> Dictionary:
	if gold_cost > 0 and int(g.profile.gold) >= gold_cost:
		return {"kind": "gold", "amount": gold_cost}
	if jade_cost > 0 and int(g.profile.get("spirit_jade", 0)) >= jade_cost:
		return {"kind": "jade", "amount": jade_cost}
	return {"kind": "", "amount": 0}

func _can_pay(gold_cost: int, jade_cost: int) -> bool:
	return str(_resolve_payment(gold_cost, jade_cost).kind) != ""

func _spend_payment(gold_cost: int, jade_cost: int) -> bool:
	var payment := _resolve_payment(gold_cost, jade_cost)
	match str(payment.kind):
		"gold": g.profile.gold = int(g.profile.gold) - int(payment.amount)
		"jade": g.profile.spirit_jade = int(g.profile.get("spirit_jade", 0)) - int(payment.amount)
		_: return false
	return true

# Reported problem: one tap bought or recycled outright. _bind_touch_guard() only rejects a
# *drag* — a clean tap anywhere on the button fired instantly, and on the 390pt-wide shop the
# price button sits directly under the card art while the recycle button sits beside a card row,
# so a mis-tap spent real currency or destroyed a real copy with nothing to undo it. These are
# infrequent, deliberate actions (unlike a battle card tap, which stays instant and recoverable),
# so an explicit second confirmation costs almost nothing and removes the whole failure mode.
func _confirm_shop_action(node_name: String, title: String, body_lines: Array, accent: Color, on_confirm: Callable) -> void:
	if g.overlay.get_node_or_null(node_name) != null: return

	var close := func():
		var stale: Node = g.overlay.get_node_or_null(node_name)
		if stale != null:
			if stale.get_parent() != null: stale.get_parent().remove_child(stale)
			stale.queue_free()

	var modal := g._modal_dialog(node_name, close)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var vp_w: int = int(g.get_viewport_rect().size.x)
	var panel := PanelContainer.new()
	panel.name = "%sPanel" % node_name
	panel.custom_minimum_size = Vector2(mini(330, vp_w - 24), 0)
	panel.add_theme_stylebox_override("panel", g._panel(Color("0b171c"), 14, accent))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 16)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 14)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	var title_lbl := g._label(title, 16, accent, HORIZONTAL_ALIGNMENT_CENTER)
	title_lbl.name = "%sTitle" % node_name
	col.add_child(title_lbl)

	for entry in body_lines:
		if entry is Control:
			var holder := CenterContainer.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(entry as Control)
			col.add_child(holder)
		else:
			col.add_child(g._label(str(entry), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)

	# Cancel first and widest-on-the-left: the dismissive option is the one the thumb may already
	# be heading for, so a mis-tap inside the dialog errs toward not spending anything.
	var cancel_btn := g._button(g.t("ui.confirm_cancel"), close, Color("1b2a30"), Vector2(110, 40))
	cancel_btn.name = "%sCancelBtn" % node_name
	buttons.add_child(cancel_btn)

	var confirm_btn := g._button(g.t("ui.confirm_ok"), func():
		close.call()
		on_confirm.call()
	, accent.darkened(0.55), Vector2(110, 40))
	confirm_btn.name = "%sConfirmBtn" % node_name
	buttons.add_child(confirm_btn)

# "Will charge: [coin]150". A price shown as "◆150 / ✧15" is ambiguous about which wallet the
# fallback actually takes from, so every confirmation states it outright before committing.
func _pay_line(gold_cost: int, jade_cost: int) -> Control:
	var payment := _resolve_payment(gold_cost, jade_cost)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if str(payment.kind) == "":
		row.add_child(g._label(g.t("ui.shop_no_gold"), 11, Color("ff7373")))
		return row
	var prefix := g._label(g.t("ui.shop_confirm_pay_prefix"), 11, g.MUTED)
	prefix.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prefix)
	row.add_child(g._currency_amount(str(payment.kind), int(payment.amount), 15, g.GOLD, 11))
	return row

# Shared shape for every priced purchase: what you get, what it costs, which wallet pays.
func _confirm_purchase(node_name: String, title: String, detail_lines: Array, gold_cost: int, jade_cost: int, accent: Color, on_confirm: Callable) -> void:
	var lines: Array = detail_lines.duplicate()
	var options: Array = []
	if gold_cost > 0: options.append(["gold", gold_cost])
	if jade_cost > 0: options.append(["jade", jade_cost])
	if options.size() > 1: lines.append(g._currency_costs(options, 16, g.GOLD, 12))
	lines.append(_pay_line(gold_cost, jade_cost))
	_confirm_shop_action(node_name, title, lines, accent, on_confirm)

func _buy_relic(relic: Dictionary, price_gold: int, price_jade: int, display_name: String) -> void:
	if not _spend_payment(price_gold, price_jade):
		g._toast(g.t("ui.shop_no_gold"))
		return
	g.profile.relics.append(relic.id)
	g._mark_discovered("relics", relic.id)
	g._advance_quest("shop_purchase", 1)
	SpiritSave.write(g.profile)
	g._haptic("heavy")
	g._toast(g.tf("ui.boon_acquired_toast", display_name), g.GOLD)
	show_shop()

func _buy_rune(rune: Dictionary, price_gold: int, price_jade: int, display_name: String) -> void:
	if not _spend_payment(price_gold, price_jade):
		g._toast(g.t("ui.shop_no_gold"))
		return
	g.profile.rune_inventory[rune.id] = int(g.profile.rune_inventory.get(rune.id, 0)) + 1
	g._mark_discovered("runes", rune.id)
	g._advance_quest("shop_purchase", 1)
	SpiritSave.write(g.profile)
	g._haptic("tap")
	g._toast(g.tf("ui.boon_acquired_toast", display_name), g.GOLD)
	show_shop()

func _buy_consumable(item: Dictionary, price_gold: int, price_jade: int, display_name: String) -> void:
	if not _spend_payment(price_gold, price_jade):
		g._toast(g.t("ui.shop_no_gold"))
		return
	match str(item.id):
		"elixir_vitality":
			g.profile.health = mini(60, int(g.profile.health) + 25)
			g._toast(g.tf("ui.shop_item_bought", display_name), g.JADE)
			SpiritSave.write(g.profile)
			show_shop()
		"elixir_might":
			if not g.profile.has("combat_consumables"): g.profile.combat_consumables = {"strength":0,"focus":0,"energy":0}
			g.profile.combat_consumables.strength = int(g.profile.combat_consumables.get("strength", 0)) + 2
			g._toast(g.tf("ui.shop_item_bought", display_name), g.EMBER)
			SpiritSave.write(g.profile)
			show_shop()
		"elixir_focus":
			if not g.profile.has("combat_consumables"): g.profile.combat_consumables = {"strength":0,"focus":0,"energy":0}
			g.profile.combat_consumables.energy = int(g.profile.combat_consumables.get("energy", 0)) + 1
			g.profile.combat_consumables.focus = int(g.profile.combat_consumables.get("focus", 0)) + 1
			g._toast(g.tf("ui.shop_item_bought", display_name), g.GOLD)
			SpiritSave.write(g.profile)
			show_shop()
		"dust_ore":
			g.profile.spirit_dust = int(g.profile.get("spirit_dust", 0)) + 35
			g._toast(g.tf("ui.shop_item_bought", display_name), Color("c79bff"))
			SpiritSave.write(g.profile)
			show_shop()
		"upgrade_stone":
			SpiritSave.write(g.profile)
			show_deck_upgrade(show_shop)
	g._advance_quest("shop_purchase", 1)
	g._haptic("tap")

func show_shop() -> void:
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var backdrop := g._background("lantern-marsh-v1.jpg", .18); g.root.add_child(backdrop); g.root.move_child(backdrop, 0)
	var page := g._create_page(8)
	page.add_child(g._header(g.t("ui.shop_title"), g.t("ui.shop_sub"), g.show_map))
	page.add_child(_tab_bar([["curated", g.t("ui.shop_tab_curated")], ["exchange", g.t("ui.shop_tab_exchange")]], g.shop_tab, func(id): g.shop_tab = id; show_shop()))

	if g.shop_tab == "curated":
		g._maybe_show_tutorial("shop_overview")
		_build_shop_curated(page)
	else:
		_build_shop_exchange(page)

func _build_shop_curated(page: VBoxContainer) -> void:
	page.add_child(g._label(g.tf("ui.shop_refresh", g._format_countdown(_shop_reset_at())), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var svc_row := HBoxContainer.new()
	svc_row.custom_minimum_size.y = 56
	svc_row.add_theme_constant_override("separation", 8)
	page.add_child(svc_row)

	var purge_svc := Button.new()
	purge_svc.name = "ShopPurgeBtn"
	purge_svc.custom_minimum_size.y = 56
	purge_svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purge_svc.focus_mode = Control.FOCUS_NONE
	var can_purge: bool = int(g.profile.gold) >= 50
	purge_svc.add_theme_stylebox_override("normal", g._panel(Color("261d36"), 12, Color("c79bff") if can_purge else Color("2a3d42")))
	purge_svc.add_theme_stylebox_override("hover", g._panel(Color("37264f"), 12, Color("c79bff")))
	purge_svc.add_theme_stylebox_override("pressed", g._panel(Color("1c142b"), 12, g.GOLD))
	g._bind_touch_guard(purge_svc, func(): show_deck_purge(show_shop, 50))
	svc_row.add_child(purge_svc)

	var purge_row := HBoxContainer.new()
	purge_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	purge_row.add_theme_constant_override("separation", 8)
	purge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	purge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purge_svc.add_child(purge_row)
	var purge_badge := CenterContainer.new()
	purge_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purge_badge.add_child(g._icon_badge("✦", Color("c79bff"), 32, 16))
	purge_row.add_child(purge_badge)
	var purge_texts := VBoxContainer.new()
	purge_texts.alignment = BoxContainer.ALIGNMENT_CENTER
	purge_texts.add_theme_constant_override("separation", 1)
	purge_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purge_row.add_child(purge_texts)
	purge_texts.add_child(g._label(g.t("ui.shop_purge_service"), 11, g.TEXT))
	purge_texts.add_child(g._currency_amount("gold", 50, 14, g.GOLD, 10))

	var pack_btn := Button.new()
	pack_btn.name = "ShopPackBtn"
	pack_btn.custom_minimum_size.y = 56
	pack_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_btn.focus_mode = Control.FOCUS_NONE
	var pack_cost_gold := 120
	var pack_cost_jade := 12
	var can_pack: bool = int(g.profile.gold) >= pack_cost_gold or int(g.profile.get("spirit_jade", 0)) >= pack_cost_jade
	pack_btn.add_theme_stylebox_override("normal", g._panel(Color("1b2a36"), 12, Color("78e9ff") if can_pack else Color("2a3d42")))
	pack_btn.add_theme_stylebox_override("hover", g._panel(Color("263d4d"), 12, Color("78e9ff")))
	pack_btn.add_theme_stylebox_override("pressed", g._panel(Color("131f28"), 12, g.GOLD))
	g._bind_touch_guard(pack_btn, func():
		_confirm_purchase("ShopConfirmPack", g.t("ui.shop_confirm_pack_title"),
			[g.t("ui.shop_pack_title"), g.t("ui.shop_pack_desc")],
			pack_cost_gold, pack_cost_jade, Color("78e9ff"),
			func(): _buy_booster_pack(pack_cost_gold, pack_cost_jade)))
	svc_row.add_child(pack_btn)

	var pack_row := HBoxContainer.new()
	pack_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pack_row.add_theme_constant_override("separation", 8)
	pack_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pack_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_btn.add_child(pack_row)
	var pack_badge := CenterContainer.new()
	pack_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_badge.add_child(g._icon_badge("🎴", Color("78e9ff"), 32, 16))
	pack_row.add_child(pack_badge)
	var pack_texts := VBoxContainer.new()
	pack_texts.alignment = BoxContainer.ALIGNMENT_CENTER
	pack_texts.add_theme_constant_override("separation", 1)
	pack_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_row.add_child(pack_texts)
	pack_texts.add_child(g._label(g.t("ui.shop_pack_title"), 11, g.TEXT))
	pack_texts.add_child(g._currency_costs([["gold", pack_cost_gold], ["jade", pack_cost_jade]], 14, Color("78e9ff"), 10))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var content_col := VBoxContainer.new()
	content_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_col.add_theme_constant_override("separation", 10)
	scroll.add_child(content_col)

	var stock: Dictionary = _shop_period()

	var has_relic: bool = not stock.get("relic", {}).is_empty()
	var has_rune: bool = not stock.get("rune", {}).is_empty()
	if has_relic or has_rune:
		var offers_col := VBoxContainer.new()
		offers_col.add_theme_constant_override("separation", 6)
		offers_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if has_relic:
			offers_col.add_child(_shop_relic_tile(stock.relic))
		if has_rune:
			offers_col.add_child(_shop_rune_tile(stock.rune))
		content_col.add_child(offers_col)

	content_col.add_child(_shop_specialties_shelf())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content_col.add_child(grid)

	var stock_cards: Array = stock.cards
	for i in stock_cards.size():
		var card: Dictionary = stock_cards[i]
		var owned: int = int(g.profile.collection.get(card.id, 0))
		var price := _shop_price(card, owned)
		var on_sale: bool = i == int(stock.sale_index)
		if on_sale: price = maxi(5, int(round(float(price) * 0.7 / 5.0)) * 5)
		grid.add_child(_shop_card_tile(card, price, on_sale))

func _shop_relic_tile(relic: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 52
	var owned: bool = g.profile.relics.has(relic.id)
	var price_gold := 150
	var price_jade := 15
	var can_afford: bool = _can_pay(price_gold, price_jade)
	panel.add_theme_stylebox_override("panel", g._panel(Color("161f28"), 10, Color(relic.get("color", "ffd700")) if not owned else Color("2a3d42")))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var badge := CenterContainer.new()
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(g._icon_badge(str(relic.get("icon", "✦")), Color(relic.get("color", "ffd700")), 32, 16))
	hbox.add_child(badge)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(texts)
	var r_name: String = relic.get("en", "") if g.lang == "en" else relic.get("zh", "")
	texts.add_child(g._label("%s · %s" % [g.t("ui.shop_relic_slot"), r_name], 11, g.TEXT))
	var r_desc: String = relic.get("detail_en", "") if g.lang == "en" else relic.get("detail", "")
	texts.add_child(g._label(r_desc, 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	if owned:
		var owned_lbl := g._label(g.t("ui.obtained"), 10, g.JADE, HORIZONTAL_ALIGNMENT_CENTER)
		owned_lbl.custom_minimum_size = Vector2(70, 32)
		owned_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(owned_lbl)
	else:
		var buy_btn := g._currency_button([["gold", price_gold], ["jade", price_jade]], func():
			_confirm_purchase("ShopConfirmRelic", g.t("ui.shop_confirm_relic_title"), [r_name, r_desc],
				price_gold, price_jade, Color(relic.get("color", "ffd700")),
				func(): _buy_relic(relic, price_gold, price_jade, r_name))
		, Color("204a44"), Color("78e9ff"), Vector2(84, 34), can_afford)
		buy_btn.name = "ShopRelicBuyBtn"
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(buy_btn)

	return panel

func _shop_rune_tile(rune: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 52
	var price_gold := 80
	var price_jade := 8
	var can_afford: bool = _can_pay(price_gold, price_jade)
	var rune_color := Color(rune.get("color", "78e9ff"))
	panel.add_theme_stylebox_override("panel", g._panel(Color("161f28"), 10, rune_color))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var badge := CenterContainer.new()
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(g._icon_badge(str(rune.get("icon", "»")), rune_color, 32, 16))
	hbox.add_child(badge)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(texts)
	var r_name: String = g.content.rune_name(rune, g.lang)
	var owned_count: int = int(g.profile.rune_inventory.get(rune.id, 0))
	texts.add_child(g._label("%s · %s%s" % [g.t("ui.shop_rune_slot"), r_name, " (×%d)" % owned_count if owned_count > 0 else ""], 11, g.TEXT))
	var r_desc: String = g.content.rune_detail(rune, g.lang)
	texts.add_child(g._label(r_desc, 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var buy_btn := g._currency_button([["gold", price_gold], ["jade", price_jade]], func():
		_confirm_purchase("ShopConfirmRune", g.t("ui.shop_confirm_rune_title"), [r_name, r_desc],
			price_gold, price_jade, rune_color,
			func(): _buy_rune(rune, price_gold, price_jade, r_name))
	, Color("204a44"), Color("78e9ff"), Vector2(84, 34), can_afford)
	buy_btn.name = "ShopRuneBuyBtn"
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(buy_btn)

	return panel

func _shop_specialties_shelf() -> Control:
	var col := VBoxContainer.new()
	col.name = "ShopSpecialtiesShelf"
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hdr := HBoxContainer.new()
	hdr.add_child(g._label(g.t("ui.shop_specialties"), 13, Color("78e9c0")))
	col.add_child(hdr)

	for item in SpiritContent.STORE_CONSUMABLES:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.y = 48
		var item_color: Color = Color(str(item.get("color", "78e9c0")))
		panel.add_theme_stylebox_override("panel", g._panel(Color("132026"), 10, item_color.darkened(0.5)))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		panel.add_child(hbox)

		var badge := CenterContainer.new()
		badge.custom_minimum_size = Vector2(34, 34)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(g._icon_badge(str(item.get("icon", "🧪")), item_color, 30, 15))
		hbox.add_child(badge)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 1)
		hbox.add_child(texts)

		var item_name: String = str(item.get("en" if g.lang == "en" else "zh", ""))
		var item_desc: String = str(item.get("detail_en" if g.lang == "en" else "detail_zh", ""))
		texts.add_child(g._label(item_name, 11, g.TEXT))
		texts.add_child(g._label(item_desc, 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

		var p_gold: int = int(item.get("price_gold", 0))
		var p_jade: int = int(item.get("price_jade", 0))
		var can_buy: bool = _can_pay(p_gold, p_jade)

		var costs: Array = []
		if p_gold > 0: costs.append(["gold", p_gold])
		if p_jade > 0: costs.append(["jade", p_jade])
		if costs.is_empty(): costs.append(["gold", 0])

		var buy_btn := g._currency_button(costs, func():
			_confirm_purchase("ShopConfirmItem_%s" % str(item.id), g.t("ui.shop_confirm_item_title"),
				[item_name, item_desc], p_gold, p_jade, item_color,
				func(): _buy_consumable(item, p_gold, p_jade, item_name))
		, Color("1e4a3d"), item_color, Vector2(84, 34), can_buy)
		buy_btn.name = "ShopItemBuyBtn_%s" % str(item.id)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(buy_btn)

		col.add_child(panel)

	return col

func _buy_booster_pack(cost_gold: int, cost_jade: int) -> void:
	if not _spend_payment(cost_gold, cost_jade):
		g._toast(g.t("ui.shop_no_gold"))
		return

	var pool: Array = g.content.cards.filter(func(c): return c.rarity != "Starter" and c.get("rarity", "") != "Curse")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	pool.shuffle()
	var uncommons_or_better: Array = pool.filter(func(c): return c.rarity != "Common")

	var awarded: Array = []
	if not uncommons_or_better.is_empty():
		awarded.append(uncommons_or_better[0])
		pool.erase(uncommons_or_better[0])
	while awarded.size() < 3 and not pool.is_empty():
		awarded.append(pool.pop_front())

	for card in awarded:
		var c_id: String = card.id
		if int(g.profile.collection.get(c_id, 0)) == 0:
			g._advance_quest("collect_cards", 1)
		g.profile.collection[c_id] = int(g.profile.collection.get(c_id, 0)) + 1

	g._advance_quest("shop_purchase", 1)
	SpiritSave.write(g.profile)
	g._haptic("heavy")
	g._toast(g.t("ui.shop_pack_opened"), g.GOLD)
	show_shop()

func _build_shop_exchange(page: VBoxContainer) -> void:
	g._maybe_show_tutorial("card_exchange")

	var dust_banner := PanelContainer.new()
	dust_banner.custom_minimum_size.y = 50
	dust_banner.add_theme_stylebox_override("panel", g._panel(Color("0f232c"), 12, Color("78e9ff")))
	page.add_child(dust_banner)

	var b_box := HBoxContainer.new()
	b_box.add_theme_constant_override("separation", 10)
	b_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dust_banner.add_child(b_box)

	var dust_icon := g._currency_icon("dust", 26)
	b_box.add_child(dust_icon)

	var d_val := int(g.profile.get("spirit_dust", 0))
	var d_label := g._label("%s: %d" % [g.t("ui.currency_dust"), d_val], 15, Color("78e9ff"))
	d_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b_box.add_child(d_label)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var content_box := VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 14)
	scroll.add_child(content_box)

	# --- Section 1: Recycle (炼化分解) ---
	var recycle_header := VBoxContainer.new()
	recycle_header.add_theme_constant_override("separation", 2)
	recycle_header.add_child(g._label(g.t("ui.shop_recycle_card"), 14, g.GOLD))
	recycle_header.add_child(g._label(g.content.ui("tutorial.card_exchange.desc", g.lang), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	content_box.add_child(recycle_header)

	var recycle_list := VBoxContainer.new()
	recycle_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recycle_list.add_theme_constant_override("separation", 6)
	content_box.add_child(recycle_list)

	var owned_card_ids: Array = g.profile.collection.keys()
	owned_card_ids.sort()

	for card_id in owned_card_ids:
		var count: int = int(g.profile.collection.get(card_id, 0))
		if count <= 0: continue
		var card: Dictionary = g.content.card(card_id)
		if card.is_empty(): continue

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(340, 50)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := g._card_color(card)
		row.add_theme_stylebox_override("panel", g._panel(Color("10242b"), 10, accent))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var badge := _cost_badge(int(card.cost), accent)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(badge)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(texts)

		var card_name: String = g.content.text(card.nameKey, g.lang)
		texts.add_child(g._label("%s  ×%d" % [card_name, count], 12, g.TEXT))
		texts.add_child(g._label("%s · %s" % [g.t("kind.%s" % card.get("kind", "Skill")), g.t("rarity.%s" % card.get("rarity", "Common"))], 9, g.GOLD))

		var is_soulbound: bool = g.content.is_card_soulbound(card_id)
		if is_soulbound:
			var sb_lbl := g._label(g.t("ui.shop_soulbound"), 9, Color("7a8f94"), HORIZONTAL_ALIGNMENT_CENTER)
			sb_lbl.custom_minimum_size = Vector2(90, 34)
			sb_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(sb_lbl)
		else:
			var dust_val := g.content.card_recycle_dust_value(card)
			# Recycle used to fire on the first tap, destroying a real copy irreversibly. Now the
			# dialog names the card, the copy count and the dust before anything is removed.
			var recycle_btn := g._currency_button([["dust", dust_val]], func():
				_confirm_shop_action("ShopConfirmRecycle", g.t("ui.shop_recycle_confirm_title"),
					["%s  ×%d" % [card_name, count],
					g._currency_amount("dust", dust_val, 18, Color("c79bff"), 13),
					g.t("ui.shop_recycle_confirm_body")],
					Color("c79bff"), func():
						g.profile.collection[card_id] = maxi(0, int(g.profile.collection[card_id]) - 1)
						g.profile.spirit_dust = int(g.profile.get("spirit_dust", 0)) + dust_val
						if g.profile.deck.count(card_id) > int(g.profile.collection[card_id]):
							var idx: int = g.profile.deck.find(card_id)
							if idx >= 0:
								g.profile.deck[idx] = "strike"
						SpiritSave.write(g.profile)
						g._haptic("tap")
						g._toast(g.tf("ui.recycle_success_toast", dust_val), g.JADE)
						show_shop())
			, Color("204a44"), Color("78e9ff"), Vector2(96, 34), true, "+")
			recycle_btn.name = "RecycleBtn_%s" % card_id
			recycle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(recycle_btn)

		recycle_list.add_child(row)

	# --- Section 2: Transmute / Craft (凝聚置换) ---
	var craft_header := VBoxContainer.new()
	craft_header.add_theme_constant_override("separation", 2)
	craft_header.add_child(g._label(g.t("ui.shop_craft_card"), 14, Color("78e9ff")))
	craft_header.add_child(g._label(g.t("ui.shop_craft_card") + " - " + g.t("ui.shop_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	content_box.add_child(craft_header)

	var craft_list := VBoxContainer.new()
	craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_list.add_theme_constant_override("separation", 6)
	content_box.add_child(craft_list)

	var craftable_pool: Array = g.content.cards.filter(func(c): return c.rarity != "Starter" and c.get("rarity", "") != "Curse")
	for card in craftable_pool:
		var craft_cost := g.content.card_craft_dust_cost(card)
		var can_craft: bool = int(g.profile.get("spirit_dust", 0)) >= craft_cost

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(340, 52)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := g._card_color(card)
		row.add_theme_stylebox_override("panel", g._panel(Color("10242b"), 10, accent))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var badge := _cost_badge(int(card.cost), accent)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(badge)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(texts)

		var card_name: String = g.content.text(card.nameKey, g.lang)
		var owned_cnt: int = int(g.profile.collection.get(card.id, 0))
		texts.add_child(g._label("%s%s" % [card_name, " (×%d)" % owned_cnt if owned_cnt > 0 else ""], 12, g.TEXT))
		texts.add_child(g._label("%s · %s" % [g.t("kind.%s" % card.get("kind", "Skill")), g.t("rarity.%s" % card.get("rarity", "Common"))], 9, g.GOLD))

		var craft_btn := g._currency_button([["dust", craft_cost]], func():
			_confirm_shop_action("ShopConfirmCraft", g.t("ui.shop_craft_confirm_title"),
				[card_name, g._currency_amount("dust", craft_cost, 18, Color("c79bff"), 13)],
				Color("78e9ff"), func():
					if int(g.profile.get("spirit_dust", 0)) < craft_cost:
						g._toast(g.t("ui.insufficient_dust"))
						return
					g.profile.spirit_dust = int(g.profile.get("spirit_dust", 0)) - craft_cost
					if int(g.profile.collection.get(card.id, 0)) == 0:
						g._advance_quest("collect_cards", 1)
					g.profile.collection[card.id] = int(g.profile.collection.get(card.id, 0)) + 1
					SpiritSave.write(g.profile)
					g._haptic("heavy")
					g._toast(g.tf("ui.transmute_success_toast", card_name), g.GOLD)
					show_shop())
		, Color("1e4b52"), Color("78e9ff"), Vector2(96, 34), can_craft, "-")
		craft_btn.name = "CraftBtn_%s" % card.id
		craft_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(craft_btn)

		craft_list.add_child(row)

func _shop_card_tile(card: Dictionary, price: int, on_sale := false) -> Control:
	var accent := g._card_color(card)
	var can_afford: bool = int(g.profile.gold) >= price
	var owned: int = int(g.profile.collection.get(card.id, 0))

	# The tile is inert; only the price button below buys, so brushing a card cannot spend gold.
	var btn := Panel.new()
	btn.name = "ShopTile_%s" % card.id
	btn.custom_minimum_size = Vector2(176, 232)
	btn.size = btn.custom_minimum_size
	btn.pivot_offset = Vector2(88, 116)
	var border_color: Color = g.GOLD if on_sale else (accent if can_afford else Color("24373d"))
	var tile_style := g._panel(Color("1d1a10") if on_sale else Color("11242a"), 12, border_color)
	if on_sale: tile_style.border_width_left = 2; tile_style.border_width_right = 2; tile_style.border_width_top = 2; tile_style.border_width_bottom = 2
	btn.add_theme_stylebox_override("panel", tile_style)
	btn.clip_contents = true

	# 1. Full-bleed card illustration covering the entire tile
	var art := TextureRect.new()
	art.texture = g._get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._apply_card_foil(art, str(card.get("rarity", "Common")), false)
	btn.add_child(art)

	# 2. Ornate frame around the entire card perimeter
	_add_ornate_frame(btn, btn.custom_minimum_size, border_color, str(card.get("rarity", "Common")))

	# 3. Top elements (Cost badge, Rarity stars, Sale tag)
	var badge := _cost_badge(int(card.cost), accent)
	badge.position = Vector2(8, 8)
	btn.add_child(badge)

	var rarity_row := _rarity_star_row(str(card.rarity), g.GOLD, BoxContainer.ALIGNMENT_END)
	rarity_row.position = Vector2(88, 10)
	rarity_row.size = Vector2(76, 16)
	btn.add_child(rarity_row)

	if on_sale:
		var sale_badge := PanelContainer.new()
		sale_badge.custom_minimum_size = Vector2(40, 16)
		sale_badge.position = Vector2(8, 40)
		sale_badge.add_theme_stylebox_override("panel", g._panel(Color("a83232"), 8, Color("e06060")))
		var sale_lbl := g._label(g.t("ui.shop_sale"), 8, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		sale_badge.add_child(sale_lbl)
		btn.add_child(sale_badge)

	# 4. Carved-out space in the lower portion for card info (smaller to show more card art)
	var info_box := PanelContainer.new()
	info_box.position = Vector2(8, 126)
	info_box.custom_minimum_size = Vector2(160, 98)
	info_box.size = info_box.custom_minimum_size
	var box_style := g._panel(Color(0.04, 0.08, 0.10, 0.48), 8, border_color)
	# Slender border g.overlay margin
	box_style.content_margin_left = 8; box_style.content_margin_right = 8
	box_style.content_margin_top = 2; box_style.content_margin_bottom = 2
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	info_box.add_child(stack)

	var name_lbl := g._label(g.content.text(card.nameKey, g.lang), 11, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 2)
	stack.add_child(name_lbl)

	var kind_lbl := g._label(g._kind_element_line(card), 8, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	kind_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	kind_lbl.add_theme_constant_override("outline_size", 2)
	stack.add_child(kind_lbl)

	var desc := g._label(g._card_description(card), 8, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	desc.add_theme_constant_override("outline_size", 2)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)

	var owned_row := HBoxContainer.new()
	owned_row.alignment = BoxContainer.ALIGNMENT_CENTER
	owned_row.add_theme_constant_override("separation", 4)
	owned_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(owned_row)
	if owned > 0:
		var dots := HBoxContainer.new()
		dots.add_theme_constant_override("separation", 2)
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owned_row.add_child(dots)
		for i in mini(owned, 6):
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(6, 6)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.add_theme_stylebox_override("panel", g._panel(g.JADE, 3))
			dots.add_child(dot)
		if owned > 6: owned_row.add_child(g._label("+%d" % (owned - 6), 8, g.JADE))
	else:
		owned_row.add_child(g._label(g.t("ui.loadout_unobtained"), 9, g.MUTED))

	var price_row := VBoxContainer.new()
	price_row.add_theme_constant_override("separation", 1)
	stack.add_child(price_row)

	var buy := Button.new()
	buy.name = "BuyButton"
	buy.custom_minimum_size.y = 30
	buy.focus_mode = Control.FOCUS_NONE
	# The price used to be welded into this button's own text ("购买 ◆200"). A Label cannot embed
	# a texture, which is exactly why the coin had to be a glyph; the price is now a real
	# TextureRect child laid over the button's right edge, with the word pushed left out of its way.
	buy.text = g.t("ui.shop_buy")
	buy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if g.font_cjk: buy.add_theme_font_override("font", g.font_cjk)
	buy.add_theme_font_size_override("font_size", 12)
	var buy_price_color: Color = Color("0f1d10") if can_afford else Color("c78b7f")
	buy.add_theme_color_override("font_color", buy_price_color)
	buy.add_theme_color_override("font_hover_color", Color("0f1d10"))
	buy.add_theme_color_override("font_disabled_color", buy_price_color)
	var buy_normal := g._panel(g.GOLD if can_afford else Color("3a2723"), 8, g.GOLD if can_afford else Color("6b4038"))
	var buy_hover := g._panel(g.GOLD.lightened(0.15) if can_afford else Color("46302b"), 8, Color.WHITE)
	var buy_pressed := g._panel(g.GOLD.darkened(0.2), 8, g.EMBER)
	var buy_disabled := g._panel(Color("2a2320"), 8, Color("53403a"))
	for buy_style in [buy_normal, buy_hover, buy_pressed, buy_disabled]:
		buy_style.content_margin_left = 10
		buy_style.content_margin_right = 10
	buy.add_theme_stylebox_override("normal", buy_normal)
	buy.add_theme_stylebox_override("hover", buy_hover)
	buy.add_theme_stylebox_override("pressed", buy_pressed)
	buy.add_theme_stylebox_override("disabled", buy_disabled)
	buy.disabled = not can_afford

	var price_overlay := HBoxContainer.new()
	price_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	price_overlay.offset_left = 46
	price_overlay.offset_right = -9
	price_overlay.alignment = BoxContainer.ALIGNMENT_END
	price_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.add_child(price_overlay)
	price_overlay.add_child(g._currency_amount("gold", price, 14, buy_price_color, 12))

	# Two taps, not one: this button sits directly beneath the card art inside the same tile, and
	# a single clean tap used to deduct gold on the spot. See _confirm_shop_action().
	g._bind_touch_guard(buy, func():
		_confirm_shop_action("ShopConfirmBuy_%s" % card.id, g.t("ui.shop_confirm_card_title"),
			[g.content.text(card.nameKey, g.lang), g._currency_amount("gold", price, 18, g.GOLD, 13)],
			g.GOLD, func(): _buy_card_with_feedback(btn, card, price)))
	price_row.add_child(buy)
	if owned > 0 and not on_sale:
		var next_row := HBoxContainer.new()
		next_row.add_theme_constant_override("separation", 3)
		next_row.alignment = BoxContainer.ALIGNMENT_CENTER
		next_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var next_lbl := g._label(g.t("ui.shop_next_price"), 8, Color("5e7278"))
		next_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		next_row.add_child(next_lbl)
		next_row.add_child(g._currency_amount("gold", _shop_price(card, owned + 1), 11, Color("5e7278"), 8))
		price_row.add_child(next_row)

	return btn

func _buy_card(card: Dictionary, price: int) -> void:
	if g.profile.gold < price: g._toast(g.t("ui.shop_no_gold")); return
	g.profile.gold -= price
	if int(g.profile.collection.get(card.id, 0)) == 0: g._advance_quest("collect_cards", 1)
	g.profile.collection[card.id] = g.profile.collection.get(card.id, 0) + 1
	SpiritSave.write(g.profile)
	g._advance_quest("shop_purchase", 1)
	show_shop()
	g._toast(g.tf("ui.shop_bought", g.content.text(card.nameKey, g.lang)), g.JADE)

# A purchase is deliberate and infrequent, unlike a card tap in battle, so it earns a
# synced haptic + flash rather than the plain instant rebuild _buy_card used to do alone —
# haptic timing should land on the visual peak, not fire blind before anything is on screen.
func _buy_card_with_feedback(tile: Panel, card: Dictionary, price: int) -> void:
	if int(g.profile.gold) < price:
		g._toast(g.t("ui.shop_no_gold"))
		return
	var buy_btn: Button = tile.get_node_or_null("BuyButton") as Button
	if buy_btn: buy_btn.disabled = true
	var pop := tile.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(tile, "scale", Vector2(1.06, 1.06), 0.09)
	pop.tween_property(tile, "scale", Vector2.ONE, 0.14)
	g._haptic("tap")
	await pop.finished
	_buy_card(card, price)

func _card_art_panel(card_id: String, art_size: Vector2, radius := 8) -> Control:
	var clip := Panel.new()
	clip.custom_minimum_size = art_size
	clip.size = art_size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_theme_stylebox_override("panel", g._panel(Color("07161a"), radius))
	var art := TextureRect.new()
	art.texture = g._get_card_texture(card_id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(art)

	# No frame texture here on purpose: this panel is used at thumbnail sizes down to 34x46,
	# and the ornate filigree frame (native 896x1200) turns into a solid muddy smear at that
	# scale — the same "washed out" failure the full-size hand card had, just worse. A plain
	# border reads correctly at any size.
	return clip

func _cost_badge(cost: int, accent: Color, diameter := 26) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size = badge.custom_minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", g._panel(accent, int(diameter / 2.0), Color("2b1a10")))
	var lbl := g._label(str(cost), int(diameter * 0.6), Color("160b06"), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge

# A single rounded border reads as a plain panel; a thin inset accent line plus a small leaf
# ornament at each corner is what turns it into something that reads as a picture frame,
# matching the ornate-border reference for the shop and deck-building screens.
func _add_ornate_frame(tile: Control, size: Vector2, accent: Color, rarity: String = "Common") -> void:
	var inset := Panel.new()
	inset.position = Vector2(3, 3)
	inset.size = size - Vector2(6, 6)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset_style := StyleBoxFlat.new()
	inset_style.bg_color = Color.TRANSPARENT
	inset_style.corner_radius_top_left = 6; inset_style.corner_radius_top_right = 6
	inset_style.corner_radius_bottom_left = 6; inset_style.corner_radius_bottom_right = 6
	inset_style.border_width_left = 1; inset_style.border_width_right = 1
	inset_style.border_width_top = 1; inset_style.border_width_bottom = 1
	inset_style.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	inset.add_theme_stylebox_override("panel", inset_style)
	tile.add_child(inset)

	var frame_overlay := TextureRect.new()
	frame_overlay.texture = g._get_card_frame_texture(rarity)
	frame_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(frame_overlay)

# Three tiers of the card's own rarity read as a row of small drawn stars instead of a raw
# English rarity word left untranslated in the Chinese UI.
func _rarity_star_row(rarity: String, color := g.GOLD, align := BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = align
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count: int = 3 if rarity == "Rare" else (2 if rarity == "Uncommon" else 1)
	for i in count:
		var star := GameIcon.new()
		star.kind = "star"
		star.icon_color = color
		star.custom_minimum_size = Vector2(11, 11)
		star.size = star.custom_minimum_size
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(star)
	return row

func show_deck() -> void:
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var page := g._create_page(6)
	page.add_child(g._header(g.t("ui.deck_title"), g.tf("ui.deck_sub", g.profile.deck.size()), g.show_map))
	g._maybe_show_tutorial("deck_synergies")

	# Search & Filter Chips (F3)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	var search_edit := LineEdit.new()
	search_edit.name = "DeckSearchInput"
	search_edit.placeholder_text = g.t("ui.deck_search_placeholder")
	search_edit.text = g.deck_search_query
	search_edit.custom_minimum_size = Vector2(0, 34)
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_submitted.connect(func(new_text: String):
		g.deck_search_query = new_text
		show_deck()
	)
	search_row.add_child(search_edit)
	if not g.deck_search_query.is_empty():
		var clear_btn := g._button("✕", func():
			g.deck_search_query = ""
			show_deck()
		, Color("2d2218"), Vector2(34, 34))
		search_row.add_child(clear_btn)
	page.add_child(search_row)

	var kind_chips := HBoxContainer.new()
	kind_chips.name = "DeckKindChips"
	kind_chips.add_theme_constant_override("separation", 4)
	for item in [["all", g.t("ui.deck_filter_all")], ["Attack", g.t("ui.deck_filter_attack")], ["Skill", g.t("ui.deck_filter_skill")], ["Power", g.t("ui.deck_filter_power")], ["Tactic", g.t("ui.deck_filter_tactic")]]:
		var k_id: String = item[0]
		var k_name: String = item[1]
		var active: bool = g.deck_filter_kind == k_id
		var chip := g._button(k_name, func(): g.deck_filter_kind = k_id; show_deck(), g.EMBER if active else Color("172a30"), Vector2(0, 28))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kind_chips.add_child(chip)
	page.add_child(kind_chips)

	var elem_chips := HBoxContainer.new()
	elem_chips.name = "DeckElementChips"
	elem_chips.add_theme_constant_override("separation", 3)
	for item in [["all", g.t("ui.deck_filter_elem_all")], ["", g.t("ui.deck_filter_elem_none")], ["fire", g.t("ui.deck_filter_elem_fire")], ["gale", g.t("ui.deck_filter_elem_gale")], ["stone", g.t("ui.deck_filter_elem_stone")], ["water", g.t("ui.deck_filter_elem_water")], ["poison", g.t("ui.deck_filter_elem_poison")]]:
		var e_id: String = item[0]
		var e_name: String = item[1]
		var active: bool = g.deck_filter_element == e_id
		var chip := g._button(e_name, func(): g.deck_filter_element = e_id; show_deck(), g.JADE if active else Color("112226"), Vector2(0, 26))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elem_chips.add_child(chip)
	page.add_child(elem_chips)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 14)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sections)

	# Grouped by rarity, richest first — a roster of thirty-some cards read as one undivided
	# grid before; a section header with its own star row tells you what you're looking at.
	var shown := 0
	for rarity in ["Rare", "Uncommon", "Common", "Starter"]:
		var group: Array = []
		for card in g.content.cards:
			if str(card.rarity) != rarity: continue
			if int(g.profile.collection.get(card.id, 0)) == 0: continue
			if g.deck_filter_kind != "all" and str(card.get("kind", "")) != g.deck_filter_kind: continue
			if g.deck_filter_element != "all" and str(card.get("element", "")) != g.deck_filter_element: continue
			if not g.deck_search_query.strip_edges().is_empty():
				var q: String = g.deck_search_query.to_lower().strip_edges()
				var c_name: String = str(g.content.card_name(card, g.lang)).to_lower()
				var c_desc: String = str(g.content.card_desc(card, g.lang)).to_lower()
				if not (q in c_name or q in c_desc or q in str(card.id).to_lower()): continue
			group.append(card)
		if group.is_empty(): continue

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		header.add_child(_rarity_star_row(rarity))
		header.add_child(g._label(g.t("rarity.%s" % rarity), 12, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		sections.add_child(header)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		sections.add_child(grid)
		for card in group:
			grid.add_child(_deck_card_tile(card, int(g.profile.collection.get(card.id, 0))))
			shown += 1
	if shown == 0:
		sections.add_child(g._label(g.t("ui.deck_need_cards"), 12, g.MUTED))

	var share_row := HBoxContainer.new()
	share_row.add_theme_constant_override("separation", 8)
	page.add_child(share_row)

	var export_btn := g._button(g.t("ui.deck_code_btn_export"), _export_deck_code, Color("1a353d"), Vector2(0, 36))
	export_btn.name = "DeckExportBtn"
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_row.add_child(export_btn)

	var import_btn := g._button(g.t("ui.deck_code_btn_import"), _show_import_deck_dialog, Color("1a353d"), Vector2(0, 36))
	import_btn.name = "DeckImportBtn"
	import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_row.add_child(import_btn)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	page.add_child(footer)
	var auto_btn := g._button(g.t("ui.deck_auto_build"), _auto_build_deck, Color("2f4c68"))
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_btn.custom_minimum_size = Vector2(0, 48)
	footer.add_child(auto_btn)
	var ready: bool = g.profile.deck.size() == 25
	var confirm := g._button("%s %d/25" % [g.t("ui.deck_confirm"), g.profile.deck.size()], _confirm_deck, g.EMBER if ready else Color("34464b"))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size = Vector2(0, 48)
	footer.add_child(confirm)

func _export_deck_code() -> void:
	var deck_cards: Array = g.profile.deck.duplicate()
	var json_str := JSON.stringify(deck_cards)
	var b64 := Marshalls.utf8_to_base64(json_str)
	var deck_code := "SPB1:%s" % b64
	g._clipboard_set(deck_code)
	g._toast(g.t("ui.deck_code_copied"), g.GOLD)

func _show_import_deck_dialog() -> void:
	var modal := g._modal_dialog("DeckImportModal", func():
		var ex: Node = g.overlay.get_node_or_null("DeckImportModal")
		if ex: ex.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var pstyle := g._panel(Color("0c1a1f"), 14, g.GOLD)
	pstyle.content_margin_left = 16
	pstyle.content_margin_right = 16
	pstyle.content_margin_top = 14
	pstyle.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)

	var head := HBoxContainer.new()
	head.add_child(g._label(g.t("ui.deck_code_import_title"), 14, g.GOLD))
	var close_btn := g._button("✕", func(): modal.queue_free(), Color("1c333a"), Vector2(30, 30))
	close_btn.name = "DeckImportCloseBtn"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	head.add_child(close_btn)
	list.add_child(head)

	list.add_child(g._label(g.t("ui.deck_code_import_desc"), 10, g.MUTED))

	var code_input := LineEdit.new()
	code_input.name = "DeckCodeInput"
	code_input.custom_minimum_size = Vector2(0, 38)
	var clip_text := g._clipboard_get()
	if clip_text.begins_with("SPB1:"):
		code_input.text = clip_text.strip_edges()
	list.add_child(code_input)

	var confirm_btn := g._button(g.t("ui.deck_code_btn_import"), func():
		var raw_code := code_input.text.strip_edges()
		if not raw_code.begins_with("SPB1:"):
			g._toast(g.t("ui.deck_code_import_err"), g.EMBER)
			return
		var b64_part := raw_code.substr(5).strip_edges()
		var json_str := Marshalls.base64_to_utf8(b64_part)
		var test_json := JSON.new()
		if test_json.parse(json_str) != OK or not test_json.data is Array:
			g._toast(g.t("ui.deck_code_import_err"), g.EMBER)
			return
		var imported_cards: Array = test_json.data
		# Exactly 25, matching _confirm_deck()'s own gate on a manually-built deck — a code is
		# unsigned base64 JSON a player can hand-edit, so without this an edited or malformed
		# code could install a deck of any size (bypassing _confirm_deck() entirely, since
		# import writes profile.deck directly) and silently break the 25-card invariant every
		# other deck-affecting system in this codebase assumes.
		if imported_cards.size() != 25:
			g._toast(g.t("ui.deck_code_import_err"), g.EMBER)
			return
		var counts: Dictionary = {}
		for cid in imported_cards:
			var card_id := str(cid)
			if g.content.card(card_id).is_empty():
				g._toast(g.t("ui.deck_code_import_err"), g.EMBER)
				return
			counts[card_id] = int(counts.get(card_id, 0)) + 1
			if int(counts[card_id]) > int(g.profile.collection.get(card_id, 0)):
				g._toast(g.t("ui.deck_code_import_err"), g.EMBER)
				return
		g.profile.deck = imported_cards
		SpiritSave.write(g.profile)
		modal.queue_free()
		g._toast(g.t("ui.deck_code_imported"), g.GOLD)
		show_deck()
	, g.EMBER, Vector2(0, 40))
	confirm_btn.name = "DeckImportConfirmBtn"
	list.add_child(confirm_btn)

func _deck_card_tile(card: Dictionary, owned: int) -> Control:
	var in_deck: int = g.profile.deck.count(card.id)
	var accent := g._card_color(card)
	var rune_id: String = g.profile.card_runes.get(card.id, "")
	var up_lvl: int = int(g.profile.upgrades.get(card.id, 0))

	var border_color: Color = accent if in_deck > 0 else Color("24373d")
	if up_lvl > 0:
		border_color = border_color.lerp(g.GOLD, 0.55)
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(176, 232)
	tile.size = tile.custom_minimum_size
	tile.add_theme_stylebox_override("panel", g._panel(Color("11242a"), 12, border_color))
	tile.clip_contents = true

	# 1. Full-bleed card illustration covering the entire tile
	var art := TextureRect.new()
	art.texture = g._get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._apply_card_foil(art, str(card.get("rarity", "Common")), up_lvl > 0)
	tile.add_child(art)

	# 2. Ornate frame around the entire card perimeter
	_add_ornate_frame(tile, tile.custom_minimum_size, border_color, str(card.get("rarity", "Common")))

	# 3. Top elements (Cost badge, Rune icon, Rarity stars)
	var badge := _cost_badge(int(card.cost), accent)
	badge.position = Vector2(8, 8)
	tile.add_child(badge)

	if not rune_id.is_empty():
		var rune_info := g.content.rune(rune_id)
		var rune_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_path)
			r_tr.position = Vector2(38, 8)
			r_tr.custom_minimum_size = Vector2(22, 22)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(r_tr)
		else:
			var rune_lbl := g._label(rune_info.icon, 15, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			rune_lbl.position = Vector2(40, 8)
			rune_lbl.size = Vector2(20, 20)
			tile.add_child(rune_lbl)

	var rarity_row := _rarity_star_row(str(card.rarity), g.GOLD, BoxContainer.ALIGNMENT_END)
	rarity_row.position = Vector2(88, 10)
	rarity_row.size = Vector2(76, 16)
	tile.add_child(rarity_row)

	# 4. Carved-out space in the lower-middle portion for card info
	var info_box := PanelContainer.new()
	info_box.position = Vector2(8, 126)
	info_box.custom_minimum_size = Vector2(160, 98)
	info_box.size = info_box.custom_minimum_size
	var box_style := g._panel(Color(0.04, 0.08, 0.10, 0.48), 8, border_color)
	# Slender border g.overlay margin
	box_style.content_margin_left = 12; box_style.content_margin_right = 12
	box_style.content_margin_top = 2; box_style.content_margin_bottom = 2
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	info_box.add_child(stack)

	var name_lbl := g._label(g.content.text(card.nameKey, g.lang) + (" +%d" % up_lvl if up_lvl > 0 else ""), 12, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 2)
	stack.add_child(name_lbl)

	var kind_lbl := g._label(g._kind_element_line(card), 8, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	kind_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	kind_lbl.add_theme_constant_override("outline_size", 2)
	stack.add_child(kind_lbl)

	var desc := g._label(g._card_description(card), 8, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	desc.add_theme_constant_override("outline_size", 2)
	desc.custom_minimum_size.y = 24
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)

	var counts := g._label("%s %d · %s %d" % [g.t("ui.deck_in_deck"), in_deck, g.t("ui.deck_owned_short"), owned], 9, g.JADE if in_deck > 0 else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(counts)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(controls)
	var minus := g._button("−", func(): _deck_change(card.id, -1), Color("593b32"), Vector2(50, 30))
	minus.disabled = in_deck <= 0
	controls.add_child(minus)
	var plus := g._button("+", func(): _deck_change(card.id, 1), Color("245247"), Vector2(50, 30))
	plus.disabled = in_deck >= owned or g.profile.deck.size() >= 25
	controls.add_child(plus)

	return tile

func _confirm_deck() -> void:
	if g.profile.deck.size() != 25:
		g._toast(g.tf("ui.deck_sub", g.profile.deck.size()))
		return
	SpiritSave.write(g.profile)
	g.show_map()

func _deck_change(id: String, amount: int) -> void:
	if amount > 0:
		if g.profile.deck.size() >= 25: g._toast(g.t("ui.deck_full")); return
		if g.profile.deck.count(id) >= int(g.profile.collection.get(id, 0)): return
		g.profile.deck.append(id)
	elif amount < 0 and g.profile.deck.has(id):
		g.profile.deck.erase(id)
	SpiritSave.write(g.profile)
	show_deck()

# This drives both auto-build and smart-add, so it has to judge what a card actually
# does. It used to be almost pure rarity (Rare +30 vs Common +12, minus a small cost
# penalty), which happily filled a deck with every Power/Tactic utility card the shop
# offered — foxBlessing, soulBrand, mountainSeal, titanForm — while starving it of the
# reliable single-target damage that closes out fights. On real g.content that deck lost
# repeatedly to a chapter-7 boss with two enemies, because nothing in hand ever finished
# the add before it added up. Rarity now nudges the score instead of dominating it.
func _card_build_score(card: Dictionary) -> float:
	var score := 0.0
	var attack_double: float = 2.0 if str(card.get("special", "")) == "critical" else 1.0
	for effect in card.effects:
		match effect.operation:
			"damage": score += float(effect.amount) * 2.2 * attack_double
			"shield": score += float(effect.amount) * 2.0
			"heal": score += float(effect.amount) * 1.0
			"draw": score += float(effect.amount) * 3.0
			"energy": score += float(effect.amount) * 4.0
			"status":
				match str(effect.get("status", "")):
					"burn": score += float(effect.amount) * 1.3
					"poison": score += float(effect.amount) * 1.5
					"focus": score += float(effect.amount) * 2.0
					"strength": score += float(effect.amount) * 3.0
					"vulnerable", "weak": score += float(effect.amount) * 1.8
	match str(card.get("special", "")):
		"cleave": score *= 1.35
		"pierce": score += 3.0
		"stun": score += 5.0
		"recoverExhaust", "recycleDiscard": score += 4.0

	# Boomerang/Reverb/Overload (Phase 7) live as top-level card fields, not effects or
	# `special`, so without these cases they'd silently score as plain vanilla cards.
	if bool(card.get("boomerang", false)): score += 3.5
	if bool(card.get("reverb", false)): score *= 1.5
	score -= float(int(card.get("overload", 0))) * 2.5

	score += {"Rare": 4.0, "Uncommon": 2.0, "Common": 1.0}.get(card.get("rarity", "Common"), 0.0)
	score += float(int(g.profile.upgrades.get(card.id, 0))) * 6.0
	# With costs now up to 3, an expensive card has to earn a bigger share of a turn.
	score -= float(int(card.cost)) * 3.0
	if not str(g.profile.card_runes.get(card.id, "")).is_empty(): score += 8.0
	return score

func _auto_build_deck() -> void:
	var pool: Array = []
	for card in g.content.cards:
		for i in int(g.profile.collection.get(card.id, 0)): pool.append(card)
	if pool.size() < 25:
		g._toast(g.t("ui.deck_need_cards"))
		return
	pool.sort_custom(func(a, b): return _card_build_score(a) > _card_build_score(b))

	# Aim for a playable curve rather than just the highest-rarity cards. Each pool entry is one
	# owned copy, so tracking consumed indices keeps the deck within what the collection holds.
	var picked: Array = []
	var used := {}
	var attacks := 0
	var defence := 0
	for i in pool.size():
		if picked.size() >= 25: break
		var card: Dictionary = pool[i]
		var kind: String = card.get("kind", "Skill")
		if kind == "Attack" and attacks >= 14: continue
		if kind in ["Skill", "Power"] and defence >= 9: continue
		picked.append(card.id)
		used[i] = true
		if kind == "Attack": attacks += 1
		elif kind in ["Skill", "Power"]: defence += 1
	for i in pool.size():
		if picked.size() >= 25: break
		if used.has(i): continue
		picked.append(pool[i].id)

	g.profile.deck = picked
	SpiritSave.write(g.profile)
	show_deck()
	g._toast(g.t("ui.deck_auto_done"), g.JADE)

func _tab_bar(tabs: Array, active: String, on_pick: Callable) -> Control:
	var bar := Panel.new()
	bar.custom_minimum_size.y = 44
	bar.add_theme_stylebox_override("panel", g._panel(Color("0c1a1f"), 22, Color("1f404d")))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)
	var font_sz: int = 9 if tabs.size() > 6 else (10 if tabs.size() > 5 else (11 if tabs.size() > 3 else 13))
	var rad: int = 10 if tabs.size() > 6 else (12 if tabs.size() > 4 else 22)
	for entry in tabs:
		var id: String = entry[0]
		var is_active: bool = id == active
		var btn := Button.new()
		btn.text = entry[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44)
		btn.clip_text = true
		btn.focus_mode = Control.FOCUS_NONE
		if g.font_cjk: btn.add_theme_font_override("font", g.font_cjk)
		btn.add_theme_font_size_override("font_size", font_sz)
		btn.add_theme_color_override("font_color", Color("10242b") if is_active else g.MUTED)
		btn.add_theme_color_override("font_hover_color", Color("10242b") if is_active else g.TEXT)
		var active_style := g._panel(g.JADE, rad)
		active_style.content_margin_left = 2; active_style.content_margin_right = 2
		var inactive_hover := g._panel(Color(1, 1, 1, 0.06), rad)
		inactive_hover.content_margin_left = 2; inactive_hover.content_margin_right = 2
		var inactive_normal := StyleBoxEmpty.new()
		inactive_normal.content_margin_left = 2; inactive_normal.content_margin_right = 2
		var inactive_pressed := g._panel(Color(1, 1, 1, 0.1), rad)
		inactive_pressed.content_margin_left = 2; inactive_pressed.content_margin_right = 2
		btn.add_theme_stylebox_override("normal", active_style if is_active else inactive_normal)
		btn.add_theme_stylebox_override("hover", active_style if is_active else inactive_hover)
		btn.add_theme_stylebox_override("pressed", g._panel(g.JADE.darkened(0.1), rad) if is_active else inactive_pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("disabled", inactive_normal)
		g._bind_touch_guard(btn, func(): on_pick.call(id))
		row.add_child(btn)
	return bar

func show_loadout() -> void:
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var page := g._create_page(6)
	page.add_child(g._header(g.t("ui.loadout_title"), g.t("ui.loadout_sub"), g.show_map))
	page.add_child(_tab_bar([["equipment", g.t("ui.tab_equipment")], ["runes", g.t("ui.tab_runes")]], g.loadout_tab, func(id): g.loadout_tab = id; show_loadout()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if g.loadout_tab == "equipment":
		_build_equipment_tab(list)
	else:
		g._maybe_show_tutorial("rune_resonance")
		_build_rune_tab(list)

func _build_equipment_tab(list: VBoxContainer) -> void:
	list.add_child(g._label(g.t("ui.loadout_cur_equip"), 13, g.JADE))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	list.add_child(slots)
	for slot in ["weapon", "armor", "charm"]:
		var item_id: String = str(g.profile.equipment_slots.get(slot, ""))
		var item := g.content.equipment(item_id)
		var filled: bool = not item.is_empty()
		var tier: int = int(g.profile.get("equipment_tiers", {}).get(item_id, 0)) if filled else 0
		var tier_col: Color = g.content.equip_tier_color(tier) if filled else Color("2a3d42")
		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 96)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", g._panel(Color("16333a") if filled else Color("101f24"), 12, tier_col if filled else Color("2a3d42")))
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 2)
		card.add_child(stack)
		var badge_row := HBoxContainer.new()
		badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_child(badge_row)
		badge_row.add_child(g._equip_icon_badge(item, tier_col, 38) if filled else g._icon_badge("＋", Color("3c5057"), 38, 18))
		stack.add_child(g._label(g.t("ui.slot_%s" % slot), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		var name_str: String = ("【%s】" % g.content.equip_tier_name(tier, g.lang) + g._equip_name(item)) if filled else g.t("ui.loadout_empty")
		stack.add_child(g._label(name_str, 10, g.TEXT if filled else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		slots.add_child(card)

	list.add_child(g._label(g.t("ui.loadout_collection"), 13, g.JADE))
	for item in SpiritContent.EQUIPMENT:
		var owned: bool = g.profile.equipment_owned.has(item.id)
		var equipped: bool = g.profile.equipment_slots.get(item.slot, "") == item.id
		var tier: int = int(g.profile.get("equipment_tiers", {}).get(item.id, 0)) if owned else 0
		var tier_col: Color = g.content.equip_tier_color(tier) if owned else Color("3c5057")
		var accent: Color = g.JADE if equipped else (tier_col if owned else Color("3c5057"))

		var item_card := PanelContainer.new()
		item_card.custom_minimum_size.y = 74
		item_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_card.add_theme_stylebox_override("panel", g._panel(Color("15383a") if equipped else Color("13282e"), 12, accent))
		list.add_child(item_card)

		var pad := MarginContainer.new()
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		for side in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
		item_card.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		pad.add_child(row)

		var badge_holder := CenterContainer.new()
		badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_holder.add_child(g._equip_icon_badge(item, accent, 44))
		row.add_child(badge_holder)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		row.add_child(texts)

		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		texts.add_child(title_row)
		title_row.add_child(g._label(g._equip_name(item), 13, g.TEXT if owned else g.MUTED))
		if owned:
			title_row.add_child(g._label("【%s】" % g.content.equip_tier_name(tier, g.lang), 10, tier_col))
		title_row.add_child(g._label("· %s" % g.t("ui.slot_%s" % item.slot), 9, g.MUTED))

		var detail := g._label(g.content.equip_detail_tiered(item, tier, g.lang), 9, g.JADE if owned else Color("445559"), HORIZONTAL_ALIGNMENT_LEFT, true)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(detail)

		if owned:
			var affixes: Array = g.profile.get("equipment_inscriptions", {}).get(item.id, [])
			if not affixes.is_empty():
				var aff_texts: Array[String] = []
				for aff in affixes:
					if aff is Dictionary:
						var txt: String = g.content.inscription_text(aff, g.lang)
						if not txt.is_empty(): aff_texts.append("✦ " + txt)
				if not aff_texts.is_empty():
					texts.add_child(g._label(" ".join(aff_texts), 8, Color("78e9ff"), HORIZONTAL_ALIGNMENT_LEFT, true))

		var btn_col := HBoxContainer.new()
		btn_col.add_theme_constant_override("separation", 6)
		btn_col.alignment = BoxContainer.ALIGNMENT_END
		btn_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btn_col)

		if owned:
			var reforge_btn := g._button(g.t("ui.reforge_btn"), func(): show_reforge_modal(item.id), Color("173e44"), Vector2(48, 30))
			reforge_btn.name = "ReforgeBtn_" + item.id
			btn_col.add_child(reforge_btn)

			var equip_btn_text := g.t("ui.loadout_unequip") if equipped else g.t("ui.loadout_equip")
			var equip_btn := g._button(equip_btn_text, func(): g._equip(item), Color("144c45") if equipped else Color("1b3238"), Vector2(48, 30))
			equip_btn.name = "EquipBtn_" + item.id
			btn_col.add_child(equip_btn)
		else:
			var status := g._label(g.t("ui.loadout_unobtained"), 10, Color("3c5057"), HORIZONTAL_ALIGNMENT_RIGHT)
			status.custom_minimum_size.x = 48
			btn_col.add_child(status)

func _build_rune_tab(list: VBoxContainer) -> void:
	list.add_child(g._label(g.t("ui.loadout_runes_bag"), 13, g.JADE))
	list.add_child(g._label(g.t("ui.rune_none_selected"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var bag := GridContainer.new()
	bag.columns = 5
	bag.add_theme_constant_override("h_separation", 6)
	bag.add_theme_constant_override("v_separation", 6)
	list.add_child(bag)
	for rune in SpiritContent.RUNES:
		var available: int = int(g.profile.rune_inventory.get(rune.id, 0)) - g.profile.card_runes.values().count(rune.id)
		var color := Color(rune.color)
		var is_selected: bool = g.selected_rune == rune.id
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(66, 74)
		btn.focus_mode = Control.FOCUS_NONE
		btn.disabled = available <= 0
		btn.add_theme_stylebox_override("normal", g._panel(Color("173a40") if is_selected else Color("12262b"), 12, color if is_selected else Color("28393e")))
		btn.add_theme_stylebox_override("hover", g._panel(Color("1b444b"), 12, color))
		btn.add_theme_stylebox_override("pressed", g._panel(Color("102026"), 12, color))
		btn.add_theme_stylebox_override("disabled", g._panel(Color("0e191d"), 12, Color("222e31")))
		g._bind_touch_guard(btn, func(): g.selected_rune = "" if is_selected else rune.id; show_loadout())
		bag.add_child(btn)

		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 1)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(stack)
		var rune_badge := g._rune_icon_badge(rune, color if available > 0 else Color("3c5057"), 34)
		var rune_badge_holder := CenterContainer.new()
		rune_badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rune_badge_holder.add_child(rune_badge)
		stack.add_child(rune_badge_holder)
		stack.add_child(g._label(g._rune_name(rune), 9, g.TEXT if available > 0 else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(g._label("×%d" % maxi(0, available), 9, g.GOLD if available > 0 else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if not g.selected_rune.is_empty():
		var chosen := g.content.rune(g.selected_rune)
		var hint := g._label("%s %s · %s" % [chosen.icon, g._rune_name(chosen), g._rune_detail(chosen)], 10, Color(chosen.color), HORIZONTAL_ALIGNMENT_CENTER, true)
		list.add_child(hint)

	list.add_child(g._label(g.t("ui.rune_resonance_title"), 13, g.JADE))
	var active_sets: Array = g.content.active_rune_sets(g.profile.card_runes)
	for rune_set in SpiritContent.RUNE_SETS:
		var is_active: bool = active_sets.has(rune_set.id)
		var set_color: Color = Color(rune_set.color)
		var row := Panel.new()
		row.custom_minimum_size.y = 58
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("panel", g._panel(Color("173a2e") if is_active else Color("101f24"), 12, set_color if is_active else Color("28393e")))
		list.add_child(row)
		var set_pad := MarginContainer.new()
		set_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: set_pad.add_theme_constant_override("margin_%s" % side, 10)
		set_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(set_pad)
		var set_stack := VBoxContainer.new()
		set_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		set_stack.add_theme_constant_override("separation", 1)
		set_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_pad.add_child(set_stack)
		var set_head := HBoxContainer.new()
		set_head.alignment = BoxContainer.ALIGNMENT_CENTER
		set_head.add_theme_constant_override("separation", 6)
		set_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_stack.add_child(set_head)
		set_head.add_child(g._label(g.t("set.%s.name" % str(rune_set.id).trim_prefix("set_")), 12, set_color if is_active else g.TEXT))
		set_head.add_child(g._label(g.t("ui.rune_resonance_active") if is_active else g.t("ui.rune_resonance_inactive"), 9, g.JADE if is_active else g.MUTED))
		set_stack.add_child(g._label(g.t("set.%s.desc" % str(rune_set.id).trim_prefix("set_")), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	list.add_child(g._label(g.t("ui.loadout_deck_runes"), 13, g.JADE))
	for id in g._unique(g.profile.deck):
		var card := g.content.card(id)
		var installed: Dictionary = g.content.rune(g.profile.card_runes.get(id, ""))
		var has_rune: bool = not installed.is_empty()
		var accent: Color = Color(installed.color) if has_rune else Color("2a3d42")

		var row_panel := Panel.new()
		row_panel.custom_minimum_size.y = 58
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", g._panel(Color("12262b"), 12, accent))
		list.add_child(row_panel)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 8)
		row_panel.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		pad.add_child(row)

		var art_holder := CenterContainer.new()
		art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(_card_art_panel(id, Vector2(34, 46), 6))
		row.add_child(art_holder)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 1)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(texts)
		texts.add_child(g._label(g.content.text(card.nameKey, g.lang), 12, g.TEXT))
		texts.add_child(g._label("%s %s" % [installed.icon, g._rune_name(installed)] if has_rune else g.t("ui.loadout_unsocketed"), 10, accent if has_rune else g.MUTED))

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(actions)
		if has_rune:
			actions.add_child(g._button(g.t("ui.loadout_remove"), func(): g.profile.card_runes.erase(id); SpiritSave.write(g.profile); show_loadout(), Color("593b32"), Vector2(52, 36)))
		else:
			var socket_btn := g._button(g.t("ui.loadout_socket"), func(): g._socket(id), Color("245247"), Vector2(52, 36))
			socket_btn.disabled = g.selected_rune.is_empty()
			actions.add_child(socket_btn)

func _close_reforge_modal() -> void:
	if g.overlay.has_node("ReforgeModal"):
		var existing: Node = g.overlay.get_node("ReforgeModal")
		existing.queue_free()

func show_reforge_modal(item_id: String) -> void:
	_close_reforge_modal()
	var item: Dictionary = g.content.equipment(item_id)
	if item.is_empty(): return

	var modal := g._modal_dialog("ReforgeModal", func(): _close_reforge_modal(); show_loadout())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ReforgeModalPanel"
	var vp_w: int = int(g.get_viewport_rect().size.x)
	panel.custom_minimum_size = Vector2(mini(360, vp_w - 20), 520)
	panel.add_theme_stylebox_override("panel", g._panel(Color("091316"), 14, g.GOLD))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)

	var refresh_modal_ui: Array = [Callable()]
	refresh_modal_ui[0] = func():
		for ch in vbox.get_children():
			ch.queue_free()

		var tier: int = int(g.profile.get("equipment_tiers", {}).get(item.id, 0))
		var tier_col: Color = g.content.equip_tier_color(tier)
		var tier_str: String = g.content.equip_tier_name(tier, g.lang)

		# 1. Header row
		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 6)
		var title_box := VBoxContainer.new()
		title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_box.add_theme_constant_override("separation", 2)
		title_box.add_child(g._label(g.t("ui.reforge_title"), 15, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		title_box.add_child(g._label(g._equip_name(item) + " · " + g.t("ui.slot_%s" % item.slot), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		header_row.add_child(title_box)

		var close_btn := g._button("✕", func(): _close_reforge_modal(); show_loadout(), Color("223640"), Vector2(32, 32))
		close_btn.name = "ReforgeCloseBtn"
		close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_row.add_child(close_btn)
		vbox.add_child(header_row)

		# 2. Currency bar (Gold & Spirit Dust) — same designed icons as the HUD, not ◈/✧ glyphs.
		var currency_row := HBoxContainer.new()
		currency_row.add_theme_constant_override("separation", 14)
		currency_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		currency_row.add_child(g._currency_amount("gold", int(g.profile.gold), 20, g.GOLD, 12))
		currency_row.add_child(g._currency_amount("dust", int(g.profile.spirit_dust), 20, Color("80d6ff"), 12))
		vbox.add_child(currency_row)

		# 3. Item Card Showcase
		var item_box := PanelContainer.new()
		item_box.add_theme_stylebox_override("panel", g._panel(Color("12242a"), 10, tier_col))
		var item_pad := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]: item_pad.add_theme_constant_override("margin_%s" % s, 10)
		item_box.add_child(item_pad)
		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 10)
		item_pad.add_child(item_row)

		item_row.add_child(g._equip_icon_badge(item, tier_col, 50))
		var item_info := VBoxContainer.new()
		item_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_info.add_theme_constant_override("separation", 3)
		item_row.add_child(item_info)

		var name_line := HBoxContainer.new()
		name_line.add_theme_constant_override("separation", 6)
		item_info.add_child(name_line)
		name_line.add_child(g._label(g._equip_name(item), 14, g.TEXT))
		name_line.add_child(g._label("【%s】" % tier_str, 12, tier_col))

		var cur_desc: String = g.content.equip_detail_tiered(item, tier, g.lang)
		item_info.add_child(g._label(cur_desc, 10, g.JADE, HORIZONTAL_ALIGNMENT_LEFT, true))
		vbox.add_child(item_box)

		# 4. Reforge Section (进阶重铸)
		var reforge_box := PanelContainer.new()
		reforge_box.add_theme_stylebox_override("panel", g._panel(Color("101d22"), 10, Color("2a444d")))
		var reforge_pad := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]: reforge_pad.add_theme_constant_override("margin_%s" % s, 8)
		reforge_box.add_child(reforge_pad)
		var reforge_col := VBoxContainer.new()
		reforge_col.add_theme_constant_override("separation", 6)
		reforge_pad.add_child(reforge_col)

		reforge_col.add_child(g._label(g.t("ui.reforge_tab_title"), 12, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))

		if tier < 3:
			var cost: Dictionary = g.content.equip_tier_cost(tier)
			var gold_cost: int = int(cost.get("gold", 100))
			var dust_cost: int = int(cost.get("dust", 20))
			var next_tier_str: String = g.content.equip_tier_name(tier + 1, g.lang)
			var next_desc: String = g.content.equip_detail_tiered(item, tier + 1, g.lang)

			reforge_col.add_child(g._label(g.tf("ui.reforge_next_tier", "【%s】" % next_tier_str), 10, g.content.equip_tier_color(tier + 1), HORIZONTAL_ALIGNMENT_LEFT))
			reforge_col.add_child(g._label(next_desc, 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

			var cost_lbl := g._label(g.tf("ui.reforge_cost_fmt", [gold_cost, dust_cost]), 10, g.GOLD if (g.profile.gold >= gold_cost and g.profile.spirit_dust >= dust_cost) else Color("ff7373"), HORIZONTAL_ALIGNMENT_LEFT)
			reforge_col.add_child(cost_lbl)

			var can_upgrade: bool = g.profile.gold >= gold_cost and g.profile.spirit_dust >= dust_cost
			var up_btn := g._button(g.t("ui.reforge_upgrade_btn"), func():
				if not (g.profile.gold >= gold_cost and g.profile.spirit_dust >= dust_cost):
					g._toast(g.t("ui.reforge_insufficient"), Color("ff7373"))
					return
				g.profile.gold -= gold_cost
				g.profile.spirit_dust -= dust_cost
				g.profile.equipment_tiers[item.id] = tier + 1
				SpiritSave.write(g.profile)
				g._toast(g.tf("ui.reforge_toast_success", [g._equip_name(item), next_tier_str]), g.GOLD)
				if g.sfx != null: g.sfx.play("victory")
				refresh_modal_ui[0].call()
			, Color("1d4f40") if can_upgrade else Color("223035"), Vector2(0, 34))
			up_btn.name = "ReforgeUpgradeBtn"
			up_btn.disabled = not can_upgrade
			reforge_col.add_child(up_btn)
		else:
			reforge_col.add_child(g._label(g.t("ui.reforge_maxed"), 11, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		vbox.add_child(reforge_box)

		# 5. Inscriptions Section (灵纹洗练)
		var inscribe_box := PanelContainer.new()
		inscribe_box.add_theme_stylebox_override("panel", g._panel(Color("101d22"), 10, Color("2a444d")))
		var inscribe_pad := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]: inscribe_pad.add_theme_constant_override("margin_%s" % s, 8)
		inscribe_box.add_child(inscribe_pad)
		var inscribe_col := VBoxContainer.new()
		inscribe_col.add_theme_constant_override("separation", 6)
		inscribe_pad.add_child(inscribe_col)

		inscribe_col.add_child(g._label(g.t("ui.inscribe_title"), 12, Color("78e9ff"), HORIZONTAL_ALIGNMENT_LEFT))

		var current_inscriptions: Array = g.profile.get("equipment_inscriptions", {}).get(item.id, [])
		var max_slots: int = 3
		var unlocked_slots: int = clampi(tier, 0, 3)

		for slot_idx in range(max_slots):
			var slot_box := PanelContainer.new()
			slot_box.add_theme_stylebox_override("panel", g._panel(Color("0d181c"), 6, Color("1c2f35")))
			var slot_pad := MarginContainer.new()
			for s in ["left", "right", "top", "bottom"]: slot_pad.add_theme_constant_override("margin_%s" % s, 4)
			slot_box.add_child(slot_pad)

			if slot_idx < unlocked_slots:
				if slot_idx < current_inscriptions.size():
					var aff: Dictionary = current_inscriptions[slot_idx]
					var aff_txt: String = g.content.inscription_text(aff, g.lang)
					var aff_lbl := g._label(g.t("ui.inscribe_affix_prefix") + aff_txt, 10, Color("78e9ff"), HORIZONTAL_ALIGNMENT_LEFT)
					slot_pad.add_child(aff_lbl)
				else:
					var empty_lbl := g._label(g.t("ui.inscribe_empty"), 9, Color("4a6870"), HORIZONTAL_ALIGNMENT_LEFT)
					slot_pad.add_child(empty_lbl)
			else:
				var lock_tier_str: String = g.content.equip_tier_name(slot_idx + 1, g.lang)
				var lock_lbl := g._label(g.tf("ui.inscribe_slot_locked", lock_tier_str), 9, Color("35454a"), HORIZONTAL_ALIGNMENT_LEFT)
				slot_pad.add_child(lock_lbl)
			inscribe_col.add_child(slot_box)

		var inscribe_cost: Dictionary = g.content.equip_inscribe_cost()
		var insc_gold: int = int(inscribe_cost.get("gold", 30))
		var insc_dust: int = int(inscribe_cost.get("dust", 10))

		var insc_cost_lbl := g._label(g.tf("ui.inscribe_cost_fmt", [insc_gold, insc_dust]), 9, g.GOLD if (g.profile.gold >= insc_gold and g.profile.spirit_dust >= insc_dust) else Color("ff7373"), HORIZONTAL_ALIGNMENT_LEFT)
		inscribe_col.add_child(insc_cost_lbl)

		var can_inscribe: bool = unlocked_slots > 0 and g.profile.gold >= insc_gold and g.profile.spirit_dust >= insc_dust
		var inscribe_btn := g._button(g.t("ui.inscribe_btn"), func():
			if unlocked_slots <= 0:
				g._toast(g.t("ui.inscribe_no_slots"), Color("ff7373"))
				return
			if not (g.profile.gold >= insc_gold and g.profile.spirit_dust >= insc_dust):
				g._toast(g.t("ui.reforge_insufficient"), Color("ff7373"))
				return
			g.profile.gold -= insc_gold
			g.profile.spirit_dust -= insc_dust
			var rolled: Array = g.content.roll_inscription_affixes(tier)
			g.profile.equipment_inscriptions[item.id] = rolled
			SpiritSave.write(g.profile)
			g._toast(g.t("ui.inscribe_toast_success"), Color("78e9ff"))
			if g.sfx != null: g.sfx.play("rune")
			refresh_modal_ui[0].call()
		, Color("1a404a") if can_inscribe else Color("223035"), Vector2(0, 34))
		inscribe_btn.name = "InscribeRollBtn"
		inscribe_btn.disabled = not can_inscribe
		inscribe_col.add_child(inscribe_btn)

		vbox.add_child(inscribe_box)

	refresh_modal_ui[0].call()

