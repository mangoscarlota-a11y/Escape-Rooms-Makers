extends RefCounted
## Catálogo de objetos que se pueden colocar en una sala.
## Cada objeto se dibuja con piezas simples (cajas) y, en modo juego, recibe su lógica.

const Textures = preload("res://textures.gd")
const Interactable = preload("res://interactable.gd")

const KEY_COLORS := ["Roja", "Azul", "Verde", "Dorada"]
const COLOR_VALUES := {
	"Roja": Color(0.8, 0.15, 0.15),
	"Azul": Color(0.2, 0.4, 0.85),
	"Verde": Color(0.2, 0.65, 0.3),
	"Dorada": Color(0.9, 0.7, 0.15),
}
const GREY := Color(0.45, 0.45, 0.48)

# size = tamaño aproximado (también la colisión); pick = colisión más grande para objetos pequeños;
# snap = rejilla al colocar; solid = bloquea al jugador; fixed = no se puede borrar ni mover.
const TYPES := {
	"mesa": {"name": "Mesa", "size": Vector3(1.4, 0.8, 0.8), "snap": 0.25, "solid": true},
	"silla": {"name": "Silla", "size": Vector3(0.5, 0.95, 0.5), "snap": 0.25, "solid": true},
	"librero": {"name": "Librero", "size": Vector3(1.6, 2.0, 0.35), "snap": 0.25, "solid": true},
	"caja": {"name": "Caja", "size": Vector3(0.6, 0.6, 0.6), "snap": 0.25, "solid": true},
	"alfombra": {"name": "Alfombra", "size": Vector3(2.0, 0.02, 1.4), "snap": 0.25, "solid": false},
	"lampara": {"name": "Lámpara", "size": Vector3(0.22, 0.45, 0.22), "snap": 0.05, "solid": false},
	"cofre": {"name": "Cofre", "size": Vector3(0.8, 0.51, 0.5), "snap": 0.25, "solid": true},
	"llave": {"name": "Llave", "size": Vector3(0.28, 0.05, 0.07), "pick": Vector3(0.32, 0.12, 0.2), "snap": 0.05, "solid": false},
	"nota": {"name": "Nota", "size": Vector3(0.3, 0.02, 0.2), "pick": Vector3(0.34, 0.1, 0.24), "snap": 0.05, "solid": false},
	"puerta_salida": {"name": "Puerta de salida", "size": Vector3(1.0, 2.1, 0.1), "snap": 0.25, "solid": true, "fixed": true},
	# --- Objetos de la tienda (price = monedas; wall = se cuelga de la pared; desc = texto de la tienda) ---
	"sofa": {"name": "Sofá", "size": Vector3(1.8, 0.85, 0.85), "snap": 0.25, "solid": true, "price": 20,
		"desc": "Decoración para dar ambiente."},
	"planta": {"name": "Planta", "size": Vector3(0.45, 1.0, 0.45), "snap": 0.25, "solid": true, "price": 10,
		"desc": "Una maceta con hojas. Sirve para esconder cosas a la vista."},
	"cuadro": {"name": "Cuadro", "size": Vector3(1.0, 0.8, 0.06), "snap": 0.25, "solid": false, "wall": true, "price": 10,
		"desc": "Se cuelga de la pared (3 estilos). Puedes escribirle una pista que se lee al mirarlo."},
	"cuadro_secreto": {"name": "Cuadro secreto", "size": Vector3(1.0, 0.8, 0.06), "snap": 0.25, "solid": false, "wall": true, "price": 25,
		"desc": "Parece un cuadro normal, pero se abre y esconde una llave."},
	"caja_fuerte": {"name": "Caja fuerte", "size": Vector3(0.7, 0.6, 0.55), "snap": 0.25, "solid": true, "price": 40,
		"desc": "Se abre con un código de 4 dígitos que tú eliges."},
	"acertijo": {"name": "Libro de acertijo", "size": Vector3(0.3, 0.06, 0.22), "pick": Vector3(0.36, 0.14, 0.28), "snap": 0.05, "solid": false, "price": 30,
		"desc": "Hay que responder una pregunta para ganar una llave."},
	"interruptores": {"name": "Panel de interruptores", "size": Vector3(0.6, 0.5, 0.06), "snap": 0.25, "solid": false, "wall": true, "price": 35,
		"desc": "Hay que dejar los 3 interruptores en la posición correcta."},
	# (long = se acomoda según su tamaño real; wall_y = altura fija en la pared)
	"cofre_misterioso": {"name": "Cofre misterioso", "size": Vector3(0.8, 0.51, 0.5), "snap": 0.25, "solid": true, "price": 30,
		"desc": "Como un cofre, pero sin ninguna pista del color de la llave que necesita."},
	"cofre_codigo": {"name": "Cofre con candado de código", "size": Vector3(0.8, 0.51, 0.5), "snap": 0.25, "solid": true, "price": 35,
		"desc": "Un cofre con candado de combinación: se abre con un código de 4 dígitos."},
	"cuadro_pasadizo": {"name": "Cuadro con pasadizo secreto", "size": Vector3(1.0, 2.1, 0.06), "snap": 0.25, "solid": false, "wall": true, "wall_y": 1.05, "price": 60,
		"desc": "Un cuadro grande que se abre y deja pasar: es una salida secreta (a la sala siguiente o al final)."},
	"cuadro_cofre": {"name": "Cuadro con cofre escondido", "size": Vector3(1.0, 0.8, 0.06), "snap": 0.25, "solid": false, "wall": true, "price": 45,
		"desc": "Se abre y detrás hay un cofre (con o sin llave)."},
	"panel_colores": {"name": "Panel de colores", "size": Vector3(0.6, 0.2, 0.06), "snap": 0.25, "solid": false, "wall": true, "price": 40,
		"desc": "Hay que pulsar 4 colores en el orden correcto."},
	"reloj": {"name": "Reloj de pared", "size": Vector3(0.5, 0.5, 0.06), "snap": 0.25, "solid": false, "wall": true, "price": 15,
		"desc": "Marca la hora que tú elijas: sirve de pista para un código."},
	"tarjeta": {"name": "Tarjeta de acceso", "size": Vector3(0.16, 0.02, 0.1), "pick": Vector3(0.3, 0.12, 0.22), "snap": 0.05, "solid": false, "price": 20,
		"desc": "Tarjeta de color para los lectores de tarjeta de las puertas. Se recoge con E."},
	"pared": {"name": "Pared (2 m)", "size": Vector3(2.0, 3.0, 0.2), "snap": 0.25, "solid": true, "long": true, "price": 10,
		"desc": "Pared interior para dividir la sala. Se gira con R."},
	"pared_larga": {"name": "Pared (4 m)", "size": Vector3(4.0, 3.0, 0.2), "snap": 0.25, "solid": true, "long": true, "price": 18,
		"desc": "Pared interior larga. Se gira con R."},
	"puerta_interior": {"name": "Puerta con llave", "size": Vector3(1.0, 2.1, 0.12), "snap": 0.25, "solid": true, "long": true, "price": 25,
		"desc": "Para poner donde quieras (por ejemplo entre dos paredes). Se abre con una llave."},
}
const PLACEABLE := ["mesa", "silla", "librero", "caja", "alfombra", "lampara", "cofre", "llave", "nota",
	"sofa", "planta", "reloj", "cuadro", "pared", "pared_larga", "cofre_misterioso", "cuadro_secreto",
	"puerta_interior", "tarjeta", "cofre_codigo", "cuadro_cofre", "caja_fuerte", "acertijo", "interruptores",
	"panel_colores", "cuadro_pasadizo"]
