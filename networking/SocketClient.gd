const SERVER_PORT = 1234;
const MAX_MESSAGES_PER_TICK = 5;

var event_listeners = {}

var tcp_socket;

var connected = false

func connect_to_host(host):
	tcp_socket = StreamPeerTCP.new();
	
	if tcp_socket.connect_to_host(host, SERVER_PORT) != OK:
		_emit("disconnect", []);

func disconnect_from_host():
	if connected:
		tcp_socket.disconnect_from_host();

func send_reliable(event: String, args: Array):
	if connected:
		tcp_socket.put_string(event);
		tcp_socket.put_var(args);

func send(event: String, args: Array):
	if connected:
		# todo: udp
		tcp_socket.put_string(event);
		tcp_socket.put_var(args);

func on(event, listener, callback):
	event_listeners[event] = {
		listener = listener,
		callback = callback
	};

func update():
	var status = tcp_socket.get_status();

	# connecting
	if status == tcp_socket.STATUS_CONNECTING:
		return;
	
	if status == tcp_socket.STATUS_NONE || status == tcp_socket.STATUS_ERROR:
		connected = false;
		_emit("disconnect", []);
		return;

	if !connected:
		tcp_socket.set_no_delay(true);
		connected = true;
		_emit("connect", []);
	
	var i = 0

	while i < MAX_MESSAGES_PER_TICK && tcp_socket.get_available_bytes() > 0:
		_handle_message(tcp_socket);
		i += 1;

func _handle_message(socket: StreamPeer):
	var event = socket.get_string();
	var args = socket.get_var();

	_emit(event, args);

func _emit(event: String, args):
	var listenerInfo = event_listeners[event];
	
	listenerInfo.listener.callv(listenerInfo.callback, args);
