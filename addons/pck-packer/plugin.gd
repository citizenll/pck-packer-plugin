tool
extends EditorPlugin

var plugin:EditorExportPlugin
var editor:Control
func _enter_tree():
	var Editor = preload("res://addons/pck_packer/editor.tscn")
	editor = Editor.instance()
	editor.plugin = self
	add_control_to_bottom_panel(editor, "PckPacker")
	

func _exit_tree():
#	remove_export_plugin(plugin)
	remove_control_from_bottom_panel(editor)
	editor.queue_free()
