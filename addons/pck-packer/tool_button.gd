tool
extends Button

export var icon_name: String

func _notification(what: int):
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			if icon_name:
				icon = get_icon(icon_name, "EditorIcons")
