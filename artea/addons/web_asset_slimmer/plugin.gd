@tool
extends EditorPlugin

var _exporter: EditorExportPlugin


func _enter_tree() -> void:
	_exporter = preload("res://addons/web_asset_slimmer/web_asset_export.gd").new()
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null
