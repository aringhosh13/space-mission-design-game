extends RefCounted
static func cue(where: Node, id: String) -> void:
	var audio: Node = where.get_node_or_null("/root/Soundscape")
	if audio: audio.cue(id)
static func tool(where: Node, id: String) -> void:
	var audio: Node = where.get_node_or_null("/root/Soundscape")
	if audio: audio.set_tool(id)
