extends Node3D
## Modo creador: cámara libre, colocar / mover / girar / borrar objetos y editar sus propiedades.

const Catalog = preload("res://catalog.gd")
const RoomData = preload("res://room_data.gd")
const Shell = preload("res://shell.gd")
const Economy = preload("res://economy.gd")

signal exit_requested
signal test_requested(room)
signal publish_requested(room, author)

const HINT := "Clic izq: colocar o seleccionar (arrastra para mover) · Mantén clic der + WASD: volar (Q/E: bajar/subir) · Rueda: acercar · R: girar · Supr: borrar · Esc: soltar herramienta"

var data: Dictionary = {}
var nodes := {}          # id -> Node3D
var next_id := 1
var current_tool := "select"
var selected_id := -1
var ghost: Node3D = null
var ghost_rot := 0
var drag_pending := false
var dragging := false
var press_pos := Vector2.ZERO
var warned := false

var cam: Camera3D
var yaw := 0.0
var pitch := deg_to_rad(-45.0)
var looking := false
var highlight: MeshInstance3D = null

var top_bar: PanelContainer
var left_panel: PanelContainer
var props_panel: PanelContainer
var props_box: VBoxContainer
var name_edit: LineEdit
var author_edit: LineEdit
var room_select: OptionButton
var cur_room := 0
var del_pending := false
var shell_node: Node3D = null
var shape_select: OptionButton
var shape_ids_shown: Array = []
var coins_label: Label
var wall_rot := 0
var status_label: Label
var tool_buttons := {}
var palette_box: VBoxContainer
var palette_group: ButtonGroup
var search_edit: LineEdit
var collapsed := {}      # categoría -> plegada


func _ready() -> void:
	cam = Camera3D.new()
	cam.position = Shell.cam_start(cur_shape())
	add_child(cam)
	cam.current = true
	_apply_camera()
	_build_ui()
	_refresh_room_select()
	_refresh_shape_select()
	_rebuild_shell()
	_load_room_nodes()
	name_edit.text = str(data.get("name", "Mi sala"))
	_set_tool("select")
	_refresh_status()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ cámara

func _apply_camera() -> void:
	cam.rotation = Vector3(pitch, yaw, 0.0)


func _process(delta: float) -> void:
	if looking and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fly(delta)
	_update_ghost()
	_update_drag()


func _fly(delta: float) -> void:
	if not looking:
		return
	var b := cam.global_transform.basis
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= b.z
	if Input.is_key_pressed(KEY_S):
		dir += b.z
	if Input.is_key_pressed(KEY_A):
		dir -= b.x
	if Input.is_key_pressed(KEY_D):
		dir += b.x
	if Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		dir -= Vector3.UP
	if dir != Vector3.ZERO:
		var speed := 7.0 * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		cam.global_position += dir.normalized() * speed * delta


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				looking = mb.pressed
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					var fo := get_viewport().gui_get_focus_owner()
					if fo != null:
						fo.release_focus() # para que R / Supr vuelvan a funcionar tras escribir
					_on_left_press()
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					cam.global_position += -cam.global_transform.basis.z * 0.8
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					cam.global_position += cam.global_transform.basis.z * 0.8
	elif event is InputEventMouseMotion and looking:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.003
		pitch = clampf(pitch - mm.relative.y * 0.003, -1.5, 1.5)
		_apply_camera()
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		match ke.keycode:
			KEY_R:
				_rotate_current()
			KEY_DELETE, KEY_BACKSPACE, KEY_X:
				_delete_selected()
			KEY_ESCAPE:
				if current_tool != "select":
					_set_tool("select")
				else:
					_select(-1)


func _on_left_press() -> void:
	get_viewport().gui_release_focus()
	if current_tool == "select":
		var hit := _mouse_ray(3)
		var id := -1
		if hit.size() > 0:
			id = _id_from_collider(hit["collider"])
		_select(id)
		if id != -1 and not _is_fixed(id):
			drag_pending = true
			press_pos = get_viewport().get_mouse_position()
	else:
		_place_current()


# ------------------------------------------------------------------ rayos y colocación

func _mouse_ray(mask: int) -> Dictionary:
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


