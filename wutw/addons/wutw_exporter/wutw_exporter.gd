@tool
class_name WUTWExporter
extends EditorPlugin

var exporter = ExportPlugin.new()

func _enter_tree() -> void:
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)

class ExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return 'World Upon The Wind Exporter'

	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		# Fetch and export build version metadata.
		var build_metadata = BuildMetadata.new()
		build_metadata.git_commit_hash = _run_git('rev-parse --short HEAD', false)
		build_metadata.git_tag = _run_git('tag --points-at HEAD')
		if ResourceSaver.save(build_metadata, BuildMetadata.EXPORT_PATH) != OK:
			push_error('Failed to save build metadata file. Make sure the path is valid.')
		# Update project build number.
		var version_regex := RegEx.create_from_string(r'\d+(\.\d+){0,3}')
		var version_match := version_regex.search(build_metadata.git_tag)
		if version_match:
			ProjectSettings.set_setting('application/config/version', version_match.get_string(0))
			ProjectSettings.save()

	func _run_git(command: String, allow_empty: bool = true) -> String:
		var git_output: Array[String] = []
		OS.execute('git', PackedStringArray(command.split(' ')), git_output)
		if git_output.is_empty() or git_output[0].is_empty():
			if not allow_empty:
				push_error('Failed to run git command. Make sure you have git installed and project is inside valid git directory.')
			return ''
		else:
			return git_output[0].strip_edges()