const INTERACTIVE := ["llave", "nota", "lampara", "cofre", "puerta_salida",
	"cuadro", "cuadro_secreto", "caja_fuerte", "acertijo", "interruptores",
	"cofre_misterioso", "cofre_codigo", "tarjeta", "cuadro_pasadizo", "cuadro_cofre", "panel_colores", "puerta_interior"]
const STYLES := ["Paisaje", "Retrato", "Abstracto"]

## Categorías del catálogo del creador (en este orden).
const CATEGORIES := ["Muebles", "Decoración", "Paredes y puertas", "Llaves y objetos", "Cofres y cajas", "Puzzles"]
const CATEGORY_OF := {
	"mesa": "Muebles", "silla": "Muebles", "librero": "Muebles", "sofa": "Muebles", "alfombra": "Muebles",
	"caja": "Muebles",
	"lampara": "Decoración", "planta": "Decoración", "reloj": "Decoración", "cuadro": "Decoración",
	"pared": "Paredes y puertas", "pared_larga": "Paredes y puertas", "puerta_interior": "Paredes y puertas",
	"cuadro_pasadizo": "Paredes y puertas",
	"llave": "Llaves y objetos", "tarjeta": "Llaves y objetos", "nota": "Llaves y objetos",
	"cofre": "Cofres y cajas", "cofre_misterioso": "Cofres y cajas", "cofre_codigo": "Cofres y cajas",
	"cuadro_cofre": "Cofres y cajas", "caja_fuerte": "Cofres y cajas",
	"cuadro_secreto": "Puzzles", "acertijo": "Puzzles", "interruptores": "Puzzles", "panel_colores": "Puzzles",
}


static func category(type: String) -> String:
	return str(CATEGORY_OF.get(type, "Muebles"))


static func default_props(type: String) -> Dictionary:
	match type:
		"llave":
			return {"color": "Dorada"}
		"tarjeta":
			return {"color": "Azul"}
		"cofre", "cofre_misterioso":
			return {"needs": "", "gives": ""}
		"puerta_salida":
			return {"lock": "Llave", "needs": "Dorada", "code": "1234"}
		"nota":
			return {"text": "Escribe aquí tu pista..."}
		"cuadro":
			return {"style": "Paisaje", "text": ""}
		"cuadro_secreto":
			return {"style": "Paisaje", "gives": "Dorada"}
		"caja_fuerte":
			return {"code": "1234", "gives": "Dorada"}
		"acertijo":
			return {"question": "¿Qué tiene teclas pero no abre puertas?", "answer": "piano", "gives": "Dorada"}
		"interruptores":
			return {"pattern": "101", "gives": "Dorada"}
		"cofre_codigo":
			return {"code": "1234", "gives": "Dorada"}
		"cuadro_pasadizo":
			return {"needs": "", "mode": "Salida"}
		"cuadro_cofre":
			return {"style": "Paisaje", "needs": "Dorada", "gives": ""}
		"panel_colores":
			return {"sequence": "RAVD", "gives": "Dorada"}
		"reloj":
			return {"time": "1030"}
		"puerta_interior":
			return {"lock": "Llave", "needs": "Dorada", "code": "1234"}
	return {}


## ¿Se acomoda según su tamaño real (paredes y puertas interiores)?
static func is_long(type: String) -> bool:
	return bool(TYPES.get(type, {}).get("long", false))


## Nombre completo de un objeto del inventario. Los datos antiguos guardaban solo el color: "Roja" -> "Llave Roja".
static func item_name(s: String) -> String:
	if s == "":
		return ""
	if s.begins_with("Llave ") or s.begins_with("Tarjeta ") or s.begins_with("Código "):
		return s
	return "Llave " + s


## Color asociado a un objeto del inventario (gris si no tiene).
static func item_color(item: String) -> Color:
	for c in KEY_COLORS:
		if item.ends_with(str(c)):
			return COLOR_VALUES[c]
	return GREY


## Cerradura de una puerta: lock = Llave | Tarjeta | Código | Ninguna.
## `req` es el objeto que hay que tener (solo con llave o tarjeta) y `code` el código (solo con código).
static func door_lock(props: Dictionary) -> Dictionary:
	var lock := str(props.get("lock", "Llave"))
	var color := str(props.get("needs", ""))
	var req := ""
	if color != "":
		if lock == "Llave":
			req = "Llave " + color
		elif lock == "Tarjeta":
			req = "Tarjeta " + color
	return {"lock": lock, "req": req, "code": str(props.get("code", "1234"))}


## Monedas que cuesta en la tienda (0 = gratis).
static func price(type: String) -> int:
	return int(TYPES.get(type, {}).get("price", 0))


## ¿Es un bloque de pared que se puede colocar (y donde se pueden colgar objetos)?
static func is_wall_block(type: String) -> bool:
	return type == "pared" or type == "pared_larga"


## ¿Se cuelga de la pared?
static func is_wall(type: String) -> bool:
	return bool(TYPES.get(type, {}).get("wall", false))


## Crea un objeto. En modo creador (play = false) solo tiene colisión para poder seleccionarlo.
## En modo juego (play = true) los objetos interactivos reciben su lógica.
static func make_object(type: String, props: Dictionary, rot_deg: float, play: bool) -> Node3D:
	if not TYPES.has(type):
		return Node3D.new()
	var info: Dictionary = TYPES[type]
	var root := Node3D.new()
	root.name = type
	root.rotation.y = deg_to_rad(rot_deg)

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	_build_visual(visual, type, props, play)

	var interactive: bool = INTERACTIVE.has(type)
	var solid: bool = info["solid"]
	if play and not solid and not interactive:
		return root # decoración sin colisión (alfombra)

	var body: StaticBody3D
	if play and interactive:
		body = Interactable.new()
	else:
		body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1 if solid else 2
	var csize: Vector3 = info.get("pick", info["size"])
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = csize
	cs.shape = bs
	var cy: float = csize.y / 2.0
	if bool(info.get("wall", false)):
		cy = 0.0 # los objetos de pared tienen el origen en su centro
	cs.position = Vector3(0, cy, 0)
	body.add_child(cs)
	root.add_child(body)
	if is_wall_block(type) and visual.get_child_count() > 0:
		_register_cuttable(root, visual.get_child(0), cs, info["size"], false)

	if play and interactive:
		_attach_logic(root, body, type, props)
	return root


static func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rough := 0.8, glow := false, tex := "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	Textures.apply(mat, tex)
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
	bm.material = mat
	m.mesh = bm
	m.position = pos
	parent.add_child(m)
	return m


