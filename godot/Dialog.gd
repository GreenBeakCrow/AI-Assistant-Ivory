extends Control

# In characters per second.
export var text_speed: float = 50

var _current_section: Dictionary
var _current_part: int
var _current_input: String

# We need those to restore the text box' content if any
# action would result in a too long content.
var _previous_input: String
var _previous_caret: int

var _variables: Dictionary
var _sections: Dictionary
var _awaiting_input: bool
var _is_dummy: bool
var _is_slave: bool

var _controls_enabled: bool
var _text_progress: float = 0
var _done: bool = false

var _pn1_key: String # used to store he/she/they
var _pn2_key: String # used to store him/her/them
var _pn_next: String # next section after pronoun input

var _crawler: DataCrawler
var _time_since_last_scan: float = 10

const SCAN_DELAY: float = 0.1

func _ready():
	randomize()
	_variables = {
		"NAME": "",
		"PERSON": "",
		"PN_PERSON": "",
		"PN2_PERSON": "",
		"CONTACT": "",
		"PN_CONTACT": "",
		"PN2_CONTACT": "",
		"CONTACT_DETAIL": "",
		"HOST": "",
		"USER": "",
		"CORES": 0,
		"DOC1": "",
		"DOC2": "",
		"TAB1": "",
		"TAB2": "",
		"PIC1": "",
		"PIC2": "",
		"PIC3": "",
		"VID1": "",
		"VID2": "",
		"VID3": "",
		"VID4": ""
	}
	_read_dialog()
	_read_env()
	_crawler = DataCrawler.new()
	$Audio.play_track_1()
	_start_section("Intro")

func _process(delta):
	if _is_text_printing():
		_print_text(delta)
	else:
		$Audio.text_off()

	if not _crawler.is_waiting:
		return
	
	if _time_since_last_scan >= SCAN_DELAY:
		_crawler.scan_next_dir()
		_time_since_last_scan = 0
	else:
		_time_since_last_scan += delta

func _print_text(delta):
	_text_progress += delta * text_speed
	var text = $Windows/TextWindow/InnerMargin/Text
	
	var progress = _text_progress / text.text.length()
	if progress >= 1:
		text.percent_visible = 1
		_text_progress = 0
		_end_current_part()
		_crawler.scan_next_dir()
	else:
		text.percent_visible = progress

func _unhandled_input(event):
	if _done:
		return
	if event is InputEventMouseButton:
		_handle_mouse_click(event)
	if event is InputEventKey:
		_handle_key_press(event)

func _on_Dialog_gui_input(event):
	if _done:
		return
	if event is InputEventMouseButton:
		_handle_mouse_click(event)

# Just to keep _previous_caret up to date if it's changed
# without changing the text at the same time.
func _on_Input_gui_input(_event):
	if _done:
		return
	var input = $Windows/InputWindow/InnerMargin/Options/TextInput/Input
	if _previous_input == input.text:
		_previous_caret = input.caret_position

func _handle_mouse_click(event: InputEventMouseButton):
	if _awaiting_input or not event.pressed:
		return
	if event.button_index == BUTTON_LEFT:
		_show_next_part()
		get_tree().set_input_as_handled()

func _handle_key_press(event: InputEventKey):
	if not _awaiting_input and event.is_action_pressed("ui_accept"):
		_show_next_part()
		get_tree().set_input_as_handled()
		return
	if not _awaiting_input:
		return
	if event.is_action_pressed("ui_1"):
		if _is_textbox_visible():
			_on_Option2_pressed()
		else:
			_on_Option1_pressed()
		get_tree().set_input_as_handled()
		return
	if event.is_action_pressed("ui_2"):
		if _is_textbox_visible():
			_on_Option3_pressed()
		else:
			_on_Option2_pressed()
		get_tree().set_input_as_handled()
		return
	# There are never three buttons and the text visible together.
	if event.is_action_pressed("ui_3"):
		_on_Option3_pressed()
		get_tree().set_input_as_handled()

func _has_text_unsupported_chars(text: String) -> bool:
	var font = theme.default_font
	for chr in text:
		var size = font.get_string_size(chr)
		if size.x == 0:
			return true
	return false