## Punto donde caería un objeto bajo el cursor (suelo o la parte de arriba de otro objeto).
func _placement_point(info: Dictionary, rot := 0):
	if bool(info.get("wall", false)):
		# Objetos de pared: se pegan a la cara de la pared que mira hacia dentro de la sala.
		var whit := _mouse_ray(1)
		if whit.size() == 0 or absf(whit["normal"].y) > 0.3:
			return null
		var hit_id := _id_from_collider(whit["collider"])
		# Se puede colgar en las paredes de la sala y en las paredes de 2 m / 4 m, pero no en otros objetos.
		if hit_id != -1 and not Catalog.is_wall_block(str(_find(hit_id).get("type", ""))):
			return null
		var wn: Vector3 = whit["normal"]
		var wp: Vector3 = whit["position"]
		if not Shell.in_union(cur_shape(), wp.x + wn.x * 0.1, wp.z + wn.z * 0.1):
			return null
		var wsnap: float = info["snap"]
		# Solo se ajusta a la rejilla a lo largo de la pared; hacia la pared se queda pegado a su cara.
		if absf(wn.x) > absf(wn.z):
			wp.z = snappedf(wp.z, wsnap)
		else:
			wp.x = snappedf(wp.x, wsnap)
		if info.has("wall_y"):
			wp.y = float(info["wall_y"])
		else:
			wp.y = clampf(snappedf(wp.y, 0.25), 0.8, 2.3)
		wp += wn * 0.03
		wall_rot = (int(round(rad_to_deg(atan2(wn.x, wn.z)))) + 360) % 360
		return wp
	var hit := _mouse_ray(1)
	var p := Vector3.ZERO
	if hit.size() > 0 and hit["normal"].y > 0.7:
		p = hit["position"]
	else:
		var mp := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mp)
		var dir := cam.project_ray_normal(mp)
		if absf(dir.y) < 0.001:
			return null
		var t := -from.y / dir.y
		if t < 0.0:
			return null
		p = from + dir * t
	var snap: float = info["snap"]
	p.x = snappedf(p.x, snap)
	p.z = snappedf(p.z, snap)
	var ok := false
	if bool(info.get("long", false)):
		# Paredes y puertas interiores: se comprueba con su tamaño real, girado según `rot`.
		var sz: Vector3 = info["size"]
		var hx := sz.x / 2.0
		var hz := sz.z / 2.0
		if rot % 180 == 90:
			hx = sz.z / 2.0
			hz = sz.x / 2.0
		ok = Shell.fits_box(cur_shape(), p.x, p.z, hx, hz)
	else:
		ok = Shell.fits(cur_shape(), p.x, p.z, 0.3)
	if not ok:
		return null
	return p


func _over_ui(mp: Vector2) -> bool:
	for p in [top_bar, left_panel, props_panel]:
		if p.visible and p.get_global_rect().has_point(mp):
			return true
	return false


func _update_ghost() -> void:
	if ghost == null:
		return
	var mp := get_viewport().get_mouse_position()
	if looking or _over_ui(mp):
		ghost.visible = false
		return
	var p = _placement_point(Catalog.TYPES[current_tool], ghost_rot)
	if p == null:
		ghost.visible = false
		return
	ghost.visible = true
	ghost.position = p
	if Catalog.is_wall(current_tool):
		ghost.rotation.y = deg_to_rad(float(wall_rot))
	else:
		ghost.rotation.y = deg_to_rad(ghost_rot)


func _place_current() -> void:
	if ghost == null or not ghost.visible:
		return
	var id := next_id
	next_id += 1
	var o := {
		"id": id, "type": current_tool,
		"x": ghost.position.x, "y": ghost.position.y, "z": ghost.position.z,
		"rot": wall_rot if Catalog.is_wall(current_tool) else ghost_rot,
		"props": Catalog.default_props(current_tool),
	}
	_objs().append(o)
	_spawn_node(o)
	_modified()


# ------------------------------------------------------------------ arrastrar

func _update_drag() -> void:
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if (drag_pending or dragging) and not lmb:
		_finish_drag()
		return
	if drag_pending and not dragging:
		if get_viewport().get_mouse_position().distance_to(press_pos) > 6.0:
			dragging = true
			_set_body_layer(selected_id, 0) # que el rayo no choque con el propio objeto
	if dragging and nodes.has(selected_id):
		var o := _find(selected_id)
		var p = _placement_point(Catalog.TYPES[o["type"]], int(o["rot"]))
		if p != null:
			nodes[selected_id].position = p
			if Catalog.is_wall(o["type"]):
				nodes[selected_id].rotation.y = deg_to_rad(float(wall_rot))


