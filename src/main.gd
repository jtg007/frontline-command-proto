extends Node
## Entry point. Builds the same node layout on server and client
## (/root/Main/Net must exist on both for RPCs), then starts the right side.

func _ready() -> void:
	var args: LaunchArgs = LaunchArgs.parse(OS.get_cmdline_user_args())
	var net := NetBridge.new()
	net.name = "Net"
	add_child(net)
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	if args.is_server:
		var server := ServerGame.new()
		server.name = "ServerGame"
		add_child(server)
		var err: Error = server.start(args, net, world)
		if err != OK:
			push_error("Server failed to start: %s" % error_string(err))
			get_tree().quit(1)
	else:
		var client := ClientGame.new()
		client.name = "ClientGame"
		add_child(client)
		client.setup(args, net, world)
