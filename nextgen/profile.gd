extends RefCounted

static func value(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"+key+"="): return arg.trim_prefix("--"+key+"=")
	return fallback
