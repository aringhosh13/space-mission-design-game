extends CanvasLayer
## Player-facing reference, available in every scene; preserves the previous pause state.
const SECTIONS = [
	["Start here", "Your first expedition", [
		["1. Plan", "Run Play First Light.cmd and choose Begin First Light. Watch or skip the problem briefing."],
		["2. Pick a route", "In the NASA lab, click a target, compare routes and select Present This Plan when feasible."],
		["3. Land", "In flight press L when the Moon is in approach range. T enables landing assist."],
		["4. Investigate", "Follow the objective and minimap. Drive near a signal, press E to scan, then Q to sample."],
		["5. Follow the story", "New objectives appear in the centre, then move to the top. Return evidence to the ship."],
		["Need a reminder?", "F1 opens this guide anywhere. F8 opens sound/music controls. Both pause the game."],
	]],
	["Rover", "Driving on the Moon or Mars", [
		["W / A / S / D or arrows", "Drive relative to the camera."],
		["Hold right mouse + move", "Look around / rotate the camera."],
		["Mouse wheel", "Zoom the following camera in or out."],
		["E", "Open the scanner within 6 m of a signal."],
		["Q", "Open the core sampler at a scanned site; drill payload required."],
		["R", "Recharge using your installed power system. Solar needs sunlight; shelter supplies full charges."],
		["T", "Transmit scientific data. Mars core science still requires the physical return trip."],
		["B", "Review the site and deploy a research station."],
		["G / H", "G boards within the ship's shown range. H repairs for free at the ship or Mars shelter."],
		["M / P", "M opens the Moon atlas on lunar surfaces. P opens the NASA route-planning lab."],
		["Escape", "Pause menu: resume, recover to a checkpoint, end the mission or quit."],
	]],
	["Instruments", "Scanner, sampler and station", [
		["Scanner: Left / Right", "Tune the cursor to the green signal peak. You can also drag the slider."],
		["Scanner: hold Space", "Hold a stable lock to complete the scan. You can hold the operation button with the mouse."],
		["Sampler: Left / Right", "Adjust feed. Keep it in the green 25–70 band; the slider works too."],
		["Sampler: hold Space", "Operate the drill. Release to cool it. High heat pauses progress without destroying the core."],
		["A", "Toggle scanner/drill assist. The same energy costs and evidence rules apply."],
		["Station: Enter / Deploy", "Commit after checking sunlight, energy cost and the return-power estimate."],
		["Result: Enter / Continue", "Read the finding and suggested next step, then return to driving."],
		["Escape", "Cancel or close. Cancelling before completion spends no new action energy."],
		["What these controls mean", "These are simplified game controls, not actual NASA instrument operating procedures."],
	]],
	["Spaceflight", "Flying between destinations", [
		["W / Up", "Apply forward thrust; consumes ship fuel."],
		["S / Down", "Brake with the ship's thrusters; also consumes fuel."],
		["A / D or Left / Right", "Steer left or right."],
		["R / F", "Pitch up / down. R is pitch here, not rover recharge."],
		["Hold C", "Align toward the selected target. You still control thrust and braking."],
		["Tab", "Cycle destinations. Earth is a landmark, not a playable landing destination."],
		["L", "Start final descent when close enough and slow enough. Read the approach guidance."],
		["Take off / disembark", "After boarding, use the ship menu's destination or Deploy the Rover buttons."],
		["Escape", "Pause, recover or end the expedition from the menu."],
	]],
	["Landing", "Final descent / touchdown", [
		["W / S", "Increase / decrease the throttle lever. The throttle stays where you set it."],
		["X", "Cut throttle to zero."],
		["Arrows or I / J / K / L", "Move over the pad with side thrusters. Up / I is north on the alignment display."],
		["T", "Toggle landing assist. It handles controls you leave alone."],
		["R after a missed landing", "Retry from the approach point without a second descent-fuel charge."],
		["Watch the HUD", "Reduce downward speed and sideways drift; stay inside the pad's safe zone."],
		["Touchdown", "The game transitions to the rover automatically after a safe landing."],
		["Escape", "Open the pause menu."],
	]],
	["Planning", "Route lab and Moon atlas", [
		["Lab: left-click map", "Set the study target."],
		["Lab: Shift + left-click", "Set the study start / base."],
		["Lab: menus and fields", "Choose Moon or Mars and adjust slope, battery and reserve assumptions."],
		["Compare Routes", "Compare distance- and energy-weighted routes, including the return leg."],
		["Present This Plan", "Explain a feasible candidate. During campaign onboarding this starts the expedition afterward."],
		["Export GeoJSON", "Save a candidate route; the game displays its save location."],
		["Atlas: drag / wheel", "Rotate / zoom the Moon globe. Click to place a planning marker."],
		["P / Escape in the lab", "Return to the previous screen. M / Escape closes the Moon atlas."],
		["Study only", "Planning picks do not move the rover, award discoveries or provide flight-approved commands."],
	]],
	["Menus", "Help, audio, story and recovery", [
		["F1 / Controls button", "Open or close this guide. Escape also closes it."],
		["F8 / Audio button", "Music/effects volume and mute. Your settings are saved locally."],
		["Space / Enter / Escape", "Skip a cinematic. While a tool or guide is open, its own controls take priority."],
		["Enter during a briefing", "Begin / dismiss the Mission Control card."],
		["Escape during gameplay", "Pause menu. Choose Recover to Last Checkpoint if stuck; progress and evidence are retained."],
		["End the expedition", "Use the pause or ship menu. The debrief shows actual completed objectives and returned evidence."],
		["After all 12 objectives", "The report unlocks the optional historical Artemis I Earth-return explanation."],
		["Context matters", "R recharges a rover, pitches the ship in flight, and retries a failed descent."],
	]],
]
var overlay: Control
var tabs: TabContainer
var is_open: bool = false
var _previous_pause: bool = false
var _previous_focus: WeakRef
var _previous_mouse: Input.MouseMode

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var access := Button.new()
	access.text = "CONTROLS [F1]"
	access.position = Vector2(1048, 684)
	access.size = Vector2(110, 28)
	access.add_theme_font_size_override("font_size", 12)
	access.pressed.connect(toggle)
	add_child(access)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.012, 0.02, 0.985)
	overlay.add_child(shade)
	var heading := Label.new()
	heading.text = "YOUR EXPEDITION / CONTROLS GUIDE"
	heading.position = Vector2(140, 62)
	heading.add_theme_font_size_override("font_size", 27)
	overlay.add_child(heading)
	var hint := Label.new()
	hint.text = "The game is paused. Choose a tab for your current activity.  F1 / Escape returns to the game."
	hint.position = Vector2(140, 105)
	hint.add_theme_font_size_override("font_size", 15)
	overlay.add_child(hint)
	tabs = TabContainer.new()
	tabs.position = Vector2(140, 148)
	tabs.size = Vector2(1000, 474)
	tabs.add_theme_font_size_override("font_size", 15)
	overlay.add_child(tabs)
	for section in SECTIONS:
		var scroll := ScrollContainer.new()
		scroll.name = section[0]
		tabs.add_child(scroll)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		scroll.add_child(column)
		var title := Label.new()
		title.text = section[1]
		title.add_theme_font_size_override("font_size", 23)
		title.add_theme_color_override("font_color", Color("f3c582"))
		column.add_child(title)
		for row in section[2]:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 18)
			column.add_child(line)
			var key := Label.new()
			key.text = row[0]
			key.custom_minimum_size.x = 230
			key.add_theme_font_size_override("font_size", 15)
			key.add_theme_color_override("font_color", Color("a7e2cb"))
			line.add_child(key)
			var meaning := Label.new()
			meaning.text = row[1]
			meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			meaning.custom_minimum_size.x = 708
			meaning.add_theme_font_size_override("font_size", 15)
			line.add_child(meaning)
	var close := Button.new()
	close.text = "RETURN TO GAME  [F1 / ESC]"
	close.position = Vector2(140, 646)
	close.size = Vector2(1000, 38)
	close.pressed.connect(close_guide)
	overlay.add_child(close)
	overlay.visible = false

