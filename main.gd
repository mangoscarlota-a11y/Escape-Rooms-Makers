extends Node3D
## Menú principal y cambio entre modos: tutorial, creador y jugar salas guardadas.

const RoomBuilder = preload("res://room_builder.gd")
const PlayerScript = preload("res://player.gd")
const Shell = preload("res://shell.gd")
const Catalog = preload("res://catalog.gd")
const RoomData = preload("res://room_data.gd")
const Creator = preload("res://creator.gd")
const OnlineScript = preload("res://online.gd")
const Economy = preload("res://economy.gd")

var scene_root: Node3D = null
var menu_layer: CanvasLayer = null
var return_to_creator := false
var last_data: Dictionary = {}
var online: OnlineScript = null
var play_reward_key := ""   # premio (una sola vez) por escapar de la sala que se está jugando
var play_reward_amt := 0


func _ready() -> void:
	online = OnlineScript.new()
	add_child(online)
	show_menu()


# ------------------------------------------------------------------ utilidades

func _clear() -> void:
	if scene_root != null:
		scene_root.queue_free()
		scene_root = null
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null


func _new_container(bright: bool) -> Node3D:
	_clear()
	scene_root = Node3D.new()
	add_child(scene_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16) if bright else Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.85, 0.8)
	env.ambient_light_energy = 0.8 if bright else 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = not bright
	env.glow_enabled = not bright
	var we := WorldEnvironment.new()
	we.environment = env
	scene_root.add_child(we)

	if bright:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-60, 30, 0)
		sun.shadow_enabled = true
		scene_root.add_child(sun)
	return scene_root


func _spawn_player(parent: Node3D, pos: Vector3, inv: Array = [], yaw := 0.0) -> PlayerScript:
	var player := PlayerScript.new()
	player.position = pos
	player.rotation.y = deg_to_rad(yaw)
	player.inventory.assign(inv)
	player.menu_requested.connect(_on_player_menu)
	parent.add_child(player)
	player.camera.current = true
	return player


func _on_player_menu() -> void:
	if return_to_creator:
		start_creator(last_data)
	else:
		show_menu()


# ------------------------------------------------------------------ modos

func start_tutorial() -> void:
	return_to_creator = false
	var c := _new_container(false)
	c.add_child(RoomBuilder.build_prefab_room())
	_spawn_player(c, Vector3(0, 0.1, 2.0)) # mirando hacia la puerta (norte, -Z)


## Juega la sala número `index` del escape room. `inv` es el inventario que trae el jugador.
func start_play(room: Dictionary, from_creator: bool, index := 0, inv: Array = []) -> void:
	return_to_creator = from_creator
	last_data = room
	var rooms: Array = room["rooms"]
	var is_last := index >= rooms.size() - 1
	var c := _new_container(false)
	var shape := str(rooms[index].get("shape", "cuadrada"))
	c.add_child(Shell.build(shape, true))
	var exit_bodies: Array = []  # puerta de salida y cuadros con pasadizo secreto
	for o in rooms[index]["objects"]:
		if not Catalog.TYPES.has(o["type"]):
			continue
		var props: Dictionary = (o["props"] as Dictionary).duplicate()
		var is_exit_obj: bool = o["type"] == "puerta_salida" or (o["type"] == "cuadro_pasadizo" and str(props.get("mode", "Salida")) != "Abertura")
		if o["type"] == "puerta_salida" or o["type"] == "cuadro_pasadizo":
			props["is_last"] = is_last
		var n := Catalog.make_object(o["type"], props, float(o["rot"]), true)
		n.position = Vector3(float(o["x"]), float(o["y"]), float(o["z"]))
		c.add_child(n)
		if is_exit_obj:
			var exit_body := n.get_node_or_null("Body")
			if exit_body != null:
				exit_bodies.append(exit_body)
	var player := _spawn_player(c, Shell.spawn_pos(shape), inv, Shell.spawn_yaw(shape))
	if rooms.size() > 1:
		var intro := "Sala %d de %d" % [index + 1, rooms.size()]
		if index > 0:
			intro += " · tu inventario empieza vacío"
		player.show_message(intro, 4.0)
	for b in exit_bodies:
		b.connect("unlocked", _on_door_unlocked.bind(room, from_creator, index, player))


## Se abrió la puerta de una sala que no es la última: pasa a la siguiente con el inventario vacío.
func _on_door_unlocked(_by, room: Dictionary, from_creator: bool, index: int, player) -> void:
	var rooms: Array = room["rooms"]
	if index >= rooms.size() - 1:
		# Era la puerta final: premio por escapar (una sola vez por sala).
		if play_reward_key != "" and is_instance_valid(player):
			var got := Economy.claim(play_reward_key, play_reward_amt)
			if got > 0:
				player.show_message("¡Lograste escapar! +%d monedas. Pulsa M para volver al menú." % got, 7.0)
		return
	await get_tree().create_timer(1.3).timeout
	if not is_instance_valid(player):
		return # el jugador volvió al menú o al editor mientras tanto
	start_play(room, from_creator, index + 1, []) # el inventario se vacía al cambiar de sala


