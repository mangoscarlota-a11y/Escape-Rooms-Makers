extends RefCounted
## Datos de un escape room (guardar, cargar y comprobar que se puede resolver).
## Formato: {"name": String, "rooms": [{"objects": [{"id", "type", "x", "y", "z", "rot", "props": {...}}]}, ...]}
## Las salas se recorren en orden: la puerta de cada sala lleva a la siguiente y la de la última es la salida.
## El formato antiguo (una sola lista "objects") se convierte solo en un escape room de una sala.

const Catalog = preload("res://catalog.gd")
const Shell = preload("res://shell.gd")

const DIR := "user://salas"
const CONFIG_PATH := "user://ajustes.cfg"
const MAX_OBJECTS := 150 # por sala (sin contar la puerta)
const MAX_ROOMS := 6


## La puerta de salida de una sala; su posición depende de la forma de la sala.
static func default_door(shape := "cuadrada") -> Dictionary:
	var p := Shell.door_pos(shape)
	return {"id": 0, "type": "puerta_salida", "x": p.x, "y": 0.0, "z": p.z, "rot": Shell.door_rot(shape),
		"props": {"lock": "Llave", "needs": "Dorada", "code": "1234"}}


static func new_room() -> Dictionary:
	return {
		"name": "Mi sala",
		"rooms": [{"shape": "cuadrada", "objects": [default_door("cuadrada")]}],
	}


## ¿Cabe este tipo de objeto en esa posición de la forma de sala? (los de pared solo necesitan estar dentro)
static func fits_object(shape: String, type: String, x: float, z: float, rot := 0) -> bool:
	if Catalog.is_wall(type):
		return Shell.fits(shape, x, z, 0.0)
	if Catalog.is_long(type):
		# Paredes y puertas interiores: se usa su tamaño real, girado según `rot`.
		var sz: Vector3 = Catalog.TYPES[type]["size"]
		var hx := sz.x / 2.0
		var hz := sz.z / 2.0
		if rot % 180 == 90:
			hx = sz.z / 2.0
			hz = sz.x / 2.0
		return Shell.fits_box(shape, x, z, hx, hz)
	return Shell.fits(shape, x, z, 0.3)


## ¿Alguna salida alternativa (como un cuadro con pasadizo) se puede abrir con las llaves disponibles?
static func _alt_exit_ok(exits: Array, available: Dictionary) -> bool:
	for n in exits:
		if str(n) == "" or available.has(str(n)):
			return true
	return false


static func _path(room_name: String) -> String:
	var n := room_name.validate_filename().strip_edges()
	if n.is_empty():
		n = "sala"
	return DIR + "/" + n + ".json"


