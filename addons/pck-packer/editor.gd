tool
extends Control
var PackItem = preload("res://addons/pck_packer/ui/pack_item.tscn")
onready var pack_item_label = $"%PackItemLabel"
onready var tree_container = $"%VBoxContainer"
onready var tree_item_list = $"%TreeItemList"

var include_files:Tree
var plugin:EditorPlugin = null setget _set_plugin
var presets = []
var current_active_pack_item
enum DefaultFilename { EMPTY, GUESS_FOR_SAVE }
var _path: String
var bundles:ConfigFile = ConfigFile.new()
const SAVED_PATH = "user://export_bundles.cfg"
var file_types = {}

func _ready():
	if not plugin:
		return

	include_files = Tree.new()
	include_files.connect("item_edited", self, "_tree_changed")
	var h_min_width = 250 * plugin.get_editor_interface().get_editor_scale()
	include_files.rect_min_size.x = h_min_width
	include_files.size_flags_horizontal = SIZE_EXPAND_FILL
	include_files.size_flags_vertical = SIZE_EXPAND_FILL
	tree_container.add_child(include_files)
	
	var err = bundles.load(SAVED_PATH)
	if err:
		print("加载配置文件出错",err)


func create_bundle_items():
	for section in bundles.get_sections():
		var item = PackItem.instance()
		item.config = bundles
		item.types = file_types
		item.uuid = bundles.get_value(section, "uuid")
		item.connect("actived", self, "_pack_item_selected")
		item.connect("exported", self, "_export_pack_item")
		item.connect("removed", self, "_remove_pack_item")
		tree_item_list.add_child(item)


func fill_resouce_tree():
	if not include_files:return
	include_files.clear()
	for child in tree_item_list.get_children():
		tree_item_list.remove_child(child)
		child.queue_free()
	var res_system = plugin.get_editor_interface().get_resource_filesystem()
	var root = include_files.create_item()
	fill_tree(res_system.get_filesystem(), root)
	create_bundle_items()


func fill_tree(p_dir:EditorFileSystemDirectory, p_item:TreeItem):
	p_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	p_item.set_icon(0, get_icon("folder", "FileDialog"))
	p_item.set_text(0, p_dir.get_name()+"/")
	p_item.set_editable(0, true)
	p_item.set_metadata(0, p_dir.get_path())
	var used = false
	var checked = true
	
	for i in range(p_dir.get_subdir_count()):
		var subdir = include_files.create_item(p_item)
		if fill_tree(p_dir.get_subdir(i), subdir):
			used = true
			checked = checked && subdir.is_checked(0)
		else:
			subdir.free()
	
	for i in range(p_dir.get_file_count()):
		var type = p_dir.get_file_type(i)
		var file = include_files.create_item(p_item)
		file.set_cell_mode(0,TreeItem.CELL_MODE_CHECK)
		file.set_text(0, p_dir.get_file(i))
		
		var path = p_dir.get_file_path(i)
		file.set_icon(0, get_icon(type, "EditorIcons"))
		file_types[path] = type
		file.set_editable(0, true)
		file.set_checked(0, false)
		file.set_metadata(0, path)
		checked = checked && file.is_checked(0)
		used = true
	p_item.set_checked(0, checked)
	return used


func _on_gui_visibility_changed():
	if not visible:return
	if not is_node_ready():
		yield(self, "ready")
	fill_resouce_tree()


func _tree_changed():
	var item = include_files.get_edited()
	if not item:return
	var path = item.get_metadata(0) as String;
	var added = item.is_checked(0);
	if path.ends_with("/"):
		_check_dir_recursive(item, added);
	else:
		if added:
			presets.append(path);
		else:
			presets.erase(path);
	_refresh_parent_checks(item)


func _check_dir_recursive(p_dir:TreeItem, p_checked:bool):
	var child:TreeItem = p_dir.get_children()
	while child:
		var path = child.get_metadata(0);
		child.set_checked(0, p_checked);
		if path.ends_with("/"):
			_check_dir_recursive(child, p_checked);
		else:
			if p_checked:
				presets.append(path);
			else:
				presets.erase(path);
		child = child.get_next()


func _refresh_parent_checks(p_item:TreeItem):
	var parent = p_item.get_parent();
	if !parent: return
	var checked = true;
	var child:TreeItem = parent.get_children()
	while child:
		checked = checked && child.is_checked(0);
		if !checked:
			break;
		child = child.get_next()
	parent.set_checked(0, checked);
	
	_refresh_parent_checks(parent);


func _set_plugin(v):
	plugin = v
	for child in get_children():
		_hook_plugin(child)