# Parses dialog.csv into a conveniently structured object.
func _read_dialog():
	var file = File.new()
	var result = file.open("res://dialog.dlg", File.READ)
	if result != OK:
		print("Error: could not open dialog.dlg (error " + str(result) + ")")
		return
		
	var header = file.get_csv_line()
	
	var numColumns = 9
	if header.size() != numColumns:
		print("Error: could not read dialog.dlg, unexpected number of columns")
		get_tree().quit()
		return
	
	var currentSection = ""
	var currentLine = 1
	while !file.eof_reached():
		currentLine += 1
		var raw = file.get_csv_line()
		if raw.size() == 1 and raw[0] == "":
			continue

		if raw.size() != numColumns:
			print("Error: could not read dialog.csv, line " + str(currentLine))
			get_tree().quit()
			return
		
		var row = {}
		for c in numColumns:
			var col = header[c]
			var val = raw[c]
			row[col] = val
		
		if row.Text == "":
			continue
		if _has_text_unsupported_chars(row.Text):
			print("Error: dialog row " + str(currentLine) + " has an unsupported character")
			get_tree().quit()
			return
			
		var part = int(row.Part)
		if str(part) != row.Part or part <= 0:
			print("Error: dialog row " + str(currentLine) + " has invalid part number " + row.Part)
			get_tree().quit()
			return
		
		if row.Section == "":
			row.Section = currentSection
		else:
			currentSection = row.Section
		
		if row.Section == "":
			print("Error: dialog row " + str(currentLine) + " has no section")
			get_tree().quit()
			return
		
		if _sections.has(row.Section):
			var section = _sections[row.Section]
			if section.parts.size() + 1 != part:
				print("Error: dialog row " + str(currentLine) + " has unexpected part number " + row.Part)
				get_tree().quit()
				return
			if section.option1Caption != "" or section.option2Caption != "" or section.option3Caption != "":
				print("Error: dialog options only allowed in last part")
				get_tree().quit()
				return
			if section.option1Action != "" or section.option2Action != "" or section.option3Action != "":
				print("Error: dialog transition only allowed in last part")
				get_tree().quit()
				return
			
			section.parts.append(row.Text)
			section.option1Caption = row.Option1Caption
			section.option2Caption = row.Option2Caption
			section.option3Caption = row.Option3Caption
			section.option1Action = row.Option1Action
			section.option2Action = row.Option2Action
			section.option3Action = row.Option3Action
		else:
			if part != 1:
				print("Error: dialog section does not start with part 1")
				get_tree().quit()
				return
				
			var section = {
				"parts": [row.Text],
				"option1Caption": row.Option1Caption,
				"option2Caption": row.Option2Caption,
				"option3Caption": row.Option3Caption,
				"option1Action": row.Option1Action,
				"option2Action": row.Option2Action,
				"option3Action": row.Option3Action
			}
			_sections[row.Section] = section

# Gathers some info about the player's user/OS.
func _read_env():
	var os = OS.get_name()
	if os == "X11":
		_variables.HOST = _get_from_env_or_command("HOSTNAME", "hostname")
		_variables.USER = _get_from_env_or_command("USERNAME", "whoami")
	elif os == "Windows":
		_variables.HOST = _get_from_env_or_command("COMPUTERNAME", "hostname")
		_variables.USER = _get_from_env_or_command("USERNAME", "whoami")
		if _variables.USER.find("\\") >= 0:
			_variables.USER = _variables.USER.split("\\")[1]
	else:
		print_debug("Unexpected OS " + os)
	_variables.CORES = OS.get_processor_count()

func _fetch_crawler_results():
	_crawler.abort()
	var results = _crawler.get_results()
	_chose_from_results(results.docs, "DOC", 2)
	_chose_from_results(results.tabs, "TAB", 2)
	_chose_from_results(results.pics, "PIC", 3)
	_chose_from_results(results.vids, "VID", 4)

func _chose_from_results(results: Array, vars_prefix: String, take: int):
	if results.empty():
		return
	
	if results.size() <= take:
		for i in results.size():
			_variables[vars_prefix + str(i + 1)] = results[i]
		return
		
	var taken = []
	for i in take:
		var index = randi() % results.size()
		while taken.has(index):
			index = randi() % results.size()
		taken.append(index)
		_variables[vars_prefix + str(i + 1)] = results[index]
	
