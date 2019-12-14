extends Node


class_name DataCrawler


const exts_doc: Array = [
	"doc",
	"docx",
	"odt",
	"rtf",
	"pdf",
	"txt",
	"tex"
]

const exts_tab : Array = [
	"xls",
	"xlsx",
	"ods",
	"xlr"
]

const exts_pic : Array = [
	"jpg",
	"jpeg",
	"gif",
	"png",
	"tif",
	"tiff"
]

const exts_vid : Array = [
	"avi",
	"m4v",
	"mov",
	"mkv",
	"mp4",
	"mpg",
	"mpeg",
	"wmv",
	"h264"
]

var _thread: Thread
var _run_thread: bool = true
var _waiting: bool = false
var _mutex: Mutex
var _semaphore: Semaphore

var _found_docs = []
var _found_tabs = []
var _found_pics = []
var _found_vids = []


var is_running: bool setget , _get_is_running
var is_waiting: bool setget , _get_is_waiting


func abort():
	_mutex.lock()
	_run_thread = false
	_mutex.unlock()
# warning-ignore:return_value_discarded
	_semaphore.post()

func scan_next_dir():
	if not self.is_running:
		return

	if self.is_waiting:
# warning-ignore:return_value_discarded
		_semaphore.post()

func get_results() -> Dictionary:
	var result = {}
	_mutex.lock()
	result.docs = [] + _found_docs
	result.tabs = [] + _found_tabs
	result.pics = [] + _found_pics
	result.vids = [] + _found_vids
	_mutex.unlock()
	return result


func _init():
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread = Thread.new()
# warning-ignore:return_value_discarded
	_thread.start(self, "_scan")

func _get_is_running() -> bool:
	return _thread.is_active()

func _get_is_waiting() -> bool:
	var waiting: bool
	_mutex.lock()
	waiting = _waiting
	_mutex.unlock()
	return waiting

func _add_result_to(array: Array, item: String):
		
	_mutex.lock()
	if array.size() > 100:
		array[randi() % array.size()] = item
	else:
		array.append(item)
	_mutex.unlock()

func _scan(_userdata):
	var os_dirs = [
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
		OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS),
		OS.get_system_dir(OS.SYSTEM_DIR_MOVIES),
		OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),
		OS.get_system_dir(OS.SYSTEM_DIR_DCIM),
		OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	]
	
	var dirs_to_scan = []
	for i in os_dirs.size():
		var dir = os_dirs[i]
		if dir == null or dir == "":
			continue
		var add_dir: bool = true
		for j in os_dirs.size():
			if i == j:
				continue
			var check = os_dirs[j]
			if check == null or check == "":
				continue
			if dir == check:
				add_dir = false
				break
			if dir.begins_with(check):
				add_dir = false
				break
		if add_dir:
			dirs_to_scan.append(dir)
	
	var run: bool
	while not dirs_to_scan.empty():
		_mutex.lock()
		run = _run_thread
		_mutex.unlock()
		
		if not run:
			break
		
		var path = dirs_to_scan.pop_front()
		var dir = Directory.new()
		if dir.open(path) != OK:
			continue
		
		_mutex.lock()
		_waiting = true
		_mutex.unlock()
		
# warning-ignore:return_value_discarded
		_semaphore.wait()
		
		_mutex.lock()
		_waiting = false
		_mutex.unlock()
			
		if dir.list_dir_begin(true) != OK:
			continue
			
		while true:
			_mutex.lock()
			run = _run_thread
			_mutex.unlock()
			
			if not run:
				break
	
			var entry = dir.get_next()
			if entry == null or entry == "":
				break
				
			if dir.current_is_dir():
				dirs_to_scan.append(path + "/" + entry)
				continue
			
			var ext = entry.get_extension().to_lower()
			if exts_doc.has(ext):
				_add_result_to(_found_docs, entry)
			elif exts_tab.has(ext):
				_add_result_to(_found_tabs, entry)
			elif exts_pic.has(ext):
				_add_result_to(_found_pics, entry)
			elif exts_vid.has(ext):
				_add_result_to(_found_vids, entry)
	
func _exit_tree():
	abort()
	_thread.wait_to_finish()