func context_tab() -> int:
	for game in get_tree().root.get_children():
		if "study_planner" in game and game.study_planner != null and game.study_planner.is_open(): return 5
		if not "current" in game or game.current == null: continue
		var scene: Node = game.current
		if "operation" in scene and scene.operation != null and scene.operation.is_open(): return 2
		if "planner" in scene and scene.planner != null and scene.planner.is_open(): return 5
		if scene.has_method("read_input"): return 4
		if scene.has_method("try_land"): return 3
		if scene.has_method("try_board"): return 1
	return 0

func toggle() -> void:
	if is_open: close_guide()
	else: open_guide()
func open_guide() -> void:
	if is_open: return
	var audio: Node = get_node_or_null("/root/Soundscape")
	if audio and audio.settings_open: audio.toggle_settings()
	_previous_pause = get_tree().paused
	_previous_mouse = Input.mouse_mode
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	is_open = true
	overlay.visible = true
	tabs.current_tab = context_tab()
	tabs.get_tab_bar().grab_focus()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if audio:
		for id in audio.loops: audio.level(id, 0)
func close_guide() -> void:
	if not is_open: return
	is_open = false
	overlay.visible = false
	get_tree().paused = _previous_pause
	Input.mouse_mode = _previous_mouse if _previous_mouse != Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else Input.MOUSE_MODE_VISIBLE
	if _previous_focus != null:
		var focus: Control = _previous_focus.get_ref() as Control
		if focus != null and focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1 or (is_open and event.physical_keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			toggle()
