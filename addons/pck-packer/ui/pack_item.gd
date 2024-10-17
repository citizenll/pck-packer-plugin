tool
extends Panel

signal actived
signal focused
signal exported
signal removed

var UUID = preload("res://addons/pck_packer/uuid.gd")
onready var border = $Border
onready var title_label = $"%TitleLabel"
onready var file_name_line_edit = $"%FileNameLineEdit"
onready var file_item_list = $"%FileItemList"
onready var file_list_icon = $"%FileListIcon"
onready var name_list_icon = $"%NameListIcon"
onready var export_button = $"%ExportButton"
onready var del_button = $"%DelButton"
onready var tool_panel = $"%ToolPanel"
onready var file_suffix_name_line_edit = $"%FileSuffixNameLineEdit"
onready var file_dist_line_edit = $"%FileDistLineEdit"


var focused = false
var actived = false
var config:ConfigFile
var uuid
var section
var types
var export_pck_name = ""
var export_pck_path = ""
var export_pck_suffix = ""

var files = []
const SAVED_PATH = "user://export_bundles.cfg"

func _ready():
	if !config:return
	if !uuid:
		uuid = UUID.v4()
	section = "PackItem_%s" % uuid
	use_editor_theme()
	config.set_value(section, "uuid", uuid);
	name_list_icon.texture =  get_icon("File", "EditorIcons")
	file_list_icon.texture = get_icon("ClassList", "EditorIcons")
	
	update()


func use_editor_theme():
	var bg = get_stylebox("Background", "EditorStyles")
	add_stylebox_override("panel", bg)
	var tool_bg = get_stylebox("SceneTabBG", "EditorStyles")
	tool_panel.add_stylebox_override("panel", tool_bg)

func update_files(p_files):
	files = p_files
	config.set_value(section, "export_files", files)
	update(p_files)


func update(p_files=null):
	files = p_files if p_files != null else config.get_value(section, "export_files", [])
	var text = config.get_value(section, "export_pck_name", "")
	export_pck_name = text
	title_label.text = text if text else "PackItemNameHere"
	file_name_line_edit.text = text
	file_item_list.clear()
	export_pck_path = config.get_value(section, "export_pck_path", "")
	file_dist_line_edit.text = export_pck_path
	export_pck_suffix = config.get_value(section, "export_pck_suffix", "")
	file_suffix_name_line_edit.text = export_pck_suffix
	
	for file in files:
		file_item_list.add_item(file, get_icon(types[file], "EditorIcons"))


func _enter_tree():
	set_process_input(true)


func _exit_tree():
	set_process_input(false)


func _input(event):
	if !visible:return
	if event is InputEventMouseMotion && get_global_rect().has_point(event.global_position):
		if !focused:
			focused = true
			active_style()
			emit_signal("focused", self)
	elif event is InputEventMouseMotion && focused && !get_global_rect().has_point(event.global_position):
		focused = false
		if !actived && border.visible:
			unactive_style()
	if focused && event is InputEventMouseButton && event.is_pressed() && event.button_index == BUTTON_LEFT:
		if !actived:
			actived = true
			active_style()
			emit_signal("actived", self)


func active_style():
	border.show()
	if focused && !actived:
		border.border_color = Color("#327090")
	elif actived:
		border.border_color = Color("#44C0FF")


func unactive_style():
	border.hide()
	actived = false


func _on_LineEdit_text_changed(value):
	title_label.text = value
	export_pck_name = value
	config.set_value(section, "export_pck_name", value)
	config.save(SAVED_PATH)


func active():
	actived = true
	active_style()
	emit_signal("actived", self)
	file_name_line_edit.grab_focus()


func _on_ExportButton_pressed():
	emit_signal("exported", self)


func remove():
	config.erase_section(section)
	config.save(SAVED_PATH)


func _on_DelButton_pressed():
	remove()
	emit_signal("removed", self)


func _on_FileDistLineEdit_text_changed(value:String):
	if OS.get_name()=="Windows":
		value = value.replace("\\","/")
	export_pck_path = value
	config.set_value(section, "export_pck_path", value)
	config.save(SAVED_PATH)


func _on_FileSuffixNameLineEdit_text_changed(value):
	export_pck_suffix = value
	config.set_value(section, "export_pck_suffix", value)
	config.save(SAVED_PATH)
