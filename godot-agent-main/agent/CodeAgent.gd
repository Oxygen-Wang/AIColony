extends Control

## CodeAgent main app — multi-session chat UI.

@onready var toolbar_panel: PanelContainer = $Root/Toolbar
@onready var toolbar_title: Label = $Root/Toolbar/ToolbarRow/Title
@onready var sidebar_panel: PanelContainer = $Root/Body/Sidebar
@onready var chat_area_panel: Panel = $Root/Body/ChatArea
@onready var session_list_root: VBoxContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList
@onready var pinned_header: Label = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/PinnedHeader
@onready var pinned_list: VBoxContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/PinnedList
@onready var pinned_separator: HSeparator = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/PinnedSeparator
@onready var normal_header: Label = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/NormalHeader
@onready var normal_list: VBoxContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/NormalList
@onready var new_session_button: Button = $Root/Body/Sidebar/SidebarVBox/NewSessionButton
@onready var chat_scroll: ScrollContainer = $Root/Body/ChatArea/ChatScroll
@onready var chat_host: MarginContainer = $Root/Body/ChatArea/ChatScroll/ChatMargin
@onready var token_usage_wrap: PanelContainer = $Root/Toolbar/ToolbarRow/TokenUsageWrap
@onready var jarvis_toggle_button: Button = $Root/Toolbar/ToolbarRow/JarvisToggleWrap/JarvisToggleButton
@onready var skill_toggle_button: Button = $Root/Toolbar/ToolbarRow/SkillToggleWrap/SkillToggleButton
@onready var markdown_toggle_button: Button = $Root/Toolbar/ToolbarRow/MarkdownToggleWrap/MarkdownToggleButton
@onready var input_bar: Control = $Root/Body/ChatArea/InputBar
@onready var input_wrap: PanelContainer = $Root/Body/ChatArea/InputBar/InputWrap
@onready var input_inner: Control = $Root/Body/ChatArea/InputBar/InputWrap/InputInner
@onready var input_field: TextEdit = $Root/Body/ChatArea/InputBar/InputWrap/InputInner/InputField
@onready var send_button: Button = $Root/Body/ChatArea/InputBar/InputWrap/InputInner/SendButton
@onready var project_button: Button = $Root/Toolbar/ToolbarRow/ProjectButton
@onready var log_button: Button = $Root/Toolbar/ToolbarRow/LogButtonWrap/LogButton
@onready var theme_color_select: Button = $Root/Toolbar/ToolbarRow/ThemeColorSelectWrap/ThemeColorSelect
@onready var theme_toggle_button: Button = $Root/Toolbar/ToolbarRow/ThemeToggleWrap/ThemeToggleButton
@onready var workspace_dialog: FileDialog = $WorkspaceDialog

var toolbar: AgentToolbar = AgentToolbar.new()
var chat_area: ChatArea = ChatArea.new()
var chat_input: AgentChatInput = AgentChatInput.new()
var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select_ctrl: ThemeColorSelect = ThemeColorSelect.new()
var jarvis_toggle: JarvisToggle = JarvisToggle.new()
var skill_bubble: SkillBubble = SkillBubble.new()
var token_usage_display: TokenUsageDisplay = TokenUsageDisplay.new()
var markdown_toggle: MarkdownToggle = MarkdownToggle.new()
var session_sidebar: AgentSessionSidebar = AgentSessionSidebar.new()
var chat_view: AgentChatView = AgentChatView.new()


func _ready() -> void:
	AgentColors.load_saved_theme()
	toolbar.setup(toolbar_panel, toolbar_title, project_button)
	session_sidebar.setup(
		session_list_root,
		pinned_header,
		pinned_list,
		pinned_separator,
		normal_header,
		normal_list,
		new_session_button,
		sidebar_panel
	)
	chat_area.setup(chat_area_panel, self)
	token_usage_display.setup(token_usage_wrap)
	jarvis_toggle.setup(jarvis_toggle_button)
	skill_bubble.setup_toggle(skill_toggle_button)
	markdown_toggle.setup(markdown_toggle_button)
	chat_view.setup(chat_scroll, chat_host)

	chat_input.setup(input_bar, input_wrap, input_inner, input_field, send_button)
	theme_color_select_ctrl.setup(theme_color_select)
	theme_toggle.setup(theme_toggle_button)
	style_log_button()
	log_button.pressed.connect(on_log_pressed)
	AgentEvents.events.theme_changed.connect(on_log_theme_changed)
	AgentEvents.events.theme_color_changed.connect(on_log_theme_changed)

	AgentSessionManager.load_from_disk()
	session_sidebar.rebuild()
	refresh_workspace_button()
	project_button.pressed.connect(on_project_button_pressed)
	workspace_dialog.dir_selected.connect(on_workspace_selected)
	pass


func refresh_workspace_button() -> void:
	var workspace_root := AgentWorkspace.get_root()
	project_button.text = workspace_root
	if DirAccess.dir_exists_absolute(workspace_root):
		workspace_dialog.current_dir = workspace_root
	pass


func on_project_button_pressed() -> void:
	var workspace_root := AgentWorkspace.get_root()
	if DirAccess.dir_exists_absolute(workspace_root):
		workspace_dialog.current_dir = workspace_root
	workspace_dialog.popup_centered()
	pass


func on_workspace_selected(path: String) -> void:
	if not AgentWorkspace.set_root(path):
		return
	AgentSessionManager.load_from_disk()
	session_sidebar.rebuild()
	refresh_workspace_button()
	pass


func style_log_button() -> void:
	AgentToolbarButton.style(log_button, "View system log")
	pass


func on_log_theme_changed() -> void:
	style_log_button()
	pass


func on_log_pressed() -> void:
	LogWindow.show_log_window(128, 70, 80)
	pass
