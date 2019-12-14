extends Node

var _text_on: bool = false

func invalid_input():
	$InvalidInput.play()
		
func option_selected():
	$OptionSelected.play()

func text_on():
	if not _text_on:
		_text_on = true
		$Text.play()

func text_off():
	_text_on = false

func play_track_1():
	$Track1.play()
	
func fade_to_track_2():
	$Tween.interpolate_property($Track1, "volume_db", null, -100, 3, Tween.TRANS_EXPO, Tween.EASE_IN)
	$Tween.interpolate_property($Track2, "volume_db", -100, $Track2.volume_db, 3, Tween.TRANS_EXPO, Tween.EASE_OUT, 2)
	$Tween.start()
	
	yield(get_tree().create_timer(2), "timeout")
	$Track2.play()

func exit():
	$Exit.play()
	$Track1.stop()
	$Track2.stop()

func _on_Text_finished():
	if _text_on:
		$Text.play()