func _finish_drag() -> void:
	if dragging and nodes.has(selected_id):
		var o := _find(selected_id)
		var n: Node3D = nodes[selected_id]
		o["x"] = n.position.x
		o["y"] = n.position.y
		o["z"] = n.position.z
		o["rot"] = (int(round(rad_to_deg(n.rotation.y))) + 360) % 360
		_restore_layer(selected_id)
		_modified()
	dragging = false
	drag_pending = false


func _set_body_layer(id: int, layer: int) -> void:
	if not nodes.has(id):
		return
	var n: Node3D = nodes[id]
	var b := n.get_node_or_null("Body") as StaticBody3D
	if b != null:
		b.collision_layer = layer


func _restore_layer(id: int) -> void:
	var o := _find(id)
	if o.is_empty():
		return
	var solid: bool = Catalog.TYPES[o["type"]]["solid"]
	_set_body_layer(id, 1 if solid else 2)


# ------------------------------------------------------------------ objetos

func _find(id: int) -> Dictionary:
	for o in _objs():
		if int(o["id"]) == id:
			return o
	return {}


func _is_fixed(id: int) -> bool:
	var o := _find(id)
	if o.is_empty():
		return false
	return bool(Catalog.TYPES[o["type"]].get("fixed", false))


func _id_from_collider(c) -> int:
	if c != null and c.has_meta("oid"):
		return int(c.get_meta("oid"))
	return -1


func _spawn_node(o: Dictionary) -> void:
	if not Catalog.TYPES.has(o["type"]):
		return
	var id := int(o["id"])
	if nodes.has(id) and is_instance_valid(nodes[id]):
		nodes[id].queue_free()
	var n := Catalog.make_object(o["type"], o["props"], float(o["rot"]), false)
	n.position = Vector3(float(o["x"]), float(o["y"]), float(o["z"]))
	add_child(n)
	var body := n.get_node_or_null("Body")
	if body != null:
		body.set_meta("oid", id)
	nodes[id] = n


func _rotate_current() -> void:
	if ghost != null:
		if not Catalog.is_wall(current_tool):
			ghost_rot = (ghost_rot + 90) % 360
	elif selected_id != -1 and not _is_fixed(selected_id):
		var o := _find(selected_id)
		if Catalog.is_wall(o["type"]):
			return # los objetos de pared siempre miran hacia la sala
		o["rot"] = (int(o["rot"]) + 90) % 360
		nodes[selected_id].rotation.y = deg_to_rad(float(o["rot"]))
		_modified()


func _delete_selected() -> void:
	if selected_id == -1 or _is_fixed(selected_id):
		return
	var id := selected_id
	_select(-1)
	if nodes.has(id):
		nodes[id].queue_free()
		nodes.erase(id)
	var objs: Array = _objs()
	for i in objs.size():
		if int(objs[i]["id"]) == id:
			objs.remove_at(i)
			break
	_modified()


func _set_tool(t: String) -> void:
	current_tool = t
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if t == "select":
		if tool_buttons.has("select"):
			tool_buttons["select"].button_pressed = true
		return
	_select(-1)
	ghost = Catalog.make_object(t, Catalog.default_props(t), ghost_rot, false)
	var body := ghost.get_node_or_null("Body")
	if body != null:
		ghost.remove_child(body)
		body.free()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.45)
	_tint(ghost, mat)
	ghost.visible = false
	add_child(ghost)


func _tint(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_tint(c, mat)


func _select(id: int) -> void:
	selected_id = id
	if is_instance_valid(highlight):
		highlight.queue_free()
	highlight = null
	if id != -1 and nodes.has(id):
		var o := _find(id)
		var sz: Vector3 = Catalog.TYPES[o["type"]]["size"]
		highlight = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz + Vector3(0.05, 0.05, 0.05)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.9, 0.2, 0.3)
		bm.material = mat
		highlight.mesh = bm
		var hy := sz.y / 2.0
		if Catalog.is_wall(o["type"]):
			hy = 0.0
		highlight.position = Vector3(0, hy, 0)
		nodes[id].add_child(highlight)
	_rebuild_props()


func _set_prop(key: String, value, rebuild := true) -> void:
	var o := _find(selected_id)
	if o.is_empty():
		return
	o["props"][key] = value
	_modified()
	if rebuild:
		var keep := selected_id
		_spawn_node(o)
		_select(keep)


func _modified() -> void:
	warned = false
	del_pending = false
	_refresh_status()


# ------------------------------------------------------------------ varias salas

## Objetos de la sala que se está editando.
func _objs() -> Array:
	return data["rooms"][cur_room]["objects"]