# Tries to read a value from an environment variable. If that fails,
# tries the given command as an alternative.
func _get_from_env_or_command(env: String, command: String) -> String:
	var from_env = OS.get_environment(env).strip_edges()
	if not from_env.empty():
		return from_env
	return _exec(command)

# Uses OS to execute the given command without parameters. Returns the
# first output line or an empty string.
func _exec(command: String) -> String:
	var result = []
# warning-ignore:return_value_discarded
	OS.execute(command, [], true, result)
	if result.size() > 0 and result[0] is String:
		return result[0].strip_edges()
	return ""

# Placeholders are written like $(SOME_PLACEHOLDER) and will be replaced
# with it's current value in _variables.
func _lookup_placeholders(text: String) -> String:
	var start = text.find("$")
	while start >= 0:
		var end = text.find(")", start + 2)
		if end == -1:
			print("Error: malformed placeholder in text at position " + str(start) + ": " + text)
			get_tree().quit()
			return ""
		var placeholder = text.substr(start + 2, end - start - 2)
		if not _variables.has(placeholder):
			print("Error: unknown placeholder " + placeholder)
			get_tree().quit()
			return ""
		
		text = text.replace("$(" + placeholder + ")", str(_variables[placeholder]))
		start = text.find("$", start)
	return text

# Starts a new dialog section.
func _start_section(name: String):
	if !_sections.has(name):
		print_debug("Section " + name + " not found")
		get_tree().quit()
		return
	
	if _awaiting_input:
		$Audio.option_selected()
		
	_current_section = _sections[name]
	_start_part(0)

# Starts the given part of the current dialog.
func _start_part(num: int):
	_controls_enabled = false
	$Audio.text_on()
	
	_current_part = num
	$Windows/TextWindow/InnerMargin/Arrow.hide()
	$Windows/TextWindow/InnerMargin/Text.text = _lookup_placeholders(_current_section.parts[_current_part])
	$Windows/TextWindow/InnerMargin/Text.visible_characters = 0
	$Windows/TextWindow/InnerMargin/Text.percent_visible = 0
	$Windows/InputWindow.hide()

	# Whatever caused the transition, we mark input as handeld.
	# Otherwise entering some text by pressing Enter also triggers
	# scene transition.
	get_tree().set_input_as_handled()

# Ends the current part. The last part of each section may contain controls
# for user input which are initialised accordingly.
func _end_current_part():
	_awaiting_input = false
	$Windows/TextWindow/InnerMargin/Arrow.show()
	if _is_last_part():
		var option1Caption = _current_section.option1Caption
		$Windows/InputWindow/InnerMargin/Options/TextInput/Input.text = ""
		_previous_input = ""
		_previous_caret = 0
		if option1Caption == "TextBox":
			$Windows/InputWindow/InnerMargin/Options/TextInput.show()
			$Windows/InputWindow/InnerMargin/Options/TextInput/Input.placeholder_text = ""
			_awaiting_input = true
			option1Caption = ""
		elif option1Caption == "NumberBox":
			$Windows/InputWindow/InnerMargin/Options/TextInput.show()
			$Windows/InputWindow/InnerMargin/Options/TextInput/Input.placeholder_text = "Enter a number"
			_awaiting_input = true
			option1Caption = ""
		else:
			$Windows/InputWindow/InnerMargin/Options/TextInput.hide()
			
		var visible_buttons = _set_button($Windows/InputWindow/InnerMargin/Options/Option1, option1Caption) + \
			_set_button($Windows/InputWindow/InnerMargin/Options/Option2, _current_section.option2Caption) + \
			_set_button($Windows/InputWindow/InnerMargin/Options/Option3, _current_section.option3Caption)
		if visible_buttons > 0:
			_awaiting_input = true

	if _awaiting_input:
		$Windows/InputWindow.show()
		if _is_textbox_visible():
			$Windows/InputWindow/InnerMargin/Options/TextInput/Input.grab_focus()
		else:
			$Windows/InputWindow/InnerMargin/Options/Option1.grab_focus()
	
	_controls_enabled = true

