const SERVER_PORT = 1234;
const MAX_PLAYERS = 4;

var tcp_server;
var tcp_sockets = []
var kick_list = [];
var ids = [];
var available_ids = [];
var id_to_tcp_socket = {}
var event_listeners = {}

func start():
	tcp_server = TCP_Server.new();
	tcp_server.listen(SERVER_PORT);

	for i in range(MAX_PLAYERS):
		available_ids.push_back(i);

func stop():
	for socket in tcp_sockets:
		socket.disconnect_from_host();
	tcp_server.stop();

func send_reliable(id: int, event: String, args: Array):
	var socket = id_to_tcp_socket[id];
	socket.put_string(event);
	socket.put_var(args);

func send(id: int, event: String, args: Array):
	# todo: udp
	var socket = id_to_tcp_socket[id];
	socket.put_string(event);
	socket.put_var(args);

func broadcast_reliable(event: String, args: Array):
	for socket in tcp_sockets:
		socket.put_string(event);
		socket.put_var(args);

func broadcast(event: String, args: Array):
	# todo: udp
	for socket in tcp_sockets:
		socket.put_string(event);
		socket.put_var(args);

func kick(id: int):
	kick_list.push_back(id);

func on(event, listener, callback):
	event_listeners[event] = {
		listener = listener,
		callback = callback
	};

func update():
	if tcp_server.is_connection_available():
		var socket = tcp_server.take_connection();
		socket.set_no_delay(true);
		
		if tcp_sockets.size() < MAX_PLAYERS - 1:
			var id = available_ids.pop_back();
			id_to_tcp_socket[id] = socket;
			
			ids.push_back(id);
			tcp_sockets.push_back(socket);
			
			_emit("connect", id, []);
		else:
			socket.disconnect_from_host();
	
	for id in kick_list:
		_remove_by_id(id);
	
	kick_list.clear();
	
	var disconnectedSockets = [];
	
	for i in range(tcp_sockets.size()):
		var socket = tcp_sockets[i];
		var id = ids[i];
	
		if !socket.is_connected_to_host():
			disconnectedSockets.push_back(i);
			_emit("disconnect", id, []);
			continue;
		
		# handle just one message per tick
		if socket.get_available_bytes() > 0:
			_handle_message(socket, id);
	
	for i in disconnectedSockets:
		_remove_by_index(i);

func _remove_by_id(id):
	var i = ids.find(id);

	if i != -1:
		_remove_by_index(i);

func _remove_by_index(i):
	var id = ids[i];
	
	id_to_tcp_socket.erase(id);
	available_ids.push_back(id);
	
	ids.remove(i);
	tcp_sockets.remove(i);


func _handle_message(socket: StreamPeer, socketid: int):
	var event = socket.get_string();
	var args = socket.get_var();
	
	_emit(event, socketid, args);

func _emit(event: String, socketid: int, args):
	var listenerInfo = event_listeners[event];
	
	if listenerInfo == null:
		vr.log_error("No listener for " + event);
		return
	
	if !(args is Array):
		vr.log_error("Malformed message");
		return
	
	args.push_front(socketid);
	
	listenerInfo.listener.callv(listenerInfo.callback, args);
