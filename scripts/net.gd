extends Node
# 2-player co-op networking for 도깨비 디펜스 (각자 무대 협동). Lives at /root/Net so it survives scene reloads
# and has the same node path on both peers (needed for RPCs).
# Model: each peer simulates only its own stage. The host is the wave master: waves start together, both
# players' card picks finish before the next wave, speed/pause follow the host. Peers exchange a small
# snapshot of their stage a few times a second so each can see the partner's board. One stage falls = both lose.

const PORT := 24680
const SNAP_EVERY := 0.2

signal changed

var peer: ENetMultiplayerPeer = null
var is_host := false
var connected := false
var status := ""
var game: Node = null          # current toy2 node (set by the game)
var partner_snap := {}         # latest snapshot from the partner
var partner_result := ""       # "" | "won" | "lost"
var ready_waves := {}          # host: peer_id -> wave number they finished
var snap_t := 0.0


static func get_net(tree: SceneTree) -> Node:
	var n := tree.root.get_node_or_null("Net")
	if n == null:
		n = load("res://scripts/net.gd").new()
		n.name = "Net"
		# the root may be busy adding the scene that asks for us, so join the tree at the end of the frame
		tree.root.add_child.call_deferred(n)
	return n


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func active() -> bool:
	return peer != null and connected


func host() -> bool:
	if not is_inside_tree(): return false
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		status = "방을 만들 수 없습니다 (포트 %d 사용 중?)" % PORT
		peer = null
		changed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	status = "친구를 기다리는 중... 내 IP: " + ", ".join(local_ips())
	changed.emit()
	return true


func join(ip: String) -> bool:
	if not is_inside_tree(): return false
	leave()
	ip = ip.strip_edges()
	if ip == "": ip = "127.0.0.1"
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status = "접속할 수 없습니다: " + ip
		peer = null
		changed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	status = "%s에 접속하는 중..." % ip
	changed.emit()
	return true


func leave() -> void:
	if peer != null:
		peer.close()
	if is_inside_tree(): multiplayer.multiplayer_peer = null
	peer = null
	connected = false
	is_host = false
	partner_snap = {}
	partner_result = ""
	ready_waves = {}
	status = ""
	changed.emit()


func local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func partner_id() -> int:
	var ids := multiplayer.get_peers()
	return ids[0] if ids.size() > 0 else 0


# ---------------- connection events ----------------
func _on_peer_connected(_id: int) -> void:
	if is_host:
		connected = true
		status = "친구가 들어왔습니다. 난이도를 고르고 '판 시작'."
		if game != null: _sync_lobby.rpc(game.diff_key)
		changed.emit()


func _on_connected() -> void:
	connected = true
	status = "접속 성공! 방장이 시작하기를 기다리는 중."
	changed.emit()


func _on_failed() -> void:
	status = "접속 실패: IP와 방장의 방 만들기 상태를 확인하세요."
	leave_keep_status()


func _on_server_gone() -> void:
	status = "방장과 연결이 끊겼습니다."
	leave_keep_status()
	if game != null: game.on_partner_left()


func _on_peer_disconnected(_id: int) -> void:
	if is_host:
		connected = false
		status = "친구와 연결이 끊겼습니다. 친구를 기다리는 중..."
		partner_snap = {}
		changed.emit()
		if game != null: game.on_partner_left()


func leave_keep_status() -> void:
	var s := status
	leave()
	status = s
	changed.emit()


# ---------------- lobby / start ----------------
@rpc("authority", "call_remote", "reliable")
func _sync_lobby(diff: String) -> void:
	if game != null: game.net_set_difficulty(diff)


func send_difficulty(diff: String) -> void:
	if active() and is_host: _sync_lobby.rpc(diff)


func start_match(seed: int, diff: String) -> void:
	if not (active() and is_host): return
	partner_result = ""
	ready_waves = {}
	_start.rpc(seed, diff)


@rpc("authority", "call_local", "reliable")
func _start(seed: int, diff: String) -> void:
	partner_result = ""
	if game != null: game.net_start(seed, diff)


# ---------------- waves: host is the master ----------------
func wave_done(w: int) -> void:
	# called by each peer when its wave timer ran out (and the card, if any, was picked)
	if not active(): return
	if is_host: _ready_for.call(1, w)
	else: _ready_for.rpc_id(1, multiplayer.get_unique_id(), w)


@rpc("any_peer", "call_remote", "reliable")
func _ready_for(id: int, w: int) -> void:
	if not is_host: return
	ready_waves[id] = w
	var all_ready: bool = ready_waves.get(1, 0) >= w
	for pid in multiplayer.get_peers():
		if ready_waves.get(pid, 0) < w: all_ready = false
	if all_ready: _next_wave.rpc(w + 1)


@rpc("authority", "call_local", "reliable")
func _next_wave(w: int) -> void:
	if game != null: game.net_next_wave(w)


func send_speed(s: int) -> void:
	if active() and is_host: _speed.rpc(s)


@rpc("authority", "call_remote", "reliable")
func _speed(s: int) -> void:
	if game != null: game.speed = s


# ---------------- results, gifts, snapshots ----------------
func send_result(won: bool, reason: String) -> void:
	if active(): _result.rpc(won, reason)


@rpc("any_peer", "call_remote", "reliable")
func _result(won: bool, reason: String) -> void:
	partner_result = "won" if won else "lost"
	if game != null: game.on_partner_result(won, reason)
	changed.emit()


func send_gold(amount: int) -> void:
	if active(): _gift.rpc(amount)


@rpc("any_peer", "call_remote", "reliable")
func _gift(amount: int) -> void:
	if game != null: game.on_gift(amount)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _snap(data: Dictionary) -> void:
	partner_snap = data
	partner_snap["t"] = Time.get_ticks_msec()
	if game != null: game.on_partner_snap(data)


func _process(delta: float) -> void:
	if not active() or game == null or not game.started: return
	snap_t -= delta
	if snap_t > 0.0: return
	snap_t = SNAP_EVERY
	_snap.rpc(game.make_snapshot())