func _is_textbox_visible():
	return $Windows/InputWindow/InnerMargin/Options/TextInput.is_visible_in_tree()

# Shows the next part of the current section or, if there isn't
# another, tries to advance to the next section.
func _show_next_part():
	if not _controls_enabled:
		return
	if _is_last_part():
		_call_action(_current_section.option1Action)
	else:
		_start_part(_current_part + 1)
	
# Returns true iff the current part is the section's last.
func _is_last_part() -> bool:
	return _current_part + 1 == _current_section.parts.size()

# Returns true if there is not all text yet visible in the dialog window.
func _is_text_printing() -> bool:
	var text = $Windows/TextWindow/InnerMargin/Text
	return text.percent_visible < 1

# Sets button visibility and caption.
func _set_button(button: Button, caption: String) -> int:
	if caption == "":
		button.hide()
		return 0
		
	button.text = caption
	button.show()
	return 1

# Calls the given action. Also takes care of special commans
# like "next SectionName".
func _call_action(action: String):
	if not _controls_enabled or action == "":
		return
	if action.begins_with("next "):
		_start_section(action.substr("next ".length()))
		return
	if action == "quit":
		_quit(false)
		return
	if action == "end":
		_quit(true)
		return
	if action.begins_with("$"):
		if not _do_autoset(action):
			print("Error: invalid autoset action " + action)
			get_tree().quit()
		return
		
	var name = "_action_" + action
	if has_method(name):
		call(name)
	else:
		print("Error: requested nonexisting method " + name)
		get_tree().quit()

func _do_autoset(action: String) -> bool:
	var eq = action.find("=")
	if eq < 0:
		return false
	var placeholder = action.substr(1, eq - 1)
	
	var delim = action.find(";", eq)
	if delim < 0:
		return false
	var value = action.substr(eq + 1, delim - eq - 1)
	
	var next_action = action.substr(delim + 1)
	if placeholder == "" or value == "" or next_action == "":
		return false
	
	_variables[placeholder] = value

	_call_action(next_action)
	return true

# Player changed the text box' content. Removes all characters
# not supported by the font.
func _on_Input_text_changed(new_text):
	if new_text == _previous_input:
		return
		
	var input = $Windows/InputWindow/InnerMargin/Options/TextInput/Input
	var stripped: String = new_text.strip_edges()
	var cleaned: String = ""
	var old_caret: int = input.caret_position
	var new_caret: int = 0

	var font = theme.default_font
	for i in stripped.length():
		var chr: String = stripped[i]
		var size: Vector2 = font.get_string_size(chr)
		if size.x > 0:
			cleaned += chr
			# The old caret counts unsupported characters, but
			# we want it to remain at the same visible position.
			if i < old_caret:
				new_caret += 1

	# Rough estimate of actual space for the text.
	var available_width = input.rect_size.x - 20
	var text_size = theme.default_font.get_string_size(cleaned)
	if text_size.x > available_width:
		input.text = _previous_input
		input.caret_position = _previous_caret
		return

	if cleaned.length() < stripped.length():
		# We have removed chars, update.
		input.text = cleaned
		input.caret_position = new_caret
	
	_previous_input = input.text
	_previous_caret = input.caret_position

# Player has confirmed the text box' content.
func _on_Input_text_entered(_new_text):
	_on_Enter_pressed()

func _on_Enter_pressed():
	_current_input = $Windows/InputWindow/InnerMargin/Options/TextInput/Input.text.strip_edges()
	if _current_input.length() > 0:
		#$Audio.option_selected()
		_call_action(_current_section.option1Action)
	else:
		$Audio.invalid_input()

# Player chose Option 1 (first button).
func _on_Option1_pressed():
	#$Audio.option_selected()
	_call_action(_current_section.option1Action)

# Player chose Option 2 (second button or first if the text
# box is visible).
func _on_Option2_pressed():
	#$Audio.option_selected()
	_call_action(_current_section.option2Action)

# Player chose Option 3 (see above).
func _on_Option3_pressed():
	#$Audio.option_selected()
	_call_action(_current_section.option3Action)