func start_creator(room: Dictionary) -> void:
	return_to_creator = false
	last_data = room
	var c := _new_container(true)
	var creator := Creator.new()
	creator.data = room
	creator.exit_requested.connect(show_menu)
	creator.test_requested.connect(func(d): _begin_play(d, true, "probar:" + str(d["name"]), 15))
	creator.publish_requested.connect(_on_publish.bind(creator))
	c.add_child(creator)


## Empieza a jugar una sala desde la primera. `key` y `amount` son el premio por escapar (key vacío = sin premio).
func _begin_play(room: Dictionary, from_creator: bool, key: String, amount: int) -> void:
	play_reward_key = key
	play_reward_amt = amount
	start_play(room, from_creator)


func _play_saved(room_name: String) -> void:
	var d := RoomData.load_room(room_name)
	if not d.is_empty():
		_begin_play(d, false, "", 0)


func _edit_saved(room_name: String) -> void:
	var d := RoomData.load_room(room_name)
	if not d.is_empty():
		start_creator(d)


# ------------------------------------------------------------------ menú

## Publica la sala del editor en el servidor.
func _on_publish(room: Dictionary, author: String, creator) -> void:
	if not online.is_configured():
		creator.show_message("Falta configurar el servidor: edita online_config.gd (mira el README).")
		return
	creator.show_message("Publicando sala...")
	var r: Dictionary = await online.publish_room(room, author)
	if not is_instance_valid(creator):
		return
	if r["ok"]:
		var got := Economy.claim("publicar:" + str(room["name"]), 30)
		var extra := ""
		if got > 0:
			extra = " ¡Ganaste %d monedas!" % got
			creator.refresh_coins()
		creator.show_message("¡Sala publicada! Ya aparece en «Salas de la comunidad»." + extra)
	else:
		creator.show_message("No se pudo publicar: " + str(r["error"]))


## Pantalla con las salas que han publicado otros jugadores.
func show_community() -> void:
	_clear()
	return_to_creator = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Salas de la comunidad"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 320)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var refresh := Button.new()
	refresh.text = "Actualizar"
	refresh.pressed.connect(_load_community.bind(list, status))
	buttons.add_child(refresh)
	var back := Button.new()
	back.text = "Volver al menú"
	back.pressed.connect(show_menu)
	buttons.add_child(back)

	_load_community(list, status)


func _load_community(list: VBoxContainer, status: Label) -> void:
	if not online.is_configured():
		status.text = "El servidor todavía no está configurado (mira el README)."
		return
	status.text = "Cargando salas..."
	for c in list.get_children():
		c.queue_free()
	var r: Dictionary = await online.list_rooms()
	if not is_instance_valid(list):
		return
	if not r["ok"]:
		status.text = "No se pudo cargar: " + str(r["error"])
		return
	var rows: Array = r["data"]
	status.text = "" if rows.size() > 0 else "Todavía no hay salas publicadas. ¡Publica la primera!"
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s — por %s" % [str(item.get("name", "?")), str(item.get("author", "?"))]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var id := str(item.get("id", ""))
		var play_b := Button.new()
		play_b.text = "Jugar"
		play_b.pressed.connect(_play_online.bind(id, status))
		row.add_child(play_b)
		var copy_b := Button.new()
		copy_b.text = "Guardar copia"
		copy_b.pressed.connect(_copy_online.bind(id, status))
		row.add_child(copy_b)
		list.add_child(row)


func _play_online(id: String, status: Label) -> void:
	status.text = "Descargando sala..."
	var r: Dictionary = await online.download_room(id)
	if not is_instance_valid(status):
		return
	if not r["ok"]:
		status.text = "No se pudo descargar: " + str(r["error"])
		return
	_begin_play(r["data"], false, "jugar:" + id, 10)


func _copy_online(id: String, status: Label) -> void:
	status.text = "Descargando sala..."
	var r: Dictionary = await online.download_room(id)
	if not is_instance_valid(status):
		return
	if not r["ok"]:
		status.text = "No se pudo descargar: " + str(r["error"])
		return
	var d: Dictionary = r["data"]
	d["name"] = RoomData.unique_name(str(d["name"]))
	if RoomData.save_room(d) != "":
		status.text = "Guardada en «Mis salas» como: " + str(d["name"])
	else:
		status.text = "No se pudo guardar la sala."