## Guarda la sala. Devuelve la ruta, o "" si falló.
static func save_room(data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := _path(str(data.get("name", "sala")))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return path


## Borra una sala guardada. Devuelve true si el archivo ya no existe.
static func delete_room(room_name: String) -> bool:
	var path := DIR + "/" + room_name + ".json"
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(path) == OK


static func load_room(room_name: String) -> Dictionary:
	var path := DIR + "/" + room_name + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d := sanitize(parsed, room_name)
	d["name"] = room_name
	return d


static func _num(v, default: float, lo: float, hi: float) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return clampf(float(v), lo, hi)
	return default


static func _clean_color(v, allow_empty: bool, default: String) -> String:
	var c := str(v)
	if Catalog.KEY_COLORS.has(c) or (allow_empty and c == ""):
		return c
	return default


static func _clean_digits(v, count: int, default: String) -> String:
	var s := str(v)
	if s.length() != count:
		return default
	for ch in s:
		if ch < "0" or ch > "9":
			return default
	return s


static func _clean_pattern(v, default: String) -> String:
	var s := str(v)
	if s.length() != 3:
		return default
	for ch in s:
		if ch != "0" and ch != "1":
			return default
	return s


## Limpia un objeto de inventario: "Llave Roja", "Tarjeta Azul" o (si allow_code) "Código 4721".
## Acepta el formato antiguo (solo el color, que era una llave).
static func _clean_item(v, allow_code: bool, default: String) -> String:
	var s := str(v)
	if s == "":
		return ""
	var norm := Catalog.item_name(s)
	for c in Catalog.KEY_COLORS:
		if norm == "Llave " + str(c) or norm == "Tarjeta " + str(c):
			return norm
	if allow_code and norm.begins_with("Código "):
		if _clean_digits(norm.substr(7), 4, "") != "":
			return norm
	return default


static func _clean_sequence(v, default: String) -> String:
	var s := str(v)
	if s.length() != 4:
		return default
	for ch in s:
		if not "RAVD".contains(ch):
			return default
	return s


static func _clean_props(type: String, raw) -> Dictionary:
	var p := Catalog.default_props(type)
	if typeof(raw) != TYPE_DICTIONARY:
		return p
	match type:
		"llave", "tarjeta":
			p["color"] = _clean_color(raw.get("color"), false, "Dorada")
		"cofre", "cofre_misterioso":
			p["needs"] = _clean_item(raw.get("needs"), false, "")
			p["gives"] = _clean_item(raw.get("gives"), true, "")
		"puerta_salida", "puerta_interior":
			var raw_needs := str(raw.get("needs", ""))
			var lock := str(raw.get("lock", ""))
			if not ["Llave", "Tarjeta", "Código", "Ninguna"].has(lock):
				# datos antiguos: sin color = sin cerradura; con color = llave
				lock = "Llave" if raw_needs != "" else "Ninguna"
			p["lock"] = lock
			p["needs"] = _clean_color(raw_needs, false, "Dorada")
			p["code"] = _clean_digits(raw.get("code"), 4, "1234")
		"nota":
			p["text"] = str(raw.get("text", "")).substr(0, 160)
		"cuadro":
			var style := str(raw.get("style", "Paisaje"))
			p["style"] = style if Catalog.STYLES.has(style) else "Paisaje"
			p["text"] = str(raw.get("text", "")).substr(0, 160)
		"cuadro_secreto":
			var secret_style := str(raw.get("style", "Paisaje"))
			p["style"] = secret_style if Catalog.STYLES.has(secret_style) else "Paisaje"
			p["gives"] = _clean_item(raw.get("gives"), true, "Llave Dorada")
		"caja_fuerte", "cofre_codigo":
			p["code"] = _clean_digits(raw.get("code"), 4, "1234")
			p["gives"] = _clean_item(raw.get("gives"), true, "Llave Dorada")
		"acertijo":
			p["question"] = str(raw.get("question", "")).substr(0, 120)
			p["answer"] = str(raw.get("answer", "")).substr(0, 40)
			p["gives"] = _clean_item(raw.get("gives"), true, "Llave Dorada")
		"interruptores":
			p["pattern"] = _clean_pattern(raw.get("pattern"), "101")
			p["gives"] = _clean_item(raw.get("gives"), true, "Llave Dorada")
		"cuadro_pasadizo":
			p["needs"] = _clean_item(raw.get("needs"), false, "")
			var pass_mode := str(raw.get("mode", "Salida"))
			p["mode"] = pass_mode if ["Salida", "Abertura"].has(pass_mode) else "Salida"
		"cuadro_cofre":
			var chest_style := str(raw.get("style", "Paisaje"))
			p["style"] = chest_style if Catalog.STYLES.has(chest_style) else "Paisaje"
			p["needs"] = _clean_item(raw.get("needs"), false, "")
			p["gives"] = _clean_item(raw.get("gives"), true, "")
		"panel_colores":
			p["sequence"] = _clean_sequence(raw.get("sequence"), "RAVD")
			p["gives"] = _clean_item(raw.get("gives"), true, "Llave Dorada")
		"reloj":
			p["time"] = _clean_digits(raw.get("time"), 4, "1030")
	return p


## Limpia los objetos de UNA sala (datos no confiables). La puerta siempre queda la primera.
static func _clean_objects(src, shape: String) -> Array:
	var door := default_door(shape)
	var objects: Array = []
	if typeof(src) == TYPE_ARRAY:
		var next_id := 1
		for o in src:
			if typeof(o) != TYPE_DICTIONARY:
				continue
			var type := str(o.get("type", ""))
			if not Catalog.TYPES.has(type):
				continue
			if type == "puerta_salida":
				door["props"] = _clean_props(type, o.get("props", {}))
				continue
			if objects.size() >= MAX_OBJECTS:
				continue
			var ox := _num(o.get("x"), 0.0, -30.0, 30.0)
			var oz := _num(o.get("z"), 0.0, -30.0, 30.0)
			var orot := (int(round(_num(o.get("rot"), 0.0, 0.0, 360.0) / 90.0)) * 90) % 360
			if not fits_object(shape, type, ox, oz, orot):
				continue # fuera de la forma de la sala
			objects.append({
				"id": next_id, "type": type,
				"x": ox,
				"y": _num(o.get("y"), 0.0, 0.0, 3.0),
				"z": oz,
				"rot": (int(round(_num(o.get("rot"), 0.0, 0.0, 360.0) / 90.0)) * 90) % 360,
				"props": _clean_props(type, o.get("props", {})),
			})
			next_id += 1
	objects.insert(0, door)
	return objects


## Limpia un escape room venido de un archivo o del servidor: solo deja tipos conocidos,
## posiciones dentro de la sala, propiedades válidas y un máximo de salas y objetos.
static func sanitize(raw, fallback_name := "Sala") -> Dictionary:
	var room_name := fallback_name
	var rooms: Array = []
	if typeof(raw) == TYPE_DICTIONARY:
		room_name = str(raw.get("name", fallback_name)).substr(0, 40)
		var src = raw.get("rooms")
		if typeof(src) == TYPE_ARRAY:
			for r in src:
				if rooms.size() >= MAX_ROOMS:
					break
				if typeof(r) == TYPE_DICTIONARY:
					var shape := str(r.get("shape", "cuadrada"))
					if not Shell.SHAPES.has(shape):
						shape = "cuadrada"
					rooms.append({"shape": shape, "objects": _clean_objects(r.get("objects"), shape)})
		elif raw.has("objects"):
			rooms.append({"shape": "cuadrada", "objects": _clean_objects(raw.get("objects"), "cuadrada")}) # formato antiguo
	if rooms.is_empty():
		rooms.append({"shape": "cuadrada", "objects": _clean_objects([], "cuadrada")})
	if room_name.strip_edges() == "":
		room_name = fallback_name
	return {"name": room_name, "rooms": rooms}


## Nombre de sala que no pisa a una ya guardada: "Sala", "Sala (2)", ...
static func unique_name(base: String) -> String:
	var n := base.validate_filename().strip_edges()
	if n.is_empty():
		n = "sala"
	var candidate := n
	var i := 2
	while FileAccess.file_exists(DIR + "/" + candidate + ".json"):
		candidate = "%s (%d)" % [n, i]
		i += 1
	return candidate


static func load_author() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		return str(cfg.get_value("perfil", "autor", ""))
	return ""


static func save_author(author: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("perfil", "autor", author)
	cfg.save(CONFIG_PATH)


static func list_rooms() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out


## Devuelve avisos si el escape room no se puede resolver (lista vacía = todo bien).
## El inventario empieza vacío en cada sala, así que cada sala se comprueba por separado.
static func validate(data: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	var rooms: Array = data["rooms"]
	for ri in rooms.size():
		var available := {}  # objetos que el jugador puede llegar a tener en ESTA sala
		var chests: Array = []
		var door_req := ""
		var alt_exits: Array = []    # lo que piden los cuadros con pasadizo secreto
		var inner_doors: Array = []  # lo que piden las puertas interiores
		for o in rooms[ri]["objects"]:
			var props: Dictionary = o.get("props", {})
			match str(o["type"]):
				"llave":
					available["Llave " + str(props.get("color", "Dorada"))] = true
				"tarjeta":
					available["Tarjeta " + str(props.get("color", "Azul"))] = true
				"cofre", "cofre_misterioso", "cuadro_cofre":
					chests.append(props)
				"cuadro_secreto", "caja_fuerte", "acertijo", "interruptores", "cofre_codigo", "panel_colores":
					# Puzzles que el jugador puede resolver solo: entregan su premio.
					var prize := Catalog.item_name(str(props.get("gives", "")))
					if prize != "":
						available[prize] = true
				"puerta_salida":
					door_req = str(Catalog.door_lock(props)["req"])
				"cuadro_pasadizo":
					if str(props.get("mode", "Salida")) != "Abertura": # una abertura no es una salida
						alt_exits.append(Catalog.item_name(str(props.get("needs", ""))))
				"puerta_interior":
					inner_doors.append(str(Catalog.door_lock(props)["req"]))

		var opened := {}
		var changed := true
		while changed:
			changed = false
			for i in chests.size():
				if opened.has(i):
					continue
				var needs := Catalog.item_name(str(chests[i].get("needs", "")))
				if needs == "" or available.has(needs):
					opened[i] = true
					var gives := Catalog.item_name(str(chests[i].get("gives", "")))
					if gives != "":
						available[gives] = true
					changed = true

		var where: String = ""
		if rooms.size() > 1:
			where = " de la sala %d" % (ri + 1)
		for i in chests.size():
			if not opened.has(i):
				warnings.append("Un cofre%s necesita «%s», pero no se puede conseguir en esa sala." % [where, Catalog.item_name(str(chests[i].get("needs", "")))])
		for n in inner_doors:
			if str(n) != "" and not available.has(str(n)):
				warnings.append("Una puerta interior%s necesita «%s», pero no se puede conseguir en esa sala." % [where, str(n)])
		if door_req != "" and not available.has(door_req) and not _alt_exit_ok(alt_exits, available):
			warnings.append("La puerta%s necesita «%s», pero no se puede conseguir en esa sala (el inventario empieza vacío en cada sala)." % [where, door_req])
			break # las salas siguientes no se pueden alcanzar
	return warnings