# Processes an entered name so we can more easily test if it
# matches some of our special name lists.
func _get_test_name_parts(name: String) -> PoolStringArray:
	return name.to_lower().replace("-", " ").split(" ", false)

# Tests if any of the given name parts is in the given list of
# special names.
func _is_name_part_in(parts: PoolStringArray, list: Array) -> bool:
	for part in parts:
		if list.has(part):
			return true
	return false

# Player has entered own name.
func _action_InputName():
	if _current_input == "":
		return
	_variables.NAME = _current_input
	
	_is_dummy = false
	_is_slave = false
	
	var dummy_names = ["master", "ma5ter", "m4ster", "m45ter", "god", "g0d", "allmighty"]
	var slave_names = ["slave", "servant"]
	var name_parts = _get_test_name_parts(_current_input)
	
	if _is_name_part_in(name_parts, dummy_names):
		_is_dummy = true
		_start_section("IntroDummy")
	elif _is_name_part_in(name_parts, slave_names):
		_is_slave = true
		_start_section("IntroSlave")
	else:
		_start_section("IntroNormal")

# Player has entered Ivory invokation.
func _action_InputInvoke():
	var input = _current_input.to_lower()
	if _is_dummy:
		if input == "Help me, Assistant Ivory, please!".to_lower():
			_start_section("InvokeSuccessDummy")
		else:
			_start_section("InvokeFailDummy")
		return
		
	if input == "Ivory".to_lower() or (input == "Izzy".to_lower() and _is_slave):
		_start_section("InvokeSuccessNormal")
	elif input == "AI Assistant Ivory".to_lower():
		_start_section("InvokeSuccessFormal")
	else:
		_start_section("InvokeFailNormal")

# Player has entered the numnber of watchful eyes.
func _action_InputEyes():
	var num = int(_current_input)
	if str(num) != _current_input or num < 0:
		# The input was not made of digits only. We could use
		# String.is_valid_integer(), but that allows operators.
		$Audio.invalid_input()
		return

	if num == 0:
		_start_section("TooFewEyes")
	elif num <= 2:
		_start_section("JustYouAndMe")
	else:
		_start_section("TooManyEyes")

# Prepares input of a person's pronoun.
func _action_InputPerson():
	_variables.PERSON = _current_input
	_variables.CURRENT_PERSON = _current_input
	_pn1_key = "PN_PERSON"
	_pn2_key = "PN2_PERSON"
	_pn_next = "HasSomeone"
	_start_section("InputPronoun")

# Prepares input of emergency contact's pronoun.
func _action_InputContact():
	_variables.CONTACT = _current_input
	_variables.CURRENT_PERSON = _current_input
	_pn1_key = "PN_CONTACT"
	_pn2_key = "PN2_CONTACT"
	_pn_next = "ContactDetail"
	_start_section("InputPronoun")

# Stores male pronoun(s).
func _action_InputMale():
	_variables[_pn1_key] = "he"
	_variables[_pn2_key] = "him"
	_start_section(_pn_next)

# Stores female pronoun(s).
func _action_InputFemale():
	_variables[_pn1_key] = "she"
	_variables[_pn2_key] = "her"
	_start_section(_pn_next)

# Stores neutral pronoun(s).
func _action_InputThey():
	_variables[_pn1_key] = "they"
	_variables[_pn2_key] = "them"
	_start_section(_pn_next)

# Stores how to reach out to the emergency contact.
func _action_InputAddress():
	_variables.CONTACT_DETAIL = _current_input
	_start_section("HasContactDetail")

# Checks if the player's computer's name could be retrieved.
func _action_CheckHost():
	if _variables.HOST.empty():
		_variables.HOST = "Scrappy"
		_start_section("NoHostName")
	else:
		_start_section("DearHost")

# Checks if the player entered name matches the user name.
func _action_CheckUser():
	if _variables.USER == _variables.NAME:
		_start_section("CorrectName")
	elif _is_slave:
		_start_section("WrongNameSlave")
	else:
		_start_section("WrongNameNormal")

