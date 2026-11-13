extends CharacterBody3D
## Jugador en primera persona. Se construye solo por código (cápsula, cámara, rayo, HUD).

signal menu_requested

const SPEED := 4.0
const SPRINT_SPEED := 6.5
const JUMP_VELOCITY := 4.2
const MOUSE_SENS := 0.0025
const REACH := 2.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var prompt_label: Label
var msg_label: Label

var _target: Object = null
var _msg_id := 0

var inventory: Array[String] = []
var inv_label: Label
var _left := false
var ui_open := false          # hay un cuadro de puzzle abierto (código, acertijo, interruptores)
var ui_root: Control = null
var hud_layer: CanvasLayer
var _pz := {}


func _ready() -> void:
	_setup_inputs()

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 75.0
	head.add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	camera.add_child(ray)
	ray.add_exception(self)
	ray.collision_mask = 3 # capa 1: objetos sólidos; capa 2: objetos pequeños que no bloquean

	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_inputs() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
		"menu": KEY_M,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if ui_open:
		if event.is_action_pressed("ui_cancel"):
			close_puzzle()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("menu"):
		menu_requested.emit()
	elif event.is_action_pressed("interact") and _target != null and is_instance_valid(_target):
		_target.interact(self)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not ui_open:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= gravity * delta

	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	var input_dir := Vector2.ZERO
	if not ui_open:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var weight := clampf((12.0 if is_on_floor() else 3.0) * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, weight)
	velocity.z = lerpf(velocity.z, dir.z * speed, weight)

	move_and_slide()
	_update_target()

	# Si sales por la puerta y caes al vacío, termina la partida.
	if global_position.y < -6.0 and not _left:
		_left = true
		menu_requested.emit()


func _update_target() -> void:
	_target = null
	if ray.is_colliding():
		var c = ray.get_collider()
		if c != null and c.has_method("interact"):
			_target = c
	if _target != null:
		prompt_label.text = "[E] " + str(_target.get("prompt_text"))
	else:
		prompt_label.text = ""


## Muestra un mensaje temporal en pantalla.
func show_message(text: String, seconds := 2.5) -> void:
	_msg_id += 1
	var id := _msg_id
	msg_label.text = text
	await get_tree().create_timer(seconds).timeout
	if id == _msg_id:
		msg_label.text = ""


## --- Puzzles: cuadros de diálogo ---

## Da una llave del color indicado y avisa en pantalla.
func give_key(given: String, prefix: String) -> void:
	# `given` puede ser "Llave Roja", "Tarjeta Azul", "Código 4721" o (datos antiguos) solo el color.
	var item := given
	if not (item.begins_with("Llave ") or item.begins_with("Tarjeta ") or item.begins_with("Código ")):
		item = "Llave " + item
	if not has_item(item):
		add_item(item)
	show_message(prefix + item + ".", 4.0)


## Abre un cuadro de puzzle. kind: "code" (dígitos), "text" (respuesta escrita) o "switches" (interruptores).
## `solution` es el código, la respuesta o el patrón ("101"). Si aciertas se llama a on_solved(jugador).
func open_puzzle(kind: String, title: String, prompt: String, solution: String, on_solved: Callable) -> void:
	if ui_open:
		return
	ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(center)
	ui_root = center
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	var p := Label.new()
	p.text = prompt
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(p)

	var edit: LineEdit = null
	var toggles: Array = []
	var seq_label: Label = null
	if kind == "switches":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		for i in solution.length():
			var b := Button.new()
			b.toggle_mode = true
			b.text = "APAGADO"
			b.custom_minimum_size = Vector2(100, 70)
			b.toggled.connect(_on_switch_toggled.bind(b))
			row.add_child(b)
			toggles.append(b)
	elif kind == "sequence":
		var crow := HBoxContainer.new()
		crow.alignment = BoxContainer.ALIGNMENT_CENTER
		crow.add_theme_constant_override("separation", 10)
		box.add_child(crow)
		var seq_defs := [
			["R", "Roja", Color(1.0, 0.35, 0.35)], ["A", "Azul", Color(0.4, 0.6, 1.0)],
			["V", "Verde", Color(0.4, 0.9, 0.5)], ["D", "Dorada", Color(1.0, 0.85, 0.3)],
		]
		for entry in seq_defs:
			var sb := Button.new()
			sb.text = str(entry[1])
			sb.custom_minimum_size = Vector2(90, 60)
			sb.modulate = entry[2]
			sb.pressed.connect(_on_seq_pressed.bind(str(entry[0])))
			crow.add_child(sb)
		seq_label = Label.new()
		seq_label.text = "(vacío)"
		seq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seq_label.add_theme_font_size_override("font_size", 20)
		box.add_child(seq_label)
		var clear_b := Button.new()
		clear_b.text = "Borrar"
		clear_b.pressed.connect(_on_seq_clear)
		box.add_child(clear_b)
	else:
		edit = LineEdit.new()
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.add_theme_font_size_override("font_size", 26)
		if kind == "code":
			edit.max_length = solution.length()
			edit.placeholder_text = "----"
			edit.text_changed.connect(_digits_only.bind(edit))
		else:
			edit.max_length = 40
			edit.placeholder_text = "Tu respuesta"
		edit.text_submitted.connect(_on_pz_submitted)
		box.add_child(edit)

	var msg := Label.new()
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	box.add_child(msg)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var ok_b := Button.new()
	ok_b.text = "Probar"
	ok_b.pressed.connect(_pz_submit)
	buttons.add_child(ok_b)
	var close_b := Button.new()
	close_b.text = "Cerrar"
	close_b.pressed.connect(close_puzzle)
	buttons.add_child(close_b)

	_pz = {"kind": kind, "solution": solution, "cb": on_solved, "edit": edit, "toggles": toggles, "msg": msg,
		"seq": "", "seq_label": seq_label}
	if edit != null:
		edit.grab_focus()


