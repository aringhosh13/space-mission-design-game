extends SceneTree
## Keep the printable guide in sync with the actual in-game reference.
const Guide = preload("res://scripts/controls_guide.gd")
func _initialize() -> void:
	var lines: PackedStringArray = ["# Blue Horizon player controls", "", "Open **Controls [F1]** anywhere. The guide pauses gameplay; F1 or Escape returns to your previous screen.", "", "Each new objective appears large in the centre, holds briefly, then fades/moves to a compact reminder at the top. Announcements wait behind briefings, tool results and menus.", ""]
	for section in Guide.SECTIONS:
		lines.append("## " + str(section[1]))
		lines.append("")
		lines.append("| Press / choose | What happens |")
		lines.append("| --- | --- |")
		for row in section[2]: lines.append("| %s | %s |" % [str(row[0]).replace("|", "\\|"), str(row[1]).replace("|", "\\|")])
		lines.append("")
	var file := FileAccess.open("res://CONTROLS.md", FileAccess.WRITE)
	if file == null:
		push_error("Could not export the player controls guide")
		quit(1)
		return
	file.store_string("\n".join(lines))
	file.close()
	print("PASS: exported matching player controls guide")
	quit()