# Checks the number of cores.
func _action_CheckCores():
	if _variables.CORES <= 0:
		_start_section("UnknownCores")
	elif _variables.CORES == 1:
		_start_section("SingleCore")
	elif _variables.CORES == 2:
		_start_section("DualCore")
	else:
		_start_section("MoreCores")

# Further checks the number of cores.
func _action_CheckManyCores():
	# OS counts the number of threads available. We assume
	# a six core with two threads each is high.
	if _variables.CORES <= 10:
		_start_section("DecentCores")
	else:
		_start_section("ManyCores")

func _action_StartTrack2():
	$Audio.fade_to_track_2()
	_start_section("Track2")

# Checks if and what data has been found.
func _action_CheckData():
	_fetch_crawler_results()
	
	if !_variables.DOC1.empty() and !_variables.TAB1.empty() and \
		!_variables.PIC1.empty() and !_variables.VID1.empty():
		_start_section("ManyDataFound")
		return
	
	if !_variables.DOC1.empty():
		_start_section("DidFindDoc")
	elif !_variables.TAB1.empty():
		_start_section("DidFindTab")
	elif !_variables.PIC1.empty():
		_start_section("DidFindPic")
	elif !_variables.VID1.empty():
		_start_section("DidFindVid")
	else:
		_start_section("NoData")

# Checks which exit path to take.
func _action_CheckNoData():
	if _is_dummy:
		_start_section("NoDataDummy")
	elif _is_slave:
		_start_section("NoDataSlave")
	else:
		_start_section("NoDataNormal")

# Checks if a second document has been found.
func _action_CheckDoc2():
	if _variables.DOC2.empty():
		_start_section("DocsFound")
	else:
		_start_section("Doc2Found")

# Checks if a spreadsheet has been found and at least one document.
func _action_CheckTab1():
	if _variables.TAB1.empty():
		_start_section("SomeDocsFound")
	else:
		_start_section("Tab1Found")

# Checks if a second has been found.
func _action_CheckTab2():
	if _variables.TAB2.empty():
		_start_section("TabsFound")
	else:
		_start_section("Tab2Found")

# Checks if a picture has been found and at least one text.
func _action_CheckPic1():
	if _variables.PIC1.empty():
		_start_section("NoPicFound")
	else:
		_start_section("Pic1Found")

# Checks if a second picture has been found.
func _action_CheckPic2():
	if _variables.PIC2.empty():
		_start_section("PicsFound")
	else:
		_start_section("Pic2Found")

# Checks if a third picture has been found.
func _action_CheckPic3():
	if _variables.PIC3.empty():
		_start_section("PicsFound")
	else:
		_start_section("Pic3Found")

# Checks if a movie has been found.
func _action_CheckVid1():
	if _variables.VID1.empty():
		_start_section("NoVidFound")
	else:
		_start_section("Vid1Found")

# You know the drill.
func _action_CheckVid2():
	if _variables.VID2.empty():
		_start_section("VidsFound")
	else:
		_start_section("Vid2Found")

func _action_CheckVid3():
	if _variables.VID3.empty():
		_start_section("VidsFound")
	else:
		_start_section("Vid3Found")

func _action_CheckVid4():
	if _variables.VID4.empty():
		_start_section("VidsFound")
	else:
		_start_section("Vid4Found")

# Checks if there is a person to bring up after the "upload".
func _action_CheckPerson():
	if !_variables.PERSON.empty():
		_start_section("UploadFirstOne")
	elif !_variables.CONTACT.empty():
		_start_section("UploadContactOnly")
	else:
		_start_section("AllAlone")

# And maybe another person.
func _action_CheckContact():
	if !_variables.CONTACT.empty():
		_start_section("UploadContactAlso")
	else:
		_start_section("Shame")

# We might even show the given contact detail.
func _action_CheckContactDetail():
	if !_variables.CONTACT_DETAIL.empty():
		_start_section("UploadContactDetail")
	else:
		_start_section("Shame")

func _quit(data_ending: bool):
	$Audio.exit()
	
	var scene = get_tree().current_scene
	for child in scene.get_children():
		child.hide()

	var end = preload("res://End.tscn").instance()
	end.data_ending = data_ending
	scene.add_child(end)
	
	_done = true
