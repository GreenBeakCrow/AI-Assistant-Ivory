extends Control

var data_ending: bool

func _on_Timer_timeout():
	if data_ending:
		$MarginContainer/VBoxContainer/NoData.hide()
		$MarginContainer/VBoxContainer/WithData.show()
	else:
		$MarginContainer/VBoxContainer/WithData.hide()
		var docs = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		var label = $MarginContainer/VBoxContainer/NoData
		label.text = label.text.replace("$DOCS", docs)
		$MarginContainer/VBoxContainer/NoData.show()
	
	$Tween.interpolate_property($ColorRect, "modulate", null, Color(1, 1, 1, 0), 2, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$Tween.start()

func _on_Tween_tween_all_completed():
	$ColorRect.hide()
	$MarginContainer/VBoxContainer/CenterContainer/Button.show()

func _on_Button_pressed():
	get_tree().quit()