static func _build_visual(v: Node3D, type: String, props: Dictionary, play: bool) -> void:
	var wood := Color(0.42, 0.28, 0.17)
	var dark := Color(0.28, 0.18, 0.11)
	match type:
		"mesa":
			_part(v, Vector3(1.4, 0.08, 0.8), Vector3(0, 0.76, 0), wood, 0.5, false, "madera")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_part(v, Vector3(0.08, 0.72, 0.08), Vector3(0.62 * sx, 0.36, 0.32 * sz), dark, 0.5, false, "madera")
		"silla":
			_part(v, Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0), wood, 0.6, false, "madera")
			_part(v, Vector3(0.45, 0.5, 0.05), Vector3(0, 0.7, -0.2), wood, 0.6, false, "madera")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_part(v, Vector3(0.05, 0.42, 0.05), Vector3(0.19 * sx, 0.21, 0.19 * sz), dark, 0.6, false, "madera")
		"librero":
			_part(v, Vector3(1.6, 2.0, 0.03), Vector3(0, 1.0, -0.16), dark, 0.6, false, "madera")
			_part(v, Vector3(0.05, 2.0, 0.35), Vector3(-0.775, 1.0, 0), dark, 0.6, false, "madera")
			_part(v, Vector3(0.05, 2.0, 0.35), Vector3(0.775, 1.0, 0), dark, 0.6, false, "madera")
			var levels := [0.1, 0.6, 1.1, 1.6, 1.98]
			for lv in levels:
				_part(v, Vector3(1.6, 0.04, 0.35), Vector3(0, lv, 0), dark, 0.6, false, "madera")
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var palette := [
				Color(0.55, 0.15, 0.15), Color(0.15, 0.3, 0.5), Color(0.2, 0.45, 0.25),
				Color(0.7, 0.55, 0.2), Color(0.35, 0.2, 0.4), Color(0.8, 0.75, 0.65),
			]
			for i in range(4):
				var bx := -0.7
				while bx < 0.7:
					var bw := rng.randf_range(0.04, 0.08)
					var bh := rng.randf_range(0.22, 0.36)
					if rng.randf() < 0.85:
						_part(v, Vector3(bw, bh, 0.22),
							Vector3(bx + bw / 2.0, levels[i] + 0.02 + bh / 2.0, 0),
							palette[rng.randi() % palette.size()], 0.8)
					bx += bw + 0.005
		"caja":
			_part(v, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), Color(0.55, 0.4, 0.25), 0.8, false, "madera")
			_part(v, Vector3(0.62, 0.08, 0.62), Vector3(0, 0.3, 0), dark, 0.8, false, "madera")
		"alfombra":
			_part(v, Vector3(2.0, 0.02, 1.4), Vector3(0, 0.01, 0), Color(0.45, 0.12, 0.14), 1.0, false, "alfombra")
		"lampara":
			_part(v, Vector3(0.2, 0.04, 0.2), Vector3(0, 0.02, 0), dark, 0.5, false, "madera")
			_part(v, Vector3(0.04, 0.25, 0.04), Vector3(0, 0.165, 0), dark, 0.5, false, "madera")
			_part(v, Vector3(0.22, 0.18, 0.22), Vector3(0, 0.34, 0), Color(1.0, 0.85, 0.55), 0.4, true)
			if play:
				var light := OmniLight3D.new()
				light.name = "Light"
				light.position = Vector3(0, 0.3, 0)
				light.light_color = Color(1.0, 0.82, 0.55)
				light.light_energy = 1.2
				light.omni_range = 3.5
				v.add_child(light)
		"cofre", "cofre_misterioso":
			var chest_latch: Color = item_color(str(props.get("needs", "")))
			if type == "cofre_misterioso":
				chest_latch = GREY # no se ve qué llave necesita
			_part(v, Vector3(0.8, 0.45, 0.5), Vector3(0, 0.225, 0), wood, 0.55, false, "madera")
			# La tapa gira alrededor de una bisagra en el borde trasero.
			var hinge := Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(0, 0.45, -0.25)
			v.add_child(hinge)
			_part(hinge, Vector3(0.82, 0.06, 0.52), Vector3(0, 0.03, 0.26), dark, 0.5, false, "madera")
			_part(v, Vector3(0.1, 0.12, 0.03), Vector3(0, 0.38, 0.26), chest_latch, 0.3)
		"llave":
			var key_color: Color = COLOR_VALUES.get(str(props.get("color", "Dorada")), GREY)
			_part(v, Vector3(0.07, 0.03, 0.07), Vector3(-0.105, 0.015, 0), key_color, 0.3)
			_part(v, Vector3(0.18, 0.02, 0.025), Vector3(0.0, 0.015, 0), key_color, 0.3)
			_part(v, Vector3(0.03, 0.02, 0.04), Vector3(0.08, 0.015, 0.03), key_color, 0.3)
		"nota":
			_part(v, Vector3(0.3, 0.01, 0.2), Vector3(0, 0.005, 0), Color(0.96, 0.94, 0.86), 0.95)
		"sofa":
			var fabric := Color(0.45, 0.2, 0.25)
			_part(v, Vector3(1.8, 0.4, 0.85), Vector3(0, 0.2, 0), fabric, 0.9, false, "tela")
			_part(v, Vector3(1.8, 0.45, 0.2), Vector3(0, 0.62, -0.325), fabric, 0.9, false, "tela")
			for sx in [-1, 1]:
				_part(v, Vector3(0.2, 0.3, 0.85), Vector3(0.8 * sx, 0.55, 0), fabric.darkened(0.15), 0.9, false, "tela")
		"planta":
			_part(v, Vector3(0.36, 0.3, 0.36), Vector3(0, 0.15, 0), Color(0.7, 0.38, 0.25), 0.8)
			_part(v, Vector3(0.3, 0.04, 0.3), Vector3(0, 0.3, 0), Color(0.25, 0.17, 0.1), 1.0)
			_part(v, Vector3(0.06, 0.5, 0.06), Vector3(0, 0.55, 0), Color(0.25, 0.5, 0.2), 0.8)
			var leaf_a := _part(v, Vector3(0.5, 0.05, 0.2), Vector3(0, 0.85, 0), Color(0.2, 0.6, 0.25), 0.8)
			leaf_a.rotation_degrees = Vector3(0, 30, 12)
			var leaf_b := _part(v, Vector3(0.45, 0.05, 0.18), Vector3(0, 0.72, 0), Color(0.25, 0.65, 0.3), 0.8)
			leaf_b.rotation_degrees = Vector3(0, -50, -14)
		"cuadro":
			_part(v, Vector3(1.0, 0.8, 0.05), Vector3.ZERO, dark, 0.5, false, "madera")
			_painting_art(v, str(props.get("style", "Paisaje")))
		"cuadro_secreto":
			# Detrás del cuadro hay un fondo oscuro y, si corresponde, una llave pegada a la pared.
			var reveal := Node3D.new()
			reveal.name = "Reveal"
			v.add_child(reveal)
			_part(reveal, Vector3(0.9, 0.7, 0.02), Vector3(0, 0, -0.015), Color(0.1, 0.08, 0.07), 0.9)
			var secret_gives := str(props.get("gives", ""))
			if secret_gives != "":
				var key_node := Node3D.new()
				key_node.name = "Key"
				key_node.position = Vector3(0, 0, 0.0)
				key_node.rotation_degrees = Vector3(90, 0, 0)
				reveal.add_child(key_node)
				_item_shape(key_node, item_name(secret_gives))
			var secret_hinge := Node3D.new()
			secret_hinge.name = "Hinge"
			secret_hinge.position = Vector3(-0.5, 0, 0.05)
			v.add_child(secret_hinge)
			var painting := Node3D.new()
			painting.position = Vector3(0.5, 0, 0)
			secret_hinge.add_child(painting)
			_part(painting, Vector3(1.0, 0.8, 0.05), Vector3.ZERO, dark, 0.5, false, "madera")
			_painting_art(painting, str(props.get("style", "Paisaje")))
		"caja_fuerte":
			var steel := Color(0.35, 0.37, 0.4)
			_part(v, Vector3(0.7, 0.6, 0.5), Vector3(0, 0.3, -0.025), steel, 0.35, false, "metal")
			_part(v, Vector3(0.56, 0.46, 0.02), Vector3(0, 0.3, 0.226), Color(0.08, 0.08, 0.09), 0.9)
			var safe_hinge := Node3D.new()
			safe_hinge.name = "Hinge"
			safe_hinge.position = Vector3(-0.32, 0.3, 0.235)
			v.add_child(safe_hinge)
			_part(safe_hinge, Vector3(0.64, 0.54, 0.05), Vector3(0.32, 0, 0), Color(0.42, 0.44, 0.48), 0.3, false, "metal")
			_part(safe_hinge, Vector3(0.18, 0.24, 0.02), Vector3(0.5, 0.05, 0.035), Color(0.1, 0.1, 0.12), 0.5)
			_part(safe_hinge, Vector3(0.12, 0.04, 0.012), Vector3(0.5, 0.13, 0.045), Color(0.2, 0.9, 0.4), 0.4, true)
			_part(safe_hinge, Vector3(0.1, 0.1, 0.04), Vector3(0.14, 0, 0.04), Color(0.8, 0.7, 0.3), 0.3)
		"acertijo":
			_part(v, Vector3(0.3, 0.05, 0.22), Vector3(0, 0.025, 0), Color(0.25, 0.2, 0.5), 0.7)
			_part(v, Vector3(0.27, 0.035, 0.2), Vector3(0.01, 0.025, 0), Color(0.95, 0.92, 0.82), 0.9)
			_part(v, Vector3(0.05, 0.052, 0.22), Vector3(-0.145, 0.026, 0), Color(0.9, 0.7, 0.15), 0.4)
		"interruptores":
			_part(v, Vector3(0.6, 0.5, 0.05), Vector3.ZERO, Color(0.32, 0.33, 0.36), 0.5)
			var n_sw := str(props.get("pattern", "101")).length()
			for i in n_sw:
				var sx := (float(i) - (float(n_sw) - 1.0) / 2.0) * 0.17
				var sy := 0.07
				if i % 2 == 1:
					sy = -0.07
				_part(v, Vector3(0.08, 0.26, 0.03), Vector3(sx, 0.0, 0.035), Color(0.15, 0.15, 0.17), 0.5)
				_part(v, Vector3(0.05, 0.1, 0.04), Vector3(sx, sy, 0.055), Color(0.9, 0.3, 0.25), 0.4)
		"cofre_codigo":
			_part(v, Vector3(0.8, 0.45, 0.5), Vector3(0, 0.225, 0), wood, 0.55, false, "madera")
			var code_hinge := Node3D.new()
			code_hinge.name = "Hinge"
			code_hinge.position = Vector3(0, 0.45, -0.25)
			v.add_child(code_hinge)
			_part(code_hinge, Vector3(0.82, 0.06, 0.52), Vector3(0, 0.03, 0.26), dark, 0.5, false, "madera")
			# candado de combinación: cuerpo, argolla y pantallita
			_part(v, Vector3(0.14, 0.12, 0.05), Vector3(0, 0.35, 0.27), Color(0.55, 0.57, 0.6), 0.3)
			_part(v, Vector3(0.08, 0.06, 0.03), Vector3(0, 0.44, 0.27), Color(0.7, 0.7, 0.72), 0.3)
			_part(v, Vector3(0.08, 0.03, 0.02), Vector3(0, 0.36, 0.3), Color(0.2, 0.9, 0.4), 0.4, true)
		"cuadro_pasadizo":
			_part(v, Vector3(0.9, 2.0, 0.02), Vector3(0, 0, -0.015), Color(0.02, 0.02, 0.03), 0.9)
			var pa_hinge := Node3D.new()
			pa_hinge.name = "Hinge"
			pa_hinge.position = Vector3(-0.5, 0, 0.05)
			v.add_child(pa_hinge)
			var pa_painting := Node3D.new()
			pa_painting.position = Vector3(0.5, 0, 0)
			pa_hinge.add_child(pa_painting)
			_part(pa_painting, Vector3(1.0, 2.1, 0.05), Vector3.ZERO, dark, 0.5, false, "madera")
			_part(pa_painting, Vector3(0.86, 1.9, 0.01), Vector3(0, 0, 0.03), Color(0.25, 0.3, 0.38), 0.9)
			_part(pa_painting, Vector3(0.3, 0.34, 0.012), Vector3(0, 0.45, 0.035), Color(0.9, 0.75, 0.6), 0.9)
			_part(pa_painting, Vector3(0.6, 0.9, 0.012), Vector3(0, -0.35, 0.035), Color(0.5, 0.15, 0.2), 0.9)
		"cuadro_cofre":
			var cc_latch: Color = item_color(str(props.get("needs", "")))
			var cc_reveal := Node3D.new()
			cc_reveal.name = "Reveal"
			v.add_child(cc_reveal)
			_part(cc_reveal, Vector3(0.9, 0.7, 0.02), Vector3(0, 0, -0.015), Color(0.1, 0.08, 0.07), 0.9)
			_part(cc_reveal, Vector3(0.5, 0.22, 0.2), Vector3(0, -0.1, 0.1), wood, 0.55, false, "madera")
			_part(cc_reveal, Vector3(0.08, 0.08, 0.03), Vector3(0, -0.04, 0.205), cc_latch, 0.3)
			var cc_lid := Node3D.new()
			cc_lid.name = "Lid"
			cc_lid.position = Vector3(0, 0.01, 0.0)
			cc_reveal.add_child(cc_lid)
			_part(cc_lid, Vector3(0.52, 0.05, 0.22), Vector3(0, 0.025, 0.11), dark, 0.5, false, "madera")
			var cc_hinge := Node3D.new()
			cc_hinge.name = "Hinge"
			cc_hinge.position = Vector3(-0.5, 0, 0.27)
			v.add_child(cc_hinge)
			var cc_painting := Node3D.new()
			cc_painting.position = Vector3(0.5, 0, 0)
			cc_hinge.add_child(cc_painting)
			_part(cc_painting, Vector3(1.0, 0.8, 0.05), Vector3.ZERO, dark, 0.5, false, "madera")
			_painting_art(cc_painting, str(props.get("style", "Paisaje")))
		"panel_colores":
			_part(v, Vector3(0.6, 0.2, 0.05), Vector3.ZERO, Color(0.2, 0.2, 0.23), 0.5)
			var pc_cols := [Color(0.8, 0.15, 0.15), Color(0.2, 0.4, 0.85), Color(0.2, 0.65, 0.3), Color(0.9, 0.7, 0.15)]
			for i in 4:
				_part(v, Vector3(0.1, 0.1, 0.03), Vector3(-0.21 + 0.14 * i, 0, 0.04), pc_cols[i], 0.4, true)
		"reloj":
			_part(v, Vector3(0.5, 0.5, 0.05), Vector3.ZERO, dark, 0.5, false, "madera")
			_part(v, Vector3(0.44, 0.44, 0.012), Vector3(0, 0, 0.03), Color(0.95, 0.93, 0.85), 0.8)
			for mark in [Vector3(0, 0.19, 0), Vector3(0, -0.19, 0), Vector3(0.19, 0, 0), Vector3(-0.19, 0, 0)]:
				_part(v, Vector3(0.03, 0.03, 0.012), mark + Vector3(0, 0, 0.036), Color(0.1, 0.1, 0.12), 0.5)
			var clock_time := str(props.get("time", "1030"))
			var clock_h := int(clock_time.substr(0, 2)) % 12
			var clock_m := int(clock_time.substr(2, 2)) % 60
			_clock_hand(v, 0.12, 0.03, float(clock_h) * 30.0 + float(clock_m) * 0.5)
			_clock_hand(v, 0.18, 0.02, float(clock_m) * 6.0)
		"tarjeta":
			var card_color: Color = COLOR_VALUES.get(str(props.get("color", "Azul")), GREY)
			_part(v, Vector3(0.16, 0.01, 0.1), Vector3(0, 0.005, 0), card_color, 0.4)
			_part(v, Vector3(0.16, 0.012, 0.025), Vector3(0, 0.006, -0.025), Color(0.1, 0.1, 0.12), 0.5)
			_part(v, Vector3(0.04, 0.012, 0.03), Vector3(-0.05, 0.006, 0.02), Color(0.95, 0.85, 0.4), 0.3)
		"pared", "pared_larga":
			var wall_size: Vector3 = TYPES[type]["size"]
			_part(v, wall_size, Vector3(0, wall_size.y / 2.0, 0), Color(0.86, 0.82, 0.74), 0.9, false, "pared")
		"puerta_interior":
			_part(v, Vector3(1.0, 2.1, 0.1), Vector3(0, 1.05, 0), Color(0.62, 0.43, 0.27), 0.6, false, "madera")
			_part(v, Vector3(0.8, 1.9, 0.02), Vector3(0, 1.05, 0.055), Color(0.56, 0.38, 0.23), 0.6, false, "madera")
			_door_lock_visual(v, props, 0.075)
		"puerta_salida":
			_part(v, Vector3(1.0, 2.1, 0.1), Vector3(0, 1.05, 0), dark, 0.6, false, "madera")
			_door_lock_visual(v, props, 0.06)


