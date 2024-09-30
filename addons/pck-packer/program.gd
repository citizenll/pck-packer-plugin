extends Reference
class_name ProgramInstance
var pid: int
var stdio: File
var stderr: File
var finish_mutext: Mutex

var is_running: bool
var finalized: bool
var result: int
var io_thread: Thread
var err_thread: Thread

signal output_line

static func create_for_pipe(data: Dictionary) -> ProgramInstance:
	var instance := ProgramInstance.new()
	if data.empty():
		return instance
	
	instance.pid = data["pid"]
	instance.stdio = data["stdio"]
	instance.stderr = data["stderr"]
	instance.finish_mutext = Mutex.new()
	instance.is_running = true
	
	return instance

func start():
	io_thread = Thread.new()
	io_thread.start(self, "pipe_read", stdio)
	
	err_thread = Thread.new()
	err_thread.start(self, "pipe_read", stderr)

func pipe_read(pipe: File):
	var is_err := pipe == stderr
	var buffer_empty: bool
	
	while is_running:
		if pipe.get_error() != OK or not OS.is_process_running(pid):
			break
		
		if buffer_empty:
			emit_signal("output_line", "", is_err)
		buffer_empty = false
		
		var line := pipe.get_line()
		if line.empty():
			buffer_empty = true
		else:
			emit_signal("output_line",line, is_err)
	
	finish_mutext.lock()
	OS.delay_usec(1) # Prevents deadlock??
	
	var other: Thread
	if is_err:
		other = io_thread
	else:
		other = err_thread
	
	if not other.is_alive():
		is_running = false
	
	finish_mutext.unlock()

func stop():
	if not is_running:
		return
	
	is_running = false
	OS.kill(pid)
	stdio.close()
	stderr.close()

func finalize():
	if finalized:
		return
	
	io_thread.wait_to_finish()
	err_thread.wait_to_finish()
	result = OS.get_process_exit_code(pid)
	finalized = true
