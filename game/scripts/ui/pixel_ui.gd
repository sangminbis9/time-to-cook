class_name PixelUi
extends RefCounted
## 게임 전체에서 공유하는 따뜻한 목재·크림 픽셀 UI 테마.
## 텍스트는 폰트로 선명하게 유지하고, 패널·버튼·기능 아이콘만 아트 에셋을 쓴다.

const PANEL_TEXTURE: Texture2D = preload("res://assets/sprites/ui_panel.png")
const BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui_button.png")
const ICON_STORE: Texture2D = preload("res://assets/sprites/ui_icon_store.png")
const ICON_STAFF: Texture2D = preload("res://assets/sprites/ui_icon_staff.png")
const ICON_MANAGE: Texture2D = preload("res://assets/sprites/ui_icon_manage.png")
const ICON_CHARACTER: Texture2D = preload("res://assets/sprites/ui_icon_character.png")
const ICON_RESEARCH: Texture2D = preload("res://assets/sprites/ui_icon_research.png")
const ICON_MAP: Texture2D = preload("res://assets/sprites/ui_icon_map.png")
const ICON_SETTINGS: Texture2D = preload("res://assets/sprites/ui_icon_settings.png")
const ICON_CLOSE: Texture2D = preload("res://assets/sprites/ui_icon_close.png")

const INK: Color = Color("#5a4632")
const CREAM: Color = Color("#f7efd9")
const MUTED_INK: Color = Color("#8c755c")
const MINT: Color = Color("#a8d8c9")
const APRICOT: Color = Color("#eaa06f")

static var _shared_theme: Theme


static func theme() -> Theme:
	if _shared_theme == null:
		_shared_theme = _build_theme()
	return _shared_theme


static func icon(name: StringName) -> Texture2D:
	match name:
		&"store":
			return ICON_STORE
		&"staff":
			return ICON_STAFF
		&"manage":
			return ICON_MANAGE
		&"character":
			return ICON_CHARACTER
		&"research":
			return ICON_RESEARCH
		&"map":
			return ICON_MAP
		&"settings":
			return ICON_SETTINGS
		&"close":
			return ICON_CLOSE
	return null


static func decorate_button(button: Button, icon_name: StringName = &"") -> Button:
	if icon_name != &"":
		button.icon = icon(icon_name)
		button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 16)
	button.add_theme_constant_override("h_separation", 5)
	return button


static func _texture_style(
		texture: Texture2D, margin: float, tint: Color = Color.WHITE
	) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
		style.set_content_margin(side, margin)
	return style


static func _flat_style(
		color: Color, border: Color = INK, width: int = 1
	) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


static func _build_theme() -> Theme:
	var result: Theme = Theme.new()
	result.default_font_size = 11

	var panel: StyleBoxTexture = _texture_style(PANEL_TEXTURE, 7.0)
	result.set_stylebox("panel", "PanelContainer", panel)
	result.set_stylebox("panel", "Panel", panel)

	var normal: StyleBoxTexture = _texture_style(BUTTON_TEXTURE, 6.0)
	var hover: StyleBoxTexture = _texture_style(
		BUTTON_TEXTURE, 6.0, Color(1.08, 1.08, 1.0))
	var pressed: StyleBoxTexture = _texture_style(
		BUTTON_TEXTURE, 6.0, Color(0.83, 0.93, 0.88))
	var disabled: StyleBoxTexture = _texture_style(
		BUTTON_TEXTURE, 6.0, Color(0.62, 0.58, 0.53, 0.8))
	result.set_stylebox("normal", "Button", normal)
	result.set_stylebox("hover", "Button", hover)
	result.set_stylebox("pressed", "Button", pressed)
	result.set_stylebox("focus", "Button", hover)
	result.set_stylebox("disabled", "Button", disabled)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", MUTED_INK)
	result.set_constant("outline_size", "Button", 0)
	result.set_constant("h_separation", "Button", 5)

	result.set_stylebox("normal", "LineEdit", _flat_style(CREAM))
	result.set_stylebox("focus", "LineEdit", _flat_style(Color("#fff9e9"), MINT, 2))
	result.set_stylebox("read_only", "LineEdit", _flat_style(Color("#d7cdb8")))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED_INK)
	result.set_color("caret_color", "LineEdit", INK)

	result.set_stylebox("grabber_area", "HSlider", _flat_style(Color("#d6b37a"), INK, 1))
	result.set_stylebox("grabber_area_highlight", "HSlider", _flat_style(MINT, INK, 1))
	result.set_icon("grabber", "HSlider", ICON_SETTINGS)
	result.set_icon("grabber_highlight", "HSlider", ICON_SETTINGS)

	result.set_color("font_color", "Label", INK)
	result.set_color("font_shadow_color", "Label", Color(1.0, 0.97, 0.88, 0.85))
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 1)

	result.set_stylebox("panel", "TooltipPanel", _flat_style(CREAM, INK, 1))
	result.set_color("font_color", "TooltipLabel", INK)
	return result