func _load_room_nodes() -> void:
	for id in nodes:
		if is_instance_valid(nodes[id]):
			nodes[id].queue_free()
	nodes.clear()
	next_id = 1
	for o in _objs():
		next_id = maxi(next_id, int(o["id"]) + 1)
		_spawn_node(o)


func cur_shape() -> String:
	return str(data["rooms"][cur_room].get("shape", "cuadrada"))


func refresh_coins() -> void:
	coins_label.text = "Monedas: %d" % Economy.coins()


func _rebuild_shell() -> void:
	if is_instance_valid(shell_node):
		shell_node.queue_free()
	shell_node = Shell.build(cur_shape(), false)
	add_child(shell_node)


## Formas disponibles: las que compraste y la que ya tiene esta sala.
func _refresh_shape_select() -> void:
	shape_select.clear()
	shape_ids_shown.clear()
	var current := cur_shape()
	for s in Shell.shape_ids():
		var sid: String = s
		if Economy.owns("shape", sid, Shell.price(sid)) or sid == current:
			shape_ids_shown.append(sid)
			shape_select.add_item(str(Shell.get_shape(sid)["name"]))
	shape_select.select(maxi(shape_ids_shown.find(current), 0))


func _on_shape_selected(i: int) -> void:
	if i < 0 or i >= shape_ids_shown.size():
		return
	var id: String = shape_ids_shown[i]
	if id == cur_shape():
		return
	var room: Dictionary = data["rooms"][cur_room]
	drag_pending = false
	dragging = false
	_select(-1)
	_set_tool("select")
	room["shape"] = id
	var door_p := Shell.door_pos(id)
	var kept: Array = []
	var removed := 0
	for o in room["objects"]:
		if str(o["type"]) == "puerta_salida":
			o["x"] = door_p.x
			o["z"] = door_p.z
			o["rot"] = Shell.door_rot(id)
			kept.append(o)
		elif RoomData.fits_object(id, str(o["type"]), float(o["x"]), float(o["z"]), int(o["rot"])):
			kept.append(o)
		else:
			removed += 1
	room["objects"] = kept
	_rebuild_shell()
	_load_room_nodes()
	_refresh_shape_select()
	_modified()
	if removed > 0:
		_status("Se quitaron %d objetos que no cabían en la forma nueva." % removed)


func _refresh_room_select() -> void:
	room_select.clear()
	for i in data["rooms"].size():
		room_select.add_item("Sala %d" % (i + 1))
	room_select.select(cur_room)


func _switch_room(i: int) -> void:
	if i == cur_room or i < 0 or i >= data["rooms"].size():
		room_select.select(cur_room)
		return
	drag_pending = false
	dragging = false
	_select(-1)
	_set_tool("select")
	cur_room = i
	del_pending = false
	_rebuild_shell()
	_refresh_shape_select()
	_load_room_nodes()
	room_select.select(cur_room)
	_refresh_status()


func _add_room() -> void:
	if data["rooms"].size() >= RoomData.MAX_ROOMS:
		_status("Un escape room puede tener como máximo %d salas." % RoomData.MAX_ROOMS)
		return
	data["rooms"].append({"shape": "cuadrada", "objects": [RoomData.default_door("cuadrada")]})
	_refresh_room_select()
	_switch_room(data["rooms"].size() - 1)
	_modified()


func _remove_room() -> void:
	if data["rooms"].size() <= 1:
		_status("Un escape room necesita al menos una sala.")
		return
	if not del_pending:
		del_pending = true
		_status("Se borrará la Sala %d con todo lo que tiene. Pulsa «Quitar sala» otra vez para confirmar." % (cur_room + 1))
		return
	drag_pending = false
	dragging = false
	_select(-1)
	_set_tool("select")
	data["rooms"].remove_at(cur_room)
	cur_room = mini(cur_room, data["rooms"].size() - 1)
	_rebuild_shell()
	_refresh_shape_select()
	_load_room_nodes()
	_refresh_room_select()
	_modified()


# ------------------------------------------------------------------ interfaz

