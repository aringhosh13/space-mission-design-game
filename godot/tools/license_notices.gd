extends SceneTree
## Writes notices directly from the engine distribution used for this build.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass an output path after --")
		quit(1)
		return
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write engine notices")
		quit(1)
		return
	output.store_string("BLUE HORIZON — GODOT ENGINE AND THIRD-PARTY NOTICES\n\n")
	output.store_string(Engine.get_license_text() + "\n\n")
	output.store_string(JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n")
	var licenses: Dictionary = Engine.get_license_info()
	for name in licenses:
		output.store_string(str(name) + "\n" + str(licenses[name]) + "\n\n")
	output.close()
	print("Engine notices written")
	quit(0)
