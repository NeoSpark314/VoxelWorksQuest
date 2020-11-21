# Integration of the OWO Game server communication protocol
# Version 0.1.0
extends Spatial

enum Muscles {
	Pectoral_R = 0,
	Pectoral_L = 1,
	Abdominal_R = 2,
	Abdominal_L = 3,
	Arm_R = 4,
	Arm_L = 5,
	Dorsal_R = 6,
	Dorsal_L = 7,
	Lumbar_R = 8,
	Lumbar_L = 9
};

enum Sensations {
	Stop = -1, #: Stops the sensation currently playing(available in 2.2b and subsequent versions)
	BallGame = 0, #: BallGame
	DartGame = 1, #: DartGame
	KnifeGame = 2, #: KnifeGame
	#BulletGame = 3, #: BulletGame DEPRECATED
	Shot = 4, #: Shot with exit
	Razorblade = 5, #: Razorblade
	Hack = 6, #: Hack
	Punch = 7, #: Punch
	Grip = 8, #: Grip
	QuickShot = 9, #: Quick Shot
	Spiders = 10, #: Spiders - Tickling
	Freefall = 11, #: Freefall
	LoadVeryHeavyObject = 12, #: Load very heavy object
	LoadHeavyObject = 13, #: Load heavy object
	DriveFast = 14, #: Drive fast
	DriveSlow = 15, #: Drive slow speed vibration
	FrontAttackChest = 16, #: Front attack chest blades
	MachinegunShots = 17, #: Machine gunshots
	PushVeryHeavy = 18, #: Pushing something very heavy
	PushHeavy = 19, #: Push something heavy
	SevereAbdominalWound = 20, #: Severe abdominal wound
	SlightBleedingWound = 21, #: Slight bleeding wound
	Oppression = 22, #: Oppression
	StrangePresence = 23, #: Strange presence (dorsal)
};


# call this function to initialize and connect to the given server IP
func connect_to_owo_server(ip = "127.0.0.1"):
	_ip = ip;
	_initialize_owo_connection();


func send_sensation(sensationID, muscleID):
	if (_stream.get_status() != 2):
		print("  OWO Error: not connected to OWO server " + _ip +":"+str(_port));
	var message = "owo/" + str(sensationID) + "/" + str(muscleID) + "/eof";
	_stream.put_data(message.to_ascii());
	print("  OWO: Sending message: '"+message+"' (" + get_sensation_name(sensationID) + ", " + get_muscle_name(muscleID) + ")");


func get_num_muscles():
	return Muscles.keys().size();

func get_num_sensations():
	return Sensations.keys().size();
	
func get_muscle_name(id):
	return Muscles.keys()[id];

func get_sensation_name(id):
	return Sensations.keys()[id];


func is_connected_to_owo_server():
	if (!_stream): return false;
	return (_stream.get_status() == 2);
	

var _ip = "127.0.0.1"
var _port = 54010;
var _stream : StreamPeerTCP = null;

func _initialize_owo_connection():
	if _stream == null:
		_stream = StreamPeerTCP.new();
	else:
		if (_stream.is_connected_to_host()): _stream.disconnect_from_host();
	
	var error = _stream.connect_to_host(_ip, _port);
	if (error != OK):
		print("OWO: Error connecting to " + _ip + ":" + str(_port));
	else:
		print("OWO: Trying to connect to " + _ip + ":" + str(_port));
	
	
func _exit_tree():
	_stream.disconnect_from_host();


func _ready():
	#_initialize_owo_connection(); we only initialize on user call right now
	pass;


var _last_status = -1;
func _process(_dt):
	#if (Input.is_action_just_pressed("ui_left")): send_sensation(1, 1);
	
	if (_stream.get_status() != _last_status):
		_last_status = _stream.get_status();
		print("  OWO: Connection status changed to : " + str(_last_status))