func _hook_plugin(node: Node) -> void:
	if "plugin" in node:
		node.plugin = plugin
	for child in node.get_children():
		_hook_plugin(child)


func _pack_item_selected(item):
	current_active_pack_item = item
	pack_item_label.text = "当前正在编辑:%s" % item.export_pck_name
	for child in tree_item_list.get_children():
		if child == item:continue
		child.unactive_style()


func _popup_confirm(content: String, target, callback: String) -> void:
	var dialog := ConfirmationDialog.new()
	add_child(dialog)
	dialog.dialog_text = content
	dialog.title = ""#translator.t("SFXR Editor")
	dialog.connect("confirmed", target, callback)
	dialog.popup_centered()
	dialog.connect("visibility_changed",dialog,"queue_free")



func _popup_file_dialog(mode: int, target, callback: String, default_filename := DefaultFilename.EMPTY) -> void:
	var dialog := EditorFileDialog.new()
	add_child(dialog)
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.mode = mode
	
	match default_filename:
		DefaultFilename.EMPTY:
			pass
		DefaultFilename.GUESS_FOR_SAVE:
			if _path:
				dialog.current_path = _generate_serial_path(_path)
	
	dialog.add_filter("*.tres; %s" %"pck配置文件")
	dialog.connect("file_selected",target, callback)
	dialog.popup_centered_ratio()
	dialog.connect("visibility_changed", dialog, "queue_free")


func _generate_serial_path(path: String) -> String:
	var directory = Directory.new()
	var state = directory.open(path.get_base_dir())
	if state != OK:
		return path
	
	if not directory.file_exists(path.get_file()):
		return path
	
	var basename := path.get_basename()
	var extension := path.get_extension()
	
	# Extract trailing number.
	var num_string: String
	for i in range(basename.length() - 1, -1, -1):
		var c: String = basename[i]
		if "0" <= c and c <= "9":
			num_string = c + num_string
		else:
			break
	var number := num_string.to_int() if num_string else 0
	var name_string: String = basename.substr(0, basename.length() - num_string.length())
	
	while true:
		number += 1
		var attemp := "%s%d.%s" % [name_string, number, extension]
		if not directory.file_exists(attemp):
			return attemp
	
	return path  # Unreachable


func _on_Load_pressed():
	_popup_file_dialog(EditorFileDialog.MODE_OPEN_FILE, self, "")


func _set_editing_file(path: String) -> int: # Error
	_path = path
	return OK


func _on_Save_pressed():
	if !current_active_pack_item:return
	current_active_pack_item.update_files(presets)
	bundles.save(SAVED_PATH)
	print("保存成功")


func _on_New_pressed():
	var item = PackItem.instance()
	item.config = bundles
	item.types = file_types
	item.connect("actived", self, "_pack_item_selected")
	item.connect("exported", self, "_export_pack_item")
	item.connect("removed", self, "_remove_pack_item")

	tree_item_list.add_child(item)
	item.active()
	bundles.save(SAVED_PATH)


func _export_pack_item(pack_item):
	var export_name = pack_item.export_pck_name
	var files = pack_item.files
	var command = _get_command()
	var platform = check_preset(files)
	var arguments = _get_arguments(platform, export_name)
	var output = []
	print("export:", [command, arguments, platform, export_name])
	var err = OS.execute(command, arguments, false , output)
	print("执行结果:",err,  output)


func _remove_pack_item(pack_item):
	tree_item_list.remove_child(pack_item)
	pack_item.queue_free()


func get_project_path():
	return ProjectSettings.globalize_path("res://")


func check_preset(files):
	var preset = ConfigFile.new()
	var err = preset.load("res://export_presets.cfg")
	if err != OK:
		push_warning("没有预设导出, 将创建默认")
	
	var sec = "preset.0"
	preset.set_value(sec,"export_filter","resources")
	preset.set_value(sec, "export_files", files)
	var default_platform = preset.get_value(sec, "platform", "HTML5")
	preset.save("res://export_presets.cfg")
	var dir = Directory.new()
	var dist_dir = "res://dist"
	if not dir.dir_exists(dist_dir):
		dir.make_dir(dist_dir)
	return default_platform


func _get_command() -> String:
	return OS.get_executable_path()


func _get_arguments(platform,  pck_name) -> PoolStringArray:
	var ret: PoolStringArray
	ret.append("--no-window")
	ret.append("--export-pack")
	ret.append(platform)
	
	var dist = get_project_path().plus_file("/dist/%s.pck" % pck_name)
	ret.append(dist)
	return ret
