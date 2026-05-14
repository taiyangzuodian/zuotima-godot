class_name HistoryOverlay
extends PlaceholderModal

const HistoryEntry = preload("res://scripts/domain/history_entry.gd")

@onready var history_list: VBoxContainer = $CenterContainer/ModalPanel/Content/HistoryList
@onready var empty_state_card: Control = $CenterContainer/ModalPanel/Content/EmptyStateCard
@onready
var empty_state_label: Label = $CenterContainer/ModalPanel/Content/EmptyStateCard/EmptyStateLabel


func load_entries(service: Object) -> void:
	_clear_history_list()
	var entries: Array[HistoryEntry] = service.load_entries()
	if entries.is_empty():
		_show_empty_state()
		return

	history_list.visible = true
	empty_state_card.visible = false
	for entry in entries:
		var item := _history_item(entry)
		history_list.add_child(item)
		_assign_owner(item, self)


func _clear_history_list() -> void:
	for child in history_list.get_children():
		history_list.remove_child(child)
		child.queue_free()


func _show_empty_state() -> void:
	history_list.visible = false
	empty_state_card.visible = true
	empty_state_label.text = "完成一次挑战后，这里会显示挑战历史。"


func _history_item(entry: HistoryEntry) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "HistoryItem"
	var body := VBoxContainer.new()
	body.name = "HistoryItemBody"
	body.add_child(_label("HistoryItemTitle", entry.summary_title))
	body.add_child(_label("HistoryItemMeta", _entry_meta(entry)))
	card.add_child(body)
	return card


func _label(label_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _assign_owner(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_assign_owner(child, owner_node)


func _entry_meta(entry: HistoryEntry) -> String:
	var accuracy_percent := int(round(entry.accuracy * 100.0))
	return (
		"%s · %s · %d%% · %d 题"
		% [
			entry.completed_at,
			entry.result,
			accuracy_percent,
			entry.question_count,
		]
	)