func _place_ctrl(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Barra superior (dos filas)
	top_bar = PanelContainer.new()
	_place_ctrl(top_bar, 0, 0, 1, 0, 0, 0, 0, 88)
	layer.add_child(top_bar)
	var rows := VBoxContainer.new()
	top_bar.add_child(rows)

	var hb := HBoxContainer.new()
	rows.add_child(hb)
	var lbl := Label.new()
	lbl.text = "Nombre:"
	hb.add_child(lbl)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(160, 0)
	hb.add_child(name_edit)
	var author_label := Label.new()
	author_label.text = "Autor:"
	hb.add_child(author_label)
	author_edit = LineEdit.new()
	author_edit.custom_minimum_size = Vector2(150, 0)
	author_edit.max_length = 30
	author_edit.placeholder_text = "Anónimo"
	author_edit.text = RoomData.load_author()
	hb.add_child(author_edit)
	hb.add_child(VSeparator.new())
	hb.add_child(_button("Guardar", _on_save))
	hb.add_child(_button("Probar sala", _on_test))
	hb.add_child(_button("Publicar", _on_publish))
	hb.add_child(_button("Menú", _on_exit))
	coins_label = Label.new()
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hb.add_child(coins_label)
	refresh_coins()

	var hb2 := HBoxContainer.new()
	rows.add_child(hb2)
	var sala_label := Label.new()
	sala_label.text = "Sala:"
	hb2.add_child(sala_label)
	room_select = OptionButton.new()
	room_select.item_selected.connect(_switch_room)
	hb2.add_child(room_select)
	hb2.add_child(_button("+ Sala", _add_room))
	hb2.add_child(_button("Quitar sala", _remove_room))
	hb2.add_child(VSeparator.new())
	var shape_label := Label.new()
	shape_label.text = "Forma:"
	hb2.add_child(shape_label)
	shape_select = OptionButton.new()
	shape_select.item_selected.connect(_on_shape_selected)
	hb2.add_child(shape_select)

	# Panel izquierdo: herramientas
	left_panel = PanelContainer.new()
	_place_ctrl(left_panel, 0, 0, 0, 1, 0, 92, 230, 0)
	layer.add_child(left_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lv)
	var title := Label.new()
	title.text = "Objetos"
	title.add_theme_font_size_override("font_size", 18)
	lv.add_child(title)
	var group := ButtonGroup.new()
	var sel := Button.new()
	sel.text = "Seleccionar / mover"
	sel.toggle_mode = true
	sel.button_group = group
	sel.pressed.connect(_set_tool.bind("select"))
	lv.add_child(sel)
	tool_buttons["select"] = sel
	lv.add_child(HSeparator.new())
	palette_group = group
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Buscar objeto..."
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(_on_search_changed)
	lv.add_child(search_edit)
	palette_box = VBoxContainer.new()
	palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(palette_box)
	_rebuild_palette()
	var shop_hint := Label.new()
	shop_hint.text = "Más objetos y formas de sala en la Tienda (menú principal)."
	shop_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_hint.custom_minimum_size = Vector2(160, 0)
	shop_hint.add_theme_font_size_override("font_size", 12)
	lv.add_child(shop_hint)

	# Panel derecho: propiedades del objeto seleccionado
	props_panel = PanelContainer.new()
	props_panel.custom_minimum_size = Vector2(290, 0)
	_place_ctrl(props_panel, 1, 0, 1, 0, -290, 92, 0, 92)
	layer.add_child(props_panel)
	props_box = VBoxContainer.new()
	props_panel.add_child(props_box)
	props_panel.visible = false

	# Línea de estado
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 6)
	_place_ctrl(status_label, 0, 1, 1, 1, 240, -52, -300, -8)
	layer.add_child(status_label)


func _on_search_changed(_t: String) -> void:
	_rebuild_palette()


func _on_category_toggled(cat: String) -> void:
	collapsed[cat] = not bool(collapsed.get(cat, false))
	_rebuild_palette()


## Reconstruye la lista de objetos según el buscador y las categorías plegadas.
func _rebuild_palette() -> void:
	for c in palette_box.get_children():
		palette_box.remove_child(c)
		c.queue_free()
	for k in tool_buttons.keys():
		if k != "select":
			tool_buttons.erase(k)
	var query := search_edit.text.strip_edges().to_lower()
	var searching := query != ""
	var shown := 0
	for cat in Catalog.CATEGORIES:
		var ids: Array = []
		for t in Catalog.PLACEABLE:
			var tid: String = t
			if Catalog.category(tid) != cat:
				continue
			if not Economy.owns("obj", tid, Catalog.price(tid)):
				continue # se compra en la tienda
			var nm := str(Catalog.TYPES[tid]["name"])
			if searching and nm.to_lower().find(query) == -1 and cat.to_lower().find(query) == -1:
				continue
			ids.append(tid)
		if ids.is_empty():
			continue
		var folded := bool(collapsed.get(cat, false)) and not searching
		var head := Button.new()
		head.text = ("▸ " if folded else "▾ ") + "%s (%d)" % [cat, ids.size()]
		head.flat = true
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		head.pressed.connect(_on_category_toggled.bind(cat))
		palette_box.add_child(head)
		if folded:
			continue
		for tid in ids:
			var b := Button.new()
			b.text = str(Catalog.TYPES[tid]["name"])
			b.toggle_mode = true
			b.button_group = palette_group
			b.clip_text = true
			b.pressed.connect(_set_tool.bind(tid))
			if tid == current_tool:
				b.button_pressed = true
			palette_box.add_child(b)
			tool_buttons[tid] = b
		shown += ids.size()
	if shown == 0 and searching:
		var none := Label.new()
		none.text = "Sin resultados (puede que esté en la Tienda)."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(190, 0)
		palette_box.add_child(none)


