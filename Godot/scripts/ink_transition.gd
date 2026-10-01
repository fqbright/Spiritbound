extends Control
class_name InkTransition

# Ink-wash Chapter / Realm Transition Curtain
# Renders an ancient parchment calligraphic reveal with ink-wash brushwork.

var chapter_num: int = 1
var chapter_title: String = "青云初试"
var realm_sub: String = "天道浩瀚 · 踏破虚空"

func _init(chap: int = 1, title: String = "", sub: String = "") -> void:
	chapter_num = chap
	if not title.is_empty(): chapter_title = title
	if not sub.is_empty(): realm_sub = sub
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 600

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.08, 0.1, 0.96)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# Ancient Seal Top
	var seal_lbl := Label.new()
	seal_lbl.text = "✦  天 道 浩 瀚  ✦"
	seal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_lbl.add_theme_font_size_override("font_size", 14)
	seal_lbl.add_theme_color_override("font_color", Color("ffd700"))
	vbox.add_child(seal_lbl)

	# Chapter Heading
	var title_lbl := Label.new()
	title_lbl.text = "第 %d 章 · %s" % [chapter_num, chapter_title]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color("fef08a"))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.95))
	title_lbl.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title_lbl)

	# Calligraphic Subtitle
	var sub_lbl := Label.new()
	sub_lbl.text = realm_sub
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color("94a3b8"))
	vbox.add_child(sub_lbl)

	# Smooth in-and-out curtain animation
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
