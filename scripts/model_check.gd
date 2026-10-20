extends Node
# Model check scene: external 3D models (assets/models/*.glb) next to the procedural look, inside the real game.
# Left pair = .glb model, right pair = procedural. Starts paused; Space plays. Never touches the save file.
var t: Node


func _ready() -> void:
	t = load("res://scenes/toy2.tscn").instantiate()
	t.no_save = true
	add_child(t)
	_setup.call_deferred()


func _setup() -> void:
	t._begin(-1)
	t.gold = 99999
	t.wave = 40
	t.wave_t = 9999.0
	var a = t.art
	var real_dir: String = a.model_dir
	for glb in [true, false]:
		a.model_dir = real_dir if glb else "res://__none__"
		t._add_unit("bari", 3, 2 if glb else 4)            # 바리공주: board slots in front of the path
		t._spawn_enemy("bulgasari", false, 6.0 if glb else 10.0)   # 불가사리 on the top edge of the path
	a.model_dir = real_dir
	t.set_speed(0)
	t.cam_target = Vector3(1.5, 0, -4.2)
	t.cam_dist = 13.0
	t._update_cam()
	var has_bari := FileAccess.file_exists(real_dir + "/units/bari.glb")
	var has_bulga := FileAccess.file_exists(real_dir + "/yokai/bulgasari.glb")
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var lb := Label.new()
	lb.add_theme_font_override("font", t.font)
	lb.add_theme_font_size_override("font_size", 11)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", 4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.12, 0.8)
	bg.set_content_margin_all(5)
	lb.add_theme_stylebox_override("normal", bg)
	lb.position = Vector2(8, 252)
	lb.text = "모델 확인 — 왼쪽: 3D 모델(.glb) · 오른쪽: 기존 모델\n" + \
		"바리 .glb %s · 불가사리 .glb %s · 저장 안 됨\n" % ["있음" if has_bari else "없음", "있음" if has_bulga else "없음"] + \
		"Space 재생/정지 · 휠 줌 · 우클릭 드래그 이동 · Z 초기화"
	layer.add_child(lb)
