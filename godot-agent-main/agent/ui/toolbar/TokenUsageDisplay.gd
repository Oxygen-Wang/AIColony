class_name TokenUsageDisplay
extends RefCounted

## Toolbar badge — current context length from the latest LLM request (left of the skill toggle).
##
## Shows [member OpenAiUsage.prompt_tokens] from the last API call (input context size, not session total).
## Panel matches [method AgentColors.theme_selection_bg]. Label text uses theme accent until
## [constant THRESHOLD_WARN], then a traffic-light scale against [constant MAX_CONTEXT_TOKENS]:
##
## ```
## 50% ── yellow ──► 75% ── orange ──► 90% ── red
## ```

## Reference context window for badge color / percentage. Update when switching to a model with a different limit (e.g. GPT-4o 128k vs DeepSeek V4 1M).
const MAX_CONTEXT_TOKENS := 1_000_000
const THRESHOLD_WARN := 0.50
const THRESHOLD_CAUTION := 0.75
const THRESHOLD_CRITICAL := 0.90

var wrap: PanelContainer
var label: Label


func setup(p_wrap: PanelContainer) -> void:
	wrap = p_wrap
	label = wrap.get_child(0) as Label
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	AgentEvents.events.theme_changed.connect(apply_theme)
	AgentEvents.events.theme_color_changed.connect(apply_theme)
	AgentEvents.events.session_selected.connect(refresh)
	AgentEvents.events.message_complete.connect(on_message_complete)
	apply_theme()
	pass


func on_message_complete(session_id: int, _usage: OpenAiUsage) -> void:
	if session_id == AgentSessionManager.active_session_id:
		refresh()
	pass


func refresh(_session_id: int = AgentSessionManager.active_session_id) -> void:
	if label == null or wrap == null:
		return
	var session_id := AgentSessionManager.active_session_id
	if session_id == AgentSessionManager.INVALID_SESSION_ID:
		return
	var session := AgentSessionStore.load_session(session_id)
	if session == null:
		return
	var usage := session.usage
	var n := usage.prompt_tokens
	var ratio := token_ratio(n)
	label.text = StringUtils.format("{} tokens", format_count(n))
	wrap.tooltip_text = StringUtils.format(
		"Context: {} ({}%) · Completion: {} · Total: {} (last request)",
		n,
		int(round(ratio * 100.0)),
		usage.completion_tokens,
		usage.total_tokens
	)
	label.add_theme_color_override("font_color", text_color_for_tokens(n))
	var panel := StyleBoxFlat.new()
	panel.bg_color = AgentColors.theme_selection_bg()
	panel.border_color = AgentColors.toolbar_border
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	wrap.add_theme_stylebox_override("panel", panel)
	pass


func apply_theme() -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", 12)
	refresh()
	pass


## Compact badge text: 999 → "999", 1500 → "1.5k", 12000 → "12k", 2M+ → "2M".
static func format_count(n: int) -> String:
	if n >= 1_000_000:
		return StringUtils.format("{}M", n / 1_000_000)
	if n >= 10_000:
		return StringUtils.format("{}k", n / 1000)
	if n >= 1000:
		return StringUtils.format("{}k", snappedf(float(n) / 1000.0, 0.1))
	return str(n)


static func token_ratio(n: int) -> float:
	return clampf(float(n) / float(MAX_CONTEXT_TOKENS), 0.0, 1.0)


static func text_color_for_tokens(n: int) -> Color:
	var ratio := token_ratio(n)
	if ratio >= THRESHOLD_CRITICAL:
		return AgentColors.error
	if ratio >= THRESHOLD_CAUTION:
		return AgentColors.file_tool_title
	if ratio >= THRESHOLD_WARN:
		return Color(0.94, 0.84, 0.35) if AgentColors.is_dark() else Color("#CA8A04")
	return AgentColors.theme_accent_solid()