# ---------------------------------------------------------------- lógica de juego

static func _attach_logic(root: Node3D, body: StaticBody3D, type: String, props: Dictionary) -> void:
	match type:
		"llave":
			_logic_key(root, body, props)
		"tarjeta":
			var card_props: Dictionary = props.duplicate()
			card_props["prefix"] = "Tarjeta"
			_logic_key(root, body, card_props)
		"nota":
			_logic_note(body, props)
		"lampara":
			_logic_lamp(root, body)
		"cofre":
			_logic_chest(root, body, props)
		"cofre_misterioso":
			var hidden_props: Dictionary = props.duplicate()
			hidden_props["hide"] = true
			_logic_chest(root, body, hidden_props)
		"cofre_codigo":
			_logic_code_chest(root, body, props)
		"cuadro_pasadizo":
			_logic_passage(root, body, props)
		"cuadro_cofre":
			_logic_painting_chest(root, body, props)
		"panel_colores":
			_logic_colors(body, props)
		"puerta_interior":
			_logic_inner_door(root, body, props)
		"puerta_salida":
			_logic_door(root, body, props)
		"cuadro":
			_logic_painting(body, props)
		"cuadro_secreto":
			_logic_secret_painting(root, body, props)
		"caja_fuerte":
			_logic_safe(root, body, props)
		"acertijo":
			_logic_riddle(body, props)
		"interruptores":
			_logic_switches(body, props)