func _status(text: String) -> void:
	status_label.text = text


func _refresh_status() -> void:
	var w := RoomData.validate(data)
	if w.is_empty():
		_status(HINT)
	else:
		_status("Aviso: " + w[0])


func _rebuild_props() -> void:
	for c in props_box.get_children():
		props_box.remove_child(c)
		c.queue_free()
	props_panel.visible = selected_id != -1
	if selected_id == -1:
		return
	var o := _find(selected_id)
	var type: String = o["type"]
	var props: Dictionary = o["props"]

	var title := Label.new()
	title.text = Catalog.TYPES[type]["name"]
	title.add_theme_font_size_override("font_size", 18)
	props_box.add_child(title)

	match type:
		"llave":
			_add_option("Color de la llave", Catalog.KEY_COLORS, str(props.get("color", "Dorada")), "",
				func(v): _set_prop("color", v))
		"tarjeta":
			_add_option("Color de la tarjeta", Catalog.KEY_COLORS, str(props.get("color", "Azul")), "",
				func(v): _set_prop("color", v))
		"cofre", "cofre_misterioso":
			var chest_opts: Array = [""] + Catalog.KEY_COLORS
			_add_item_option("Se abre con", "needs", str(props.get("needs", "")), false, "Sin llave")
			_add_item_option("Contiene", "gives", str(props.get("gives", "")), true, "Nada")
		"puerta_salida":
			var door_note := Label.new()
			if cur_room < data["rooms"].size() - 1:
				door_note.text = "Esta puerta lleva a la sala siguiente."
			else:
				door_note.text = "Es la salida final del escape room."
			props_box.add_child(door_note)
			_add_door_lock_ui(props)
		"cuadro":
			_add_option("Estilo", Catalog.STYLES, str(props.get("style", "Paisaje")), "",
				func(v): _set_prop("style", v))
			_add_line("Pista (opcional)", str(props.get("text", "")), 160, false,
				func(v): _set_prop("text", v, false))
		"cuadro_secreto":
			var secret_opts: Array = [""] + Catalog.KEY_COLORS
			_add_option("Estilo", Catalog.STYLES, str(props.get("style", "Paisaje")), "",
				func(v): _set_prop("style", v))
			_add_item_option("Detrás hay", "gives", str(props.get("gives", "")), true, "Nada")
		"caja_fuerte", "cofre_codigo":
			var safe_opts: Array = [""] + Catalog.KEY_COLORS
			_add_line("Código (4 dígitos)", str(props.get("code", "1234")), 4, true,
				func(v): _set_prop("code", v, false))
			_add_item_option("Dentro hay", "gives", str(props.get("gives", "")), true, "Nada")
		"acertijo":
			var riddle_opts: Array = [""] + Catalog.KEY_COLORS
			_add_line("Pregunta", str(props.get("question", "")), 120, false,
				func(v): _set_prop("question", v, false))
			_add_line("Respuesta", str(props.get("answer", "")), 40, false,
				func(v): _set_prop("answer", v, false))
			_add_item_option("Premio", "gives", str(props.get("gives", "")), true, "Nada")
		"interruptores":
			var sw_opts: Array = [""] + Catalog.KEY_COLORS
			var pat := str(props.get("pattern", "101"))
			var sl := Label.new()
			sl.text = "Posición correcta (marcado = arriba)"
			props_box.add_child(sl)
			var srow := HBoxContainer.new()
			props_box.add_child(srow)
			for i in pat.length():
				var cb := CheckBox.new()
				cb.text = str(i + 1)
				cb.button_pressed = pat[i] == "1"
				cb.toggled.connect(_on_pattern_toggled.bind(i))
				srow.add_child(cb)
			_add_item_option("Premio", "gives", str(props.get("gives", "")), true, "Nada")
		"cuadro_pasadizo":
			var pass_note := Label.new()
			pass_note.text = "Abre un hueco en la pared (también en paredes de 2 m / 4 m). «Salida»: avisa y pasa a la siguiente sala o termina. «Abertura»: solo abre el hueco, sin avisar."
			pass_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pass_note.custom_minimum_size = Vector2(260, 0)
			props_box.add_child(pass_note)
			_add_option("Tipo", ["Salida", "Abertura"], str(props.get("mode", "Salida")), "",
				func(v): _set_prop("mode", v))
			_add_item_option("Se abre con", "needs", str(props.get("needs", "")), false, "Sin llave")
		"cuadro_cofre":
			var cc_opts: Array = [""] + Catalog.KEY_COLORS
			_add_option("Estilo", Catalog.STYLES, str(props.get("style", "Paisaje")), "",
				func(v): _set_prop("style", v))
			_add_item_option("El cofre se abre con", "needs", str(props.get("needs", "")), false, "Sin llave")
			_add_item_option("Dentro hay", "gives", str(props.get("gives", "")), true, "Nada")
		"panel_colores":
			var pc_opts: Array = [""] + Catalog.KEY_COLORS
			var pc_seq := str(props.get("sequence", "RAVD"))
			var pcl := Label.new()
			pcl.text = "Orden correcto de los 4 colores"
			props_box.add_child(pcl)
			var pcrow := HBoxContainer.new()
			props_box.add_child(pcrow)
			for i in 4:
				var ob := OptionButton.new()
				for color_name in Catalog.KEY_COLORS:
					ob.add_item(str(color_name))
				ob.select(maxi("RAVD".find(pc_seq[i]), 0))
				ob.item_selected.connect(_on_seq_changed.bind(i))
				pcrow.add_child(ob)
			_add_item_option("Premio", "gives", str(props.get("gives", "")), true, "Nada")
		"reloj":
			var clock_t := str(props.get("time", "1030"))
			var hours: Array = []
			for h in 12:
				hours.append("%02d" % h)
			var mins: Array = []
			for m in range(0, 60, 5):
				mins.append("%02d" % m)
			_add_option("Hora (0-11)", hours, clock_t.substr(0, 2), "",
				func(v): _set_prop("time", str(v) + clock_t.substr(2, 2)))
			_add_option("Minutos", mins, clock_t.substr(2, 2), "",
				func(v): _set_prop("time", clock_t.substr(0, 2) + str(v)))
		"puerta_interior":
			_add_door_lock_ui(props)
		"nota":
			var l := Label.new()
			l.text = "Texto de la nota"
			props_box.add_child(l)
			var le := LineEdit.new()
			le.max_length = 160
			le.text = str(props.get("text", ""))
			le.custom_minimum_size = Vector2(260, 0)
			le.text_changed.connect(func(t): _set_prop("text", t, false))
			props_box.add_child(le)

	if not _is_fixed(selected_id):
		props_box.add_child(HSeparator.new())
		props_box.add_child(_button("Girar 90° (R)", _rotate_current))
		props_box.add_child(_button("Borrar (Supr)", _delete_selected))


