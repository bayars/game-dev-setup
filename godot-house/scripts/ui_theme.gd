class_name UiTheme
extends RefCounted
## One look for every HUD element: palette, type sizes, rounded panels, buttons, keycaps.
## Type scale: 13 caption, 16 body, 20 title, 28 headline. Spacing steps: 4, 8, 12, 16, 24.

const BG := Color(0.07, 0.08, 0.10, 0.86)        # panels over the 3D scene
const BG_SOFT := Color(0.13, 0.14, 0.17, 0.92)   # rows, slots, chips
const BG_HOVER := Color(0.2, 0.21, 0.25, 0.95)
const LINE := Color(1, 1, 1, 0.08)
const TEXT := Color(0.94, 0.93, 0.9)
const MUTED := Color(0.64, 0.66, 0.7)
const ACCENT := Color(1.0, 0.76, 0.36)           # amber: the one thing to look at
const OK := Color(0.47, 0.82, 0.52)
const DANGER := Color(0.96, 0.43, 0.36)
const NICO := Color(0.36, 0.76, 0.82)
const TOMAS := Color(0.93, 0.47, 0.4)
const RADIUS := 10

const CAPTION := 13
const BODY := 16
const TITLE := 20
const HEADLINE := 28

static func person_color(who: String) -> Color:
	match who:
		"Nico": return NICO
		"Tomas": return TOMAS
		"Linda": return Color(0.78, 0.64, 0.95)
		"Daniel": return Color(0.7, 0.9, 0.5)
		"Rose": return Color(0.95, 0.85, 0.6)
	return TEXT

static func panel(bg := BG, radius := RADIUS, margin := 12, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	if border.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = border
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = BODY
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	var normal := panel(BG_SOFT, 8, 8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BG_HOVER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT.darkened(0.55)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.1, 0.1, 0.12, 0.6)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", BODY)
	var bar_bg := panel(Color(1, 1, 1, 0.08), 4, 0)
	var bar_fill := panel(ACCENT, 4, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	return t

static func label(text: String, size := BODY, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## A key drawn as a small rounded cap ("E", "Tab", "1").
static func keycap(key: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := panel(Color(0.92, 0.9, 0.86), 5, 0)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 2
	s.border_width_bottom = 3
	s.border_color = Color(0.55, 0.53, 0.5)
	p.add_theme_stylebox_override("panel", s)
	var l := label(key, CAPTION + 1, Color(0.12, 0.12, 0.14))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## "[key] action" as one row.
static func key_hint(key: String, action: String, size := BODY) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := keycap(key)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var l := label(action, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row

## A filled dot used as a status mark or a person's colour.
static func dot(color: Color, size := 10) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", panel(color, size / 2, 0))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