## Manecilla del reloj: apunta a las 12 y gira en sentido horario `angle_deg` grados.
static func _clock_hand(parent: Node3D, length: float, width: float, angle_deg: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, 0.042)
	pivot.rotation_degrees = Vector3(0, 0, -angle_deg)
	parent.add_child(pivot)
	_part(pivot, Vector3(width, length, 0.01), Vector3(0, length / 2.0, 0), Color(0.1, 0.1, 0.12), 0.5)


static func _logic_code_chest(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var code := str(props.get("code", "1234"))
	var gives := str(props.get("gives", ""))
	var state := {"open": false}
	var hinge: Node3D = root.get_node("Visual/Hinge")
	body.set("prompt_text", "Abrir cofre con candado")
	var on_solved = func(by):
		state["open"] = true
		body.set("prompt_text", "Cofre abierto")
		hinge.create_tween().tween_property(hinge, "rotation:x", deg_to_rad(-110.0), 0.8)
		if gives == "":
			by.show_message("¡El candado se abrió! El cofre está vacío.")
		else:
			by.give_key(gives, "¡El candado se abrió! Dentro había: ")
	var on_use = func(by):
		if state["open"]:
			by.show_message("El cofre ya está abierto.")
			return
		by.open_puzzle("code", "Candado de combinación", "Introduce el código de %d dígitos." % code.length(), code, on_solved)
	body.connect("interacted", on_use)


## Cuadro grande que se abre dejando un hueco en la pared. Modo "Salida": además da el mensaje y
## termina la sala. Modo "Abertura": solo abre el hueco (sin mensaje ni salida).
static func _logic_passage(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var needs := str(props.get("needs", ""))
	var req := item_name(needs)
	var is_exit := str(props.get("mode", "Salida")) != "Abertura"
	var is_last := bool(props.get("is_last", true))
	var state := {"open": false}
	var hinge: Node3D = root.get_node("Visual/Hinge")
	var carve_fn: Callable = carve_walls   # (los estáticos se llaman desde la lambda mediante Callable)
	var alcove_fn: Callable = _build_alcove
	body.set("prompt_text", "Mirar cuadro")
	var on_use = func(by):
		if state["open"]:
			return
		if needs != "" and not by.has_item(req):
			by.show_message("El cuadro no se mueve. Algo en él necesita una llave.")
			return
		state["open"] = true
		body.set("prompt_text", "Pasadizo abierto")
		hinge.create_tween().tween_property(hinge, "rotation:y", deg_to_rad(-100.0), 0.8)
		var cut: Dictionary = carve_fn.call(root.get_tree(), root.global_transform, 1.0, 2.1)
		if bool(cut["carved"]) and bool(cut["shell"]):
			alcove_fn.call(root.get_parent(), root.global_transform, 1.0, 2.1)
		if not is_exit:
			return
		if is_last:
			by.show_message("¡Un pasadizo secreto! Lograste escapar. Pulsa M para volver al menú.", 6.0)
		else:
			by.show_message("¡Un pasadizo secreto! Pasando a la siguiente sala...", 3.0)
		body.emit_signal("unlocked", by)
	body.connect("interacted", on_use)


# ---------------------------------------------------------------- huecos en paredes

## Marca una pared como "recortable" (se le puede abrir un hueco).
static func _register_cuttable(owner: Node, mesh: Node, col: CollisionShape3D, size: Vector3, shell: bool) -> void:
	owner.add_to_group("cuttable")
	owner.set_meta("cut", {"mesh": mesh, "col": col, "size": size, "shell": shell})


## Abre un hueco de w × h (desde el suelo) en las paredes que están detrás de `xf` (la posición del objeto
## de pared). Sirve para paredes de la sala y para las paredes de 2 m / 4 m. Devuelve si cortó algo
## y si alguna era pared de la propia sala.
static func carve_walls(tree: SceneTree, xf: Transform3D, w: float, h: float) -> Dictionary:
	var result := {"carved": false, "shell": false}
	for n in tree.get_nodes_in_group("cuttable"):
		var info: Dictionary = n.get_meta("cut")
		var mesh = info["mesh"]
		var col = info["col"]
		if not is_instance_valid(mesh) or not mesh.is_inside_tree():
			continue
		var size: Vector3 = info["size"]
		var wxf: Transform3D = mesh.global_transform
		var local: Vector3 = wxf.affine_inverse() * xf.origin
		var across: Vector3 = wxf.basis.transposed() * xf.basis.x
		var long_is_x := size.x >= size.z
		var lc: float = local.x if long_is_x else local.z
		var tc: float = local.z if long_is_x else local.x
		var long_len: float = size.x if long_is_x else size.z
		var thick: float = size.z if long_is_x else size.x
		var along: float = absf(across.x) if long_is_x else absf(across.z)
		if along < 0.9 or absf(tc) > thick / 2.0 + 0.3:
			continue
		if local.y < -size.y / 2.0 or local.y > size.y / 2.0:
			continue
		var lo := maxf(lc - w / 2.0, -long_len / 2.0)
		var hi := minf(lc + w / 2.0, long_len / 2.0)
		if hi - lo < 0.02:
			continue
		var y_bot := -size.y / 2.0
		var y_top := size.y / 2.0
		var parts: Array = []  # [desde, hasta, y0, y1] a lo largo de la pared
		if lo > -long_len / 2.0 + 0.01:
			parts.append([-long_len / 2.0, lo, y_bot, y_top])
		if hi < long_len / 2.0 - 0.01:
			parts.append([hi, long_len / 2.0, y_bot, y_top])
		if y_bot + h < y_top - 0.01:
			parts.append([lo, hi, y_bot + h, y_top])
		var material: Material = null
		if mesh is MeshInstance3D and (mesh as MeshInstance3D).mesh != null:
			material = (mesh as MeshInstance3D).mesh.surface_get_material(0)
			if material == null and (mesh as MeshInstance3D).mesh is BoxMesh:
				material = ((mesh as MeshInstance3D).mesh as BoxMesh).material
		var host: Node = n.get_parent()
		for part in parts:
			var a: float = part[0]
			var b: float = part[1]
			var y0: float = part[2]
			var y1: float = part[3]
			var psize := Vector3(b - a, y1 - y0, thick) if long_is_x else Vector3(thick, y1 - y0, b - a)
			var pcenter := Vector3((a + b) / 2.0, (y0 + y1) / 2.0, 0.0) if long_is_x else Vector3(0.0, (y0 + y1) / 2.0, (a + b) / 2.0)
			var piece := StaticBody3D.new()
			var pm := MeshInstance3D.new()
			var pbm := BoxMesh.new()
			pbm.size = psize
			pbm.material = material
			pm.mesh = pbm
			piece.add_child(pm)
			var pcs := CollisionShape3D.new()
			var pbs := BoxShape3D.new()
			pbs.size = psize
			pcs.shape = pbs
			piece.add_child(pcs)
			host.add_child(piece)
			piece.global_transform = Transform3D(wxf.basis, wxf * pcenter)
			_register_cuttable(piece, pm, pcs, psize, bool(info["shell"]))
		mesh.visible = false
		col.disabled = true
		n.remove_from_group("cuttable")
		result["carved"] = true
		if bool(info["shell"]):
			result["shell"] = true
	return result


## Nicho oscuro detrás de un hueco abierto en una pared exterior de la sala, para que no dé al vacío.
static func _build_alcove(parent: Node, xf: Transform3D, w: float, h: float) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	var basis := Basis(xf.basis.x.normalized(), Vector3.UP, xf.basis.z.normalized())
	holder.global_transform = Transform3D(basis, Vector3(xf.origin.x, 0.0, xf.origin.z))
	var z0 := -0.23   # cara exterior de la pared
	var d := 0.9      # profundidad del nicho
	var dark_c := Color(0.12, 0.1, 0.09)
	var pieces := [
		[Vector3(w + 0.2, h + 0.1, 0.1), Vector3(0, h / 2.0, z0 - d - 0.05)],
		[Vector3(0.1, h + 0.1, d), Vector3(-(w / 2.0 + 0.05), h / 2.0, z0 - d / 2.0)],
		[Vector3(0.1, h + 0.1, d), Vector3(w / 2.0 + 0.05, h / 2.0, z0 - d / 2.0)],
		[Vector3(w + 0.2, 0.1, d), Vector3(0, h + 0.05, z0 - d / 2.0)],
		[Vector3(w, 0.1, d), Vector3(0, -0.05, z0 - d / 2.0)],
	]
	for pc in pieces:
		var psz: Vector3 = pc[0]
		var ppos: Vector3 = pc[1]
		var sb := StaticBody3D.new()
		sb.position = ppos
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = psz
		var mat := StandardMaterial3D.new()
		mat.albedo_color = dark_c
		mat.roughness = 0.9
		bm.material = mat
		mi.mesh = bm
		sb.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = psz
		cs.shape = bs
		sb.add_child(cs)
		holder.add_child(sb)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, h - 0.3, z0 - d / 2.0)
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.7
	lamp.omni_range = 2.5
	holder.add_child(lamp)


## Cuadro que se abre (1.ª vez) y deja ver un cofre (2.ª vez), que puede pedir una llave.
static func _logic_painting_chest(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var needs := str(props.get("needs", ""))
	var req := item_name(needs)
	var gives := str(props.get("gives", ""))
	var state := {"painting": false, "chest": false}
	var hinge: Node3D = root.get_node("Visual/Hinge")
	var lid: Node3D = root.get_node("Visual/Reveal/Lid")
	body.set("prompt_text", "Mirar cuadro")
	var on_use = func(by):
		if not state["painting"]:
			state["painting"] = true
			body.set("prompt_text", "Abrir cofre")
			hinge.create_tween().tween_property(hinge, "rotation:y", deg_to_rad(-100.0), 0.8)
			by.show_message("¡El cuadro se abre! Detrás hay un cofre.")
			return
		if state["chest"]:
			by.show_message("El cofre ya está abierto.")
			return
		if needs != "" and not by.has_item(req):
			by.show_message("El cofre está cerrado. Necesitas: " + req + ".")
			return
		state["chest"] = true
		body.set("prompt_text", "Cofre abierto")
		lid.create_tween().tween_property(lid, "rotation:x", deg_to_rad(-110.0), 0.8)
		if gives == "":
			by.show_message("El cofre está vacío.")
		else:
			by.give_key(gives, "Dentro había: ")
	body.connect("interacted", on_use)


static func _logic_colors(body: StaticBody3D, props: Dictionary) -> void:
	var sequence := str(props.get("sequence", "RAVD"))
	var gives := str(props.get("gives", ""))
	var state := {"done": false}
	body.set("prompt_text", "Usar panel de colores")
	var on_solved = func(by):
		state["done"] = true
		body.set("prompt_text", "Panel resuelto")
		if gives == "":
			by.show_message("¡Click! El panel se activó.")
		else:
			by.give_key(gives, "¡Click! Se abrió un compartimento con: ")
	var on_use = func(by):
		if state["done"]:
			by.show_message("El panel ya está activado.")
			return
		by.open_puzzle("sequence", "Panel de colores", "Pulsa los colores en el orden correcto.", sequence, on_solved)
	body.connect("interacted", on_use)


## Puerta que se pone en cualquier lugar; se abre con una llave y se desliza hacia un lado.
static func _logic_inner_door(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var lk := door_lock(props)
	var lock := str(lk["lock"])
	var req := str(lk["req"])
	var code := str(lk["code"])
	var state := {"open": false}
	var locked_msg := "La puerta está cerrada con llave. Necesitas: " + req + "."
	body.set("prompt_text", "Abrir puerta")
	if lock == "Tarjeta":
		locked_msg = "El lector de tarjetas está en rojo. Necesitas: " + req + "."
		body.set("prompt_text", "Usar lector de tarjetas")
	elif lock == "Código":
		body.set("prompt_text", "Escribir el código")
	var on_open = func(by):
		state["open"] = true
		body.set("prompt_text", "Puerta abierta")
		by.show_message("Abriste la puerta.")
		var slide_to: Vector3 = root.position + root.transform.basis.x * 1.1
		root.create_tween().tween_property(root, "position", slide_to, 1.0)
	var on_use = func(by):
		if state["open"]:
			return
		if lock == "Código":
			by.open_puzzle("code", "Puerta con código", "Introduce el código de %d dígitos." % code.length(), code, on_open)
			return
		if req != "" and not by.has_item(req):
			by.show_message(locked_msg)
			return
		on_open.call(by)
	body.connect("interacted", on_use)


## Dibujo del cuadro según su estilo (se apoya en la cara delantera del marco).
static func _painting_art(parent: Node3D, style: String) -> void:
	match style:
		"Retrato":
			_part(parent, Vector3(0.86, 0.66, 0.01), Vector3(0, 0, 0.03), Color(0.25, 0.3, 0.38), 0.9)
			_part(parent, Vector3(0.26, 0.3, 0.012), Vector3(0, 0.06, 0.035), Color(0.9, 0.75, 0.6), 0.9)
			_part(parent, Vector3(0.5, 0.26, 0.012), Vector3(0, -0.2, 0.035), Color(0.5, 0.15, 0.2), 0.9)
		"Abstracto":
			_part(parent, Vector3(0.86, 0.66, 0.01), Vector3(0, 0, 0.03), Color(0.93, 0.9, 0.82), 0.9)
			_part(parent, Vector3(0.3, 0.3, 0.012), Vector3(-0.2, 0.1, 0.035), Color(0.8, 0.2, 0.2), 0.9)
			_part(parent, Vector3(0.4, 0.14, 0.012), Vector3(0.15, -0.15, 0.035), Color(0.2, 0.4, 0.8), 0.9)
			_part(parent, Vector3(0.14, 0.4, 0.012), Vector3(0.28, 0.12, 0.035), Color(0.95, 0.75, 0.2), 0.9)
		_:
			_part(parent, Vector3(0.86, 0.66, 0.01), Vector3(0, 0, 0.03), Color(0.55, 0.78, 0.92), 0.9)
			_part(parent, Vector3(0.86, 0.26, 0.012), Vector3(0, -0.2, 0.035), Color(0.3, 0.6, 0.3), 0.9)
			_part(parent, Vector3(0.14, 0.14, 0.012), Vector3(0.25, 0.18, 0.035), Color(0.98, 0.85, 0.3), 0.9)


## Cerradura dibujada en la puerta según su estilo: llave, tarjeta, código o ninguna.
static func _door_lock_visual(v: Node3D, props: Dictionary, z: float) -> void:
	var lock := str(props.get("lock", "Llave"))
	var col: Color = COLOR_VALUES.get(str(props.get("needs", "")), GREY)
	match lock:
		"Tarjeta":
			_part(v, Vector3(0.12, 0.2, 0.03), Vector3(0.35, 1.05, z), Color(0.12, 0.12, 0.14), 0.4)
			_part(v, Vector3(0.05, 0.02, 0.012), Vector3(0.35, 1.12, z + 0.02), col, 0.4, true)
			_part(v, Vector3(0.08, 0.015, 0.012), Vector3(0.35, 1.03, z + 0.02), Color(0.3, 0.3, 0.33), 0.4)
		"Código":
			_part(v, Vector3(0.14, 0.22, 0.03), Vector3(0.35, 1.05, z), Color(0.12, 0.12, 0.14), 0.4)
			_part(v, Vector3(0.1, 0.035, 0.012), Vector3(0.35, 1.13, z + 0.02), Color(0.2, 0.9, 0.4), 0.4, true)
			for i in 6:
				var bx := 0.35 + (float(i % 3) - 1.0) * 0.04
				var by := 1.06 - float(floori(float(i) / 3.0)) * 0.05
				_part(v, Vector3(0.03, 0.03, 0.012), Vector3(bx, by, z + 0.02), Color(0.7, 0.7, 0.74), 0.4)
		"Ninguna":
			_part(v, Vector3(0.04, 0.14, 0.05), Vector3(0.38, 1.0, z), Color(0.75, 0.75, 0.78), 0.3)
		_:
			_part(v, Vector3(0.12, 0.12, 0.03), Vector3(0.3, 1.0, z), col, 0.3)


## Objeto escondido (llave, tarjeta o papel con un código) pegado a una superficie.
static func _item_shape(parent: Node3D, item: String) -> void:
	var col := item_color(item)
	if item.begins_with("Tarjeta "):
		_part(parent, Vector3(0.16, 0.012, 0.1), Vector3(0, 0.006, 0), col, 0.4)
	elif item.begins_with("Código "):
		_part(parent, Vector3(0.14, 0.01, 0.1), Vector3(0, 0.005, 0), Color(0.95, 0.93, 0.85), 0.9)
		_part(parent, Vector3(0.1, 0.012, 0.01), Vector3(0, 0.006, -0.02), Color(0.2, 0.2, 0.25), 0.9)
		_part(parent, Vector3(0.08, 0.012, 0.01), Vector3(0, 0.006, 0.01), Color(0.2, 0.2, 0.25), 0.9)
	else:
		_key_shape(parent, col)


static func _key_shape(parent: Node3D, color: Color) -> void:
	_part(parent, Vector3(0.07, 0.03, 0.07), Vector3(-0.105, 0.015, 0), color, 0.3)
	_part(parent, Vector3(0.18, 0.02, 0.025), Vector3(0.0, 0.015, 0), color, 0.3)
	_part(parent, Vector3(0.03, 0.02, 0.04), Vector3(0.08, 0.015, 0.03), color, 0.3)


static func _logic_painting(body: StaticBody3D, props: Dictionary) -> void:
	var hint := str(props.get("text", "")).strip_edges()
	body.set("prompt_text", "Mirar cuadro")
	var on_use = func(by):
		if hint == "":
			by.show_message("Un bonito cuadro.")
		else:
			by.show_message(hint, 7.0)
	body.connect("interacted", on_use)


## Se ve igual que un cuadro normal, pero al usarlo se abre y da la llave escondida.
static func _logic_secret_painting(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var gives := str(props.get("gives", ""))
	var state := {"open": false}
	var hinge: Node3D = root.get_node("Visual/Hinge")
	body.set("prompt_text", "Mirar cuadro")
	var on_use = func(by):
		if state["open"]:
			by.show_message("Ya lo abriste.")
			return
		state["open"] = true
		body.set("prompt_text", "Cuadro abierto")
		hinge.create_tween().tween_property(hinge, "rotation:y", deg_to_rad(-100.0), 0.8)
		if gives == "":
			by.show_message("¡El cuadro se abre! Detrás no hay nada.")
		else:
			var key_node := root.get_node_or_null("Visual/Reveal/Key")
			if key_node != null:
				key_node.queue_free()
			by.give_key(gives, "¡El cuadro se abre! Detrás había: ")
	body.connect("interacted", on_use)


static func _logic_safe(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var code := str(props.get("code", "1234"))
	var gives := str(props.get("gives", ""))
	var state := {"open": false}
	var hinge: Node3D = root.get_node("Visual/Hinge")
	body.set("prompt_text", "Abrir caja fuerte")
	var on_solved = func(by):
		state["open"] = true
		body.set("prompt_text", "Caja fuerte abierta")
		hinge.create_tween().tween_property(hinge, "rotation:y", deg_to_rad(-100.0), 0.8)
		if gives == "":
			by.show_message("¡Se abrió! Está vacía.")
		else:
			by.give_key(gives, "¡Se abrió! Dentro había: ")
	var on_use = func(by):
		if state["open"]:
			by.show_message("La caja fuerte ya está abierta.")
			return
		by.open_puzzle("code", "Caja fuerte", "Introduce el código de %d dígitos." % code.length(), code, on_solved)
	body.connect("interacted", on_use)


static func _logic_riddle(body: StaticBody3D, props: Dictionary) -> void:
	var question := str(props.get("question", ""))
	var answer := str(props.get("answer", ""))
	var gives := str(props.get("gives", ""))
	var state := {"done": false}
	body.set("prompt_text", "Leer acertijo")
	var on_solved = func(by):
		state["done"] = true
		body.set("prompt_text", "Acertijo resuelto")
		if gives == "":
			by.show_message("¡Correcto!")
		else:
			by.give_key(gives, "¡Correcto! Obtuviste: ")
	var on_use = func(by):
		if state["done"]:
			by.show_message("Ya resolviste este acertijo.")
			return
		by.open_puzzle("text", "Acertijo", question, answer, on_solved)
	body.connect("interacted", on_use)


static func _logic_switches(body: StaticBody3D, props: Dictionary) -> void:
	var pattern := str(props.get("pattern", "101"))
	var gives := str(props.get("gives", ""))
	var state := {"done": false}
	body.set("prompt_text", "Usar panel")
	var on_solved = func(by):
		state["done"] = true
		body.set("prompt_text", "Panel resuelto")
		if gives == "":
			by.show_message("¡Click! El panel se activó.")
		else:
			by.give_key(gives, "¡Click! Se abrió un compartimento con: ")
	var on_use = func(by):
		if state["done"]:
			by.show_message("El panel ya está activado.")
			return
		by.open_puzzle("switches", "Panel de interruptores", "Deja los interruptores en la posición correcta.", pattern, on_solved)
	body.connect("interacted", on_use)


static func _logic_key(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var item := str(props.get("prefix", "Llave")) + " " + str(props.get("color", "Dorada"))
	body.set("prompt_text", "Recoger " + item)
	var on_use = func(by):
		if not by.has_item(item):
			by.add_item(item)
		by.show_message("Conseguiste: " + item)
		root.queue_free()
	body.connect("interacted", on_use)


static func _logic_note(body: StaticBody3D, props: Dictionary) -> void:
	var note_text := str(props.get("text", ""))
	body.set("prompt_text", "Leer nota")
	var on_use = func(by):
		if note_text.strip_edges() == "":
			by.show_message("La nota está en blanco.")
		else:
			by.show_message(note_text, 7.0)
	body.connect("interacted", on_use)


static func _logic_lamp(root: Node3D, body: StaticBody3D) -> void:
	var light: OmniLight3D = root.get_node("Visual/Light")
	body.set("prompt_text", "Encender / apagar lámpara")
	var on_use = func(_by):
		light.visible = not light.visible
	body.connect("interacted", on_use)


static func _logic_chest(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var hide_color := bool(props.get("hide", false))
	var needs := str(props.get("needs", ""))
	var req := item_name(needs)
	var gives := str(props.get("gives", ""))
	var state := {"open": false}
	var hinge: Node3D = root.get_node("Visual/Hinge")
	body.set("prompt_text", "Abrir cofre")
	var on_use = func(by):
		if state["open"]:
			by.show_message("El cofre ya está abierto.")
			return
		if needs != "" and not by.has_item(req):
			if hide_color:
				by.show_message("El cofre está cerrado con llave. Quizá otra llave lo abra.")
			else:
				by.show_message("El cofre está cerrado. Necesitas: " + req + ".")
			return
		state["open"] = true
		body.set("prompt_text", "Cofre abierto")
		hinge.create_tween().tween_property(hinge, "rotation:x", deg_to_rad(-110.0), 0.8)
		if gives != "":
			var reward := item_name(gives)
			if not by.has_item(reward):
				by.add_item(reward)
			by.show_message("Dentro había: " + reward + ".")
		else:
			by.show_message("El cofre está vacío.")
	body.connect("interacted", on_use)


static func _logic_door(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var lk := door_lock(props)
	var lock := str(lk["lock"])
	var req := str(lk["req"])
	var code := str(lk["code"])
	var is_last := bool(props.get("is_last", true))
	var state := {"open": false}
	var locked_msg := "La puerta está cerrada con llave. Necesitas: " + req + "."
	body.set("prompt_text", "Abrir puerta")
	if lock == "Tarjeta":
		locked_msg = "El lector de tarjetas está en rojo. Necesitas: " + req + "."
		body.set("prompt_text", "Usar lector de tarjetas")
	elif lock == "Código":
		body.set("prompt_text", "Escribir el código")
	var on_open = func(by):
		state["open"] = true
		body.set("prompt_text", "Puerta abierta")
		if is_last:
			by.show_message("¡Abriste la puerta! Lograste escapar. Pulsa M para volver al menú.", 6.0)
		else:
			by.show_message("¡Puerta abierta! Pasando a la siguiente sala...", 3.0)
		body.emit_signal("unlocked", by)
		# La puerta se desliza hacia dentro de la pared.
		var slide_to: Vector3 = root.position + root.transform.basis.x * 1.1
		root.create_tween().tween_property(root, "position", slide_to, 1.0)
	var on_use = func(by):
		if state["open"]:
			return
		if lock == "Código":
			by.open_puzzle("code", "Puerta con código", "Introduce el código de %d dígitos." % code.length(), code, on_open)
			return
		if req != "" and not by.has_item(req):
			by.show_message(locked_msg)
			return
		on_open.call(by)
	body.connect("interacted", on_use)