func close_puzzle() -> void:
	if ui_root != null:
		ui_root.queue_free()
		ui_root = null
	_pz = {}
	ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_seq_pressed(letter: String) -> void:
	if _pz.is_empty():
		return
	var cur := str(_pz["seq"])
	if cur.length() >= str(_pz["solution"]).length():
		return
	_pz["seq"] = cur + letter
	_update_seq_label()


func _on_seq_clear() -> void:
	if _pz.is_empty():
		return
	_pz["seq"] = ""
	_update_seq_label()


func _update_seq_label() -> void:
	var names := {"R": "Roja", "A": "Azul", "V": "Verde", "D": "Dorada"}
	var parts := PackedStringArray()
	for ch in str(_pz["seq"]):
		parts.append(str(names.get(ch, "?")))
	var lbl: Label = _pz["seq_label"]
	if parts.size() > 0:
		lbl.text = " - ".join(parts)
	else:
		lbl.text = "(vacío)"


func _on_switch_toggled(pressed: bool, b: Button) -> void:
	b.text = "ENCENDIDO" if pressed else "APAGADO"


func _digits_only(t: String, le: LineEdit) -> void:
	var f := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			f += ch
	if f != t:
		le.text = f
		le.caret_column = f.length()


func _on_pz_submitted(_t: String) -> void:
	_pz_submit()


func _norm(s: String) -> String:
	var t := s.strip_edges().to_lower()
	var map := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}
	for k in map:
		t = t.replace(k, map[k])
	return t


func _pz_submit() -> void:
	if _pz.is_empty():
		return
	var kind: String = _pz["kind"]
	var solution: String = _pz["solution"]
	var ans := ""
	if kind == "sequence":
		ans = str(_pz["seq"])
	elif kind == "switches":
		for b in _pz["toggles"]:
			if (b as Button).button_pressed:
				ans += "1"
			else:
				ans += "0"
	else:
		ans = (_pz["edit"] as LineEdit).text
	var ok := false
	if kind == "text":
		ok = _norm(ans) == _norm(solution)
	else:
		ok = ans == solution
	if ok:
		var cb: Callable = _pz["cb"]
		close_puzzle()
		cb.call(self)
	else:
		(_pz["msg"] as Label).text = "Incorrecto. Inténtalo de nuevo."


## --- Inventario ---
func add_item(item: String) -> void:
	inventory.append(item)
	_update_inventory_hud()


func has_item(item: String) -> bool:
	return inventory.has(item)


func remove_item(item: String) -> void:
	inventory.erase(item)
	_update_inventory_hud()


func _update_inventory_hud() -> void:
	if inventory.is_empty():
		inv_label.text = "Inventario: (vacío)"
	else:
		inv_label.text = "Inventario: " + ", ".join(inventory)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_layer = layer

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_right = 2
	dot.offset_top = -2
	dot.offset_bottom = 2
	layer.add_child(dot)

	prompt_label = _make_label(layer, 30)
	msg_label = _make_label(layer, 90)

	inv_label = Label.new()
	inv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_label.add_theme_font_size_override("font_size", 18)
	inv_label.add_theme_color_override("font_outline_color", Color.BLACK)
	inv_label.add_theme_constant_override("outline_size", 6)
	inv_label.position = Vector2(16, 16)
	layer.add_child(inv_label)
	_update_inventory_hud()

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "E: interactuar · M: menú · Esc: soltar ratón"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	hint.position = Vector2(16, 46)
	layer.add_child(hint)


func _make_label(layer: CanvasLayer, y: float) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -300
	l.offset_right = 300
	l.offset_top = y
	l.offset_bottom = y + 30
	layer.add_child(l)
	return l
