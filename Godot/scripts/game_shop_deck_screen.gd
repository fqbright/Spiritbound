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

const SHOP_STOCK_COUNT := 6

# Stock and the day's sale slot are derived from the day number rather than stored, so
# they need no save-file field and can't drift out of sync with the daily quest reset.
func _shop_period() -> Dictionary:
	var day: int = int(Time.get_unix_time_from_system()) / g.DAY_SECONDS
	return g.content.roll_shop_stock(day, SHOP_STOCK_COUNT)

func _shop_reset_at() -> int:
	var day: int = int(Time.get_unix_time_from_system()) / g.DAY_SECONDS
	return (day + 1) * g.DAY_SECONDS

# Escalating cost is the direct fix for "just buy the same card forever": each copy already
# owned raises the price of the next one, the same shape as Slay the Spire's card-removal
# cost climbing with each use, rather than a flat price with no friction on repeat buys.
func _shop_price(card: Dictionary, owned: int) -> int:
	var base := 90 if card.rarity == "Rare" else 60 if card.rarity == "Uncommon" else 40
	return int(round(float(base) * (1.0 + float(owned) * 0.35) / 5.0)) * 5

func show_shop() -> void:
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var backdrop := g._background("lantern-marsh-v1.jpg", .18); g.root.add_child(backdrop); g.root.move_child(backdrop, 0)
	var page := g._create_page(8)
	page.add_child(g._header(g.t("ui.shop_title"), g.t("ui.shop_sub"), g.show_map))
	page.add_child(g._label(g.tf("ui.shop_refresh", g._format_countdown(_shop_reset_at())), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var svc_row := HBoxContainer.new()
	svc_row.custom_minimum_size.y = 56
	svc_row.add_theme_constant_override("separation", 8)
	page.add_child(svc_row)

	var potion := Button.new()
	potion.custom_minimum_size.y = 56
	potion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion.focus_mode = Control.FOCUS_NONE
	var affordable: bool = int(g.profile.gold) >= 30
	potion.add_theme_stylebox_override("normal", g._panel(Color("1d4a40"), 12, g.JADE if affordable else Color("2a3d42")))
	potion.add_theme_stylebox_override("hover", g._panel(Color("245a4d"), 12, g.JADE))
	potion.add_theme_stylebox_override("pressed", g._panel(Color("163a32"), 12, g.GOLD))
	potion.pressed.connect(_buy_potion)
	svc_row.add_child(potion)

	var potion_row := HBoxContainer.new()
	potion_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	potion_row.add_theme_constant_override("separation", 8)
	potion_row.alignment = BoxContainer.ALIGNMENT_CENTER
	potion_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion.add_child(potion_row)
	var potion_badge := CenterContainer.new()
	potion_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_badge.add_child(g._icon_badge("✚", g.JADE, 32, 16))
	potion_row.add_child(potion_badge)
	var potion_texts := VBoxContainer.new()
	potion_texts.alignment = BoxContainer.ALIGNMENT_CENTER
	potion_texts.add_theme_constant_override("separation", 1)
	potion_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_row.add_child(potion_texts)
	potion_texts.add_child(g._label(g.t("ui.shop_potion"), 11, g.TEXT))
	potion_texts.add_child(g._label(g.tf("ui.shop_gold", 30), 10, g.GOLD))

	var purge_svc := Button.new()
	purge_svc.name = "ShopPurgeBtn"
	purge_svc.custom_minimum_size.y = 56
	purge_svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purge_svc.focus_mode = Control.FOCUS_NONE
	var can_purge: bool = int(g.profile.gold) >= 50
	purge_svc.add_theme_stylebox_override("normal", g._panel(Color("261d36"), 12, Color("c79bff") if can_purge else Color("2a3d42")))
	purge_svc.add_theme_stylebox_override("hover", g._panel(Color("37264f"), 12, Color("c79bff")))
	purge_svc.add_theme_stylebox_override("pressed", g._panel(Color("1c142b"), 12, g.GOLD))
	purge_svc.pressed.connect(func(): show_deck_purge(show_shop, 50))
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
	purge_texts.add_child(g._label(g.tf("ui.shop_gold", 50), 10, g.GOLD))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var stock: Dictionary = _shop_period()
	var stock_cards: Array = stock.cards
	for i in stock_cards.size():
		var card: Dictionary = stock_cards[i]
		var owned: int = int(g.profile.collection.get(card.id, 0))
		var price := _shop_price(card, owned)
		var on_sale: bool = i == int(stock.sale_index)
		if on_sale: price = maxi(5, int(round(float(price) * 0.7 / 5.0)) * 5)
		grid.add_child(_shop_card_tile(card, price, on_sale))

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

	# 4. Carved-out space in the lower-middle portion for card info
	var info_box := PanelContainer.new()
	info_box.position = Vector2(8, 86)
	info_box.custom_minimum_size = Vector2(160, 138)
	info_box.size = info_box.custom_minimum_size
	var box_style := g._panel(Color(0.06, 0.12, 0.16, 0.90), 8, border_color)
	# Slender border g.overlay margin
	box_style.content_margin_left = 12; box_style.content_margin_right = 12
	box_style.content_margin_top = 4; box_style.content_margin_bottom = 4
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	info_box.add_child(stack)

	stack.add_child(g._label(g.content.text(card.nameKey, g.lang), 12, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(g._label(g._kind_element_line(card), 8, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := g._label(g._card_description(card), 8, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.custom_minimum_size.y = 24
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
	buy.custom_minimum_size.y = 32
	buy.focus_mode = Control.FOCUS_NONE
	buy.text = "%s  ◆%d" % [g.t("ui.shop_buy"), price]
	if g.font_cjk: buy.add_theme_font_override("font", g.font_cjk)
	buy.add_theme_font_size_override("font_size", 12)
	buy.add_theme_color_override("font_color", Color("0f1d10") if can_afford else Color("c78b7f"))
	buy.add_theme_color_override("font_hover_color", Color("0f1d10"))
	buy.add_theme_stylebox_override("normal", g._panel(g.GOLD if can_afford else Color("3a2723"), 8, g.GOLD if can_afford else Color("6b4038")))
	buy.add_theme_stylebox_override("hover", g._panel(g.GOLD.lightened(0.15) if can_afford else Color("46302b"), 8, Color.WHITE))
	buy.add_theme_stylebox_override("pressed", g._panel(g.GOLD.darkened(0.2), 8, g.EMBER))
	buy.add_theme_stylebox_override("disabled", g._panel(Color("2a2320"), 8, Color("53403a")))
	buy.disabled = not can_afford
	buy.pressed.connect(func(): _buy_card_with_feedback(btn, card, price))
	price_row.add_child(buy)
	if owned > 0 and not on_sale:
		price_row.add_child(g._label(g.tf("ui.shop_next_price", _shop_price(card, owned + 1)), 8, Color("5e7278"), HORIZONTAL_ALIGNMENT_CENTER))

	return btn

func _buy_potion() -> void:
	if int(g.profile.gold) < 30: g._toast(g.t("ui.shop_no_gold")); return
	g.profile.gold -= 30
	g.profile.health = mini(60, int(g.profile.health) + 20)
	SpiritSave.write(g.profile)
	g._advance_quest("shop_purchase", 1)
	show_shop()

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
		if imported_cards.size() < 15:
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

	var border_color: Color = accent if in_deck > 0 else Color("24373d")
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
	g._apply_card_foil(art, str(card.get("rarity", "Common")), int(g.profile.upgrades.get(card.id, 0)) > 0)
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
	info_box.position = Vector2(8, 86)
	info_box.custom_minimum_size = Vector2(160, 138)
	info_box.size = info_box.custom_minimum_size
	var box_style := g._panel(Color(0.06, 0.12, 0.16, 0.90), 8, border_color)
	# Slender border g.overlay margin
	box_style.content_margin_left = 12; box_style.content_margin_right = 12
	box_style.content_margin_top = 4; box_style.content_margin_bottom = 4
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	info_box.add_child(stack)

	var up_lvl: int = int(g.profile.upgrades.get(card.id, 0))
	stack.add_child(g._label(g.content.text(card.nameKey, g.lang) + (" +%d" % up_lvl if up_lvl > 0 else ""), 12, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(g._label(g._kind_element_line(card), 8, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var desc := g._label(g._card_description(card), 8, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
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
			"shield": score += float(effect.amount) * 1.6
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
	for entry in tabs:
		var id: String = entry[0]
		var is_active: bool = id == active
		var btn := Button.new()
		btn.text = entry[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 44
		btn.focus_mode = Control.FOCUS_NONE
		if g.font_cjk: btn.add_theme_font_override("font", g.font_cjk)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color("10242b") if is_active else g.MUTED)
		btn.add_theme_color_override("font_hover_color", Color("10242b") if is_active else g.TEXT)
		var active_style := g._panel(g.JADE, 22)
		btn.add_theme_stylebox_override("normal", active_style if is_active else StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", active_style if is_active else g._panel(Color(1, 1, 1, 0.06), 22))
		btn.add_theme_stylebox_override("pressed", g._panel(g.JADE.darkened(0.1), 22) if is_active else g._panel(Color(1, 1, 1, 0.1), 22))
		btn.pressed.connect(func(): on_pick.call(id))
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

	if g.loadout_tab == "equipment": _build_equipment_tab(list)
	else: _build_rune_tab(list)

func _build_equipment_tab(list: VBoxContainer) -> void:
	list.add_child(g._label(g.t("ui.loadout_cur_equip"), 13, g.JADE))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	list.add_child(slots)
	for slot in ["weapon", "armor", "charm"]:
		var item := g.content.equipment(g.profile.equipment_slots.get(slot, ""))
		var filled: bool = not item.is_empty()
		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 96)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", g._panel(Color("16333a") if filled else Color("101f24"), 12, g.GOLD if filled else Color("2a3d42")))
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 2)
		card.add_child(stack)
		var badge_row := HBoxContainer.new()
		badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_child(badge_row)
		badge_row.add_child(g._equip_icon_badge(item, g.GOLD, 38) if filled else g._icon_badge("＋", Color("3c5057"), 38, 18))
		stack.add_child(g._label(g.t("ui.slot_%s" % slot), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(g._label(g._equip_name(item) if filled else g.t("ui.loadout_empty"), 11, g.TEXT if filled else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		slots.add_child(card)

	list.add_child(g._label(g.t("ui.loadout_collection"), 13, g.JADE))
	for item in SpiritContent.EQUIPMENT:
		var owned: bool = g.profile.equipment_owned.has(item.id)
		var equipped: bool = g.profile.equipment_slots.get(item.slot, "") == item.id
		var status_text := g.t("ui.loadout_unequip") if equipped else (g.t("ui.loadout_equip") if owned else g.t("ui.loadout_unobtained"))
		var accent: Color = g.JADE if equipped else (g.GOLD if owned else Color("3c5057"))

		var btn := Button.new()
		btn.custom_minimum_size.y = 72
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("normal", g._panel(Color("15383a") if equipped else Color("13282e"), 12, accent))
		btn.add_theme_stylebox_override("hover", g._panel(Color("1b4544") if equipped else Color("17333a"), 12, accent))
		btn.add_theme_stylebox_override("pressed", g._panel(Color("102c2e"), 12, accent))
		btn.add_theme_stylebox_override("disabled", g._panel(Color("0e191d"), 12, Color("243135")))
		btn.disabled = not owned
		btn.pressed.connect(func(): g._equip(item))
		list.add_child(btn)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(row)

		var badge_holder := CenterContainer.new()
		badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_holder.add_child(g._equip_icon_badge(item, accent, 44))
		row.add_child(badge_holder)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(texts)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(title_row)
		title_row.add_child(g._label(g._equip_name(item), 13, g.TEXT if owned else g.MUTED))
		title_row.add_child(g._label("· %s" % g.t("ui.slot_%s" % item.slot), 9, g.MUTED))
		var detail := g._label(g._equip_detail(item), 9, g.JADE if owned else Color("445559"), HORIZONTAL_ALIGNMENT_LEFT, true)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(detail)

		var status := g._label(status_text, 10, accent, HORIZONTAL_ALIGNMENT_RIGHT)
		status.custom_minimum_size.x = 48
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(status)

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
		btn.pressed.connect(func(): g.selected_rune = "" if is_selected else rune.id; show_loadout())
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

