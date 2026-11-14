extends SceneTree
## Native simulation test runner. Runs every test_*.gd in this folder (and folders passed after --).
##   godot --headless --path godot --script res://tests/simulation/run_tests.gd
##   godot --headless --path godot --script res://tests/simulation/run_tests.gd -- res://tests/spaceflight
## Script runtime errors raised during a test are captured through a Logger and count as failures,
## so a crashing test cannot pass silently.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		errors.append("%s:%d in %s(): %s %s" % [file, line, function, code, rationale])
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func take() -> Array[String]:
		mutex.lock()
		var result: Array[String] = errors.duplicate()
		errors.clear()
		mutex.unlock()
		return result

func _initialize() -> void:
	_run.call_deferred()

func _test_files(folder: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null: return files
	for file_name in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			files.append(folder.path_join(file_name))
	files.sort()
	return files

func _run() -> void:
	var folders: Array[String] = ["res://tests/simulation"]
	for arg in OS.get_cmdline_user_args(): folders.append(arg)
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var total_tests: int = 0
	var total_assertions: int = 0
	var failures: Array[String] = []
	for folder in folders:
		for path in _test_files(folder):
			var script: GDScript = load(path)
			if script == null:
				failures.append("%s: failed to load" % path)
				continue
			var suite = script.new()
			var names: Array[String] = []
			for method in script.get_script_method_list():
				if str(method.name).begins_with("test_"): names.append(str(method.name))
			for test_name in names:
				suite.current_test = "%s::%s" % [path.get_file(), test_name]
				catcher.take()
				suite.call(test_name)
				for error in catcher.take(): failures.append("%s: runtime error %s" % [suite.current_test, error])
				total_tests += 1
			total_assertions += suite.assertions
			failures.append_array(suite.failures)
	OS.remove_logger(catcher)
	for failure in failures: print("FAIL  ", failure)
	print("%s  %d tests, %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", total_tests, total_assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