func _add_line(title: String, current: String, max_len: int, digits: bool, on_change: Callable) -> void:
	var l := Label.new()
	l.text = title
	props_box.add_child(l)
	var le := LineEdit.new()
	le.max_length = max_len
	le.text = current
	le.custom_minimum_size = Vector2(260, 0)
	le.text_changed.connect(_on_line_changed.bind(le, digits, on_change))
	props_box.add_child(le)


func _on_line_changed(t: String, le: LineEdit, digits: bool, on_change: Callable) -> void:
	var value := t
	if digits:
		var f := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				f += ch
		if f != t:
			le.text = f
			le.caret_column = f.length()
		value = f
	on_change.call(value)


func _on_seq_changed(color_idx: int, pos: int) -> void:
	var o := _find(selected_id)
	if o.is_empty():
		return
	var letters := "RAVD"
	var cur := str(o["props"].get("sequence", "RAVD"))
	cur = cur.substr(0, pos) + letters[color_idx] + cur.substr(pos + 1)
	_set_prop("sequence", cur, false)


func _on_pattern_toggled(pressed: bool, i: int) -> void:
	var o := _find(selected_id)
	if o.is_empty():
		return
	var pat := str(o["props"].get("pattern", "101"))
	var bit := "0"
	if pressed:
		bit = "1"
	pat = pat.substr(0, i) + bit + pat.substr(i + 1)
	_set_prop("pattern", pat, false)