## Tienda: se compran objetos y formas de sala con las monedas.
func show_shop(msg := "") -> void:
	_clear()
	return_to_creator = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "Tienda"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var coins_l := Label.new()
	coins_l.text = "Tus monedas: %d" % Economy.coins()
	coins_l.add_theme_font_size_override("font_size", 20)
	coins_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	coins_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(coins_l)

	var tip := Label.new()
	tip.text = "Ganas monedas al terminar el tutorial, guardar y publicar tus salas, probarlas y escapar de las de otros."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(700, 0)
	tip.add_theme_font_size_override("font_size", 14)
	box.add_child(tip)

	var status := Label.new()
	status.text = msg
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 380)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var h1 := Label.new()
	h1.text = "Objetos"
	h1.add_theme_font_size_override("font_size", 22)
	list.add_child(h1)
	for t in Catalog.PLACEABLE:
		var tid: String = t
		var price := Catalog.price(tid)
		if price <= 0:
			continue
		_shop_row(list, str(Catalog.TYPES[tid]["name"]), str(Catalog.TYPES[tid].get("desc", "")), "obj", tid, price)

	var h2 := Label.new()
	h2.text = "Formas de sala"
	h2.add_theme_font_size_override("font_size", 22)
	list.add_child(h2)
	for s in Shell.shape_ids():
		var sid: String = s
		var sprice := Shell.price(sid)
		if sprice <= 0:
			continue
		var shape: Dictionary = Shell.get_shape(sid)
		_shop_row(list, str(shape["name"]), str(shape.get("desc", "")), "shape", sid, sprice)

	var back := Button.new()
	back.text = "Volver al menú"
	back.custom_minimum_size = Vector2(260, 40)
	back.pressed.connect(show_menu)
	box.add_child(back)


func _shop_row(list: VBoxContainer, item_name: String, desc: String, kind: String, id: String, price: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := Label.new()
	nl.text = item_name
	info.add_child(nl)
	if desc != "":
		var dl := Label.new()
		dl.text = desc
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(430, 0)
		dl.add_theme_font_size_override("font_size", 13)
		dl.modulate = Color(1, 1, 1, 0.65)
		info.add_child(dl)
	row.add_child(info)
	var pl := Label.new()
	pl.text = "%d monedas" % price
	pl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	row.add_child(pl)
	var b := Button.new()
	b.custom_minimum_size = Vector2(100, 0)
	if Economy.owns(kind, id, price):
		b.text = "Comprado"
		b.disabled = true
	else:
		b.text = "Comprar"
		b.pressed.connect(_buy.bind(kind, id, price, item_name))
	row.add_child(b)
	list.add_child(row)


func _buy(kind: String, id: String, price: int, item_name: String) -> void:
	if Economy.buy(kind, id, price):
		show_shop("¡Compraste: %s!" % item_name)
	else:
		show_shop("No te alcanzan las monedas para: %s." % item_name)


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 46)
	b.pressed.connect(cb)
	return b


## Primer clic: pide confirmación. Segundo clic: borra la sala y recarga el menú.
func _ask_delete(b: Button, room_name: String) -> void:
	if b.text == "Borrar":
		b.text = "¿Seguro?"
		b.modulate = Color(1.0, 0.5, 0.5)
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(b) and b.text == "¿Seguro?":
				b.text = "Borrar"
				b.modulate = Color.WHITE)
		return
	RoomData.delete_room(room_name)
	show_menu()


func show_menu() -> void:
	_clear()
	return_to_creator = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Escape Room Maker"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var coins_label := Label.new()
	coins_label.text = "Monedas: %d" % Economy.coins()
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(coins_label)

	box.add_child(_menu_button("Tutorial (sala de práctica)", start_tutorial))
	box.add_child(_menu_button("Crear una sala nueva", func(): start_creator(RoomData.new_room())))
	box.add_child(_menu_button("Salas de la comunidad", show_community))
	box.add_child(_menu_button("Tienda (objetos y formas de sala)", show_shop))

	var sub := Label.new()
	sub.text = "Mis salas guardadas"
	sub.add_theme_font_size_override("font_size", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 200)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var rooms := RoomData.list_rooms()
	if rooms.is_empty():
		var empty := Label.new()
		empty.text = "(todavía no has guardado ninguna sala)"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	for n in rooms:
		var row := HBoxContainer.new()
		var nl := Label.new()
		nl.text = n
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var play_b := Button.new()
		play_b.text = "Jugar"
		play_b.pressed.connect(_play_saved.bind(n))
		row.add_child(play_b)
		var edit_b := Button.new()
		edit_b.text = "Editar"
		edit_b.pressed.connect(_edit_saved.bind(n))
		row.add_child(edit_b)
		var del_b := Button.new()
		del_b.text = "Borrar"
		del_b.pressed.connect(_ask_delete.bind(del_b, n))
		row.add_child(del_b)
		list.add_child(row)