## Lista de objetos (llaves, tarjetas y, si allow_code, un código) para "se abre con" / "contiene".
func _add_item_option(title: String, key: String, current: String, allow_code: bool, empty_label: String) -> void:
	var values: Array = [""]
	for c in Catalog.KEY_COLORS:
		values.append("Llave " + str(c))
	for c in Catalog.KEY_COLORS:
		values.append("Tarjeta " + str(c))
	if allow_code:
		values.append("Código")
	var cur := Catalog.item_name(current)
	var shown := cur
	if cur.begins_with("Código "):
		shown = "Código"
	var l := Label.new()
	l.text = title
	props_box.add_child(l)
	var ob := OptionButton.new()
	for v in values:
		ob.add_item(empty_label if str(v) == "" else str(v))
	ob.select(maxi(values.find(shown), 0))
	ob.item_selected.connect(_on_item_selected.bind(key, values))
	props_box.add_child(ob)
	if allow_code and cur.begins_with("Código "):
		_add_line("Código que se entrega (4 dígitos)", cur.substr(7), 4, true,
			func(v): _set_prop(key, "Código " + str(v), false))


func _on_item_selected(i: int, key: String, values: Array) -> void:
	var v := str(values[i])
	if v == "Código":
		v = "Código 1234"
	_set_prop(key, v)


## Cerradura de una puerta: llave, tarjeta, código o ninguna.
func _add_door_lock_ui(props: Dictionary) -> void:
	var locks := ["Llave", "Tarjeta", "Código", "Ninguna"]
	var lock := str(props.get("lock", "Llave"))
	_add_option("Cerradura", locks, lock, "", func(v): _set_prop("lock", v))
	if lock == "Llave" or lock == "Tarjeta":
		_add_option("Color de la %s" % lock.to_lower(), Catalog.KEY_COLORS, str(props.get("needs", "Dorada")), "",
			func(v): _set_prop("needs", v))
	elif lock == "Código":
		_add_line("Código de la puerta (4 dígitos)", str(props.get("code", "1234")), 4, true,
			func(v): _set_prop("code", v, false))


func _add_option(title: String, values: Array, current: String, empty_label: String,
		on_change: Callable) -> void:
	var l := Label.new()
	l.text = title
	props_box.add_child(l)
	var ob := OptionButton.new()
	for v in values:
		ob.add_item(empty_label if str(v) == "" else str(v))
	ob.select(maxi(values.find(current), 0))
	ob.item_selected.connect(func(i: int): on_change.call(values[i]))
	props_box.add_child(ob)


# ------------------------------------------------------------------ barra superior

func _save(silent := false) -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Mi sala"
	data["name"] = n
	var path := RoomData.save_room(data)
	if path == "":
		_status("No se pudo guardar la sala.")
		return
	# Premio (una sola vez por proyecto): al menos 3 objetos y que se pueda resolver.
	var count := 0
	for r in data["rooms"]:
		count += r["objects"].size() - 1
	var got := 0
	if count >= 3 and RoomData.validate(data).is_empty():
		got = Economy.claim("guardar:" + n, 20)
	if got > 0:
		refresh_coins()
		_status("Sala guardada: %s. ¡Ganaste %d monedas!" % [n, got])
	elif not silent:
		_status("Sala guardada: " + n)


func _on_save() -> void:
	_save()


func _on_test() -> void:
	_save(true)
	var w := RoomData.validate(data)
	if not w.is_empty() and not warned:
		warned = true
		_status("Aviso: " + w[0] + " — Pulsa «Probar sala» otra vez para jugarla de todos modos.")
		return
	test_requested.emit(data)


func _on_exit() -> void:
	_save(true)
	exit_requested.emit()


func _on_publish() -> void:
	_save(true)
	var total := 0
	for r in data["rooms"]:
		total += r["objects"].size() - 1 # sin contar la puerta
	if total < 1:
		_status("Agrega al menos un objeto antes de publicar la sala.")
		return
	var w := RoomData.validate(data)
	if not w.is_empty():
		_status("Arregla esto antes de publicar: " + w[0])
		return
	var author := author_edit.text.strip_edges()
	if author == "":
		author = "Anónimo"
	RoomData.save_author(author)
	publish_requested.emit(data, author)


## Muestra un mensaje en la línea de estado (lo usa main.gd).
func show_message(text: String) -> void:
	_status(text)
