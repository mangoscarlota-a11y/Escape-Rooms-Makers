extends RefCounted
## Formas de sala. Cada forma es un conjunto de rectángulos sobre una rejilla de 1 m.
## Las paredes, las esquinas y el hueco de la puerta se generan solos alrededor del contorno.

const RoomBuilder = preload("res://room_builder.gd")

const WALL_H := 3.0
const WALL_COLOR := Color(0.86, 0.82, 0.74)

# rects: [x0, z0, x1, z1] en metros enteros.
# door_cell: celda pegada a la pared donde va la puerta; door_dir: hacia dónde da esa pared (hacia afuera).
# spawn / yaw: dónde aparece el jugador y hacia dónde mira (0 = hacia -Z, 90 = hacia -X, -90 = hacia +X).
const SHAPES := {
	"cuadrada": {
		"name": "Cuadrada (8×8)", "desc": "La sala clásica.", "price": 0,
		"rects": [[-4, -4, 4, 4]],
		"door_cell": Vector2i(0, -4), "door_dir": Vector2i(0, -1),
		"spawn": Vector3(0, 0.1, 3.0), "yaw": 0.0,
	},
	"rectangular": {
		"name": "Rectangular (12×6)", "desc": "Larga y ancha: cabe mucho mobiliario.", "price": 40,
		"rects": [[-6, -3, 6, 3]],
		"door_cell": Vector2i(5, 0), "door_dir": Vector2i(1, 0),
		"spawn": Vector3(-5, 0.1, 0.5), "yaw": -90.0,
	},
	"pasillo": {
		"name": "Pasillo (16×4)", "desc": "Un recorrido largo y estrecho.", "price": 50,
		"rects": [[-8, -2, 8, 2]],
		"door_cell": Vector2i(7, 0), "door_dir": Vector2i(1, 0),
		"spawn": Vector3(-7, 0.1, 0.5), "yaw": -90.0,
	},
	"l": {
		"name": "En forma de L", "desc": "Hay que doblar la esquina para llegar a la puerta.", "price": 60,
		"rects": [[-4, -4, 0, 4], [0, 0, 4, 4]],
		"door_cell": Vector2i(-2, -4), "door_dir": Vector2i(0, -1),
		"spawn": Vector3(3, 0.1, 2), "yaw": 90.0,
	},
	"cruz": {
		"name": "En cruz", "desc": "Una sala central con cuatro brazos.", "price": 80,
		"rects": [[-2, -2, 2, 2], [-1, -5, 1, -2], [-1, 2, 1, 5], [-5, -1, -2, 1], [2, -1, 5, 1]],
		"door_cell": Vector2i(0, -5), "door_dir": Vector2i(0, -1),
		"spawn": Vector3(0, 0.1, 4.0), "yaw": 0.0,
	},
}


static func get_shape(id: String) -> Dictionary:
	return SHAPES.get(id, SHAPES["cuadrada"])


static func shape_ids() -> Array:
	return SHAPES.keys()


static func price(id: String) -> int:
	return int(get_shape(id).get("price", 0))


static func _cells(id: String) -> Dictionary:
	var cells := {}
	for r in get_shape(id)["rects"]:
		for x in range(int(r[0]), int(r[2])):
			for z in range(int(r[1]), int(r[3])):
				cells[Vector2i(x, z)] = true
	return cells


## ¿Está el punto dentro de la sala (suelo)?
static func in_union(id: String, x: float, z: float) -> bool:
	for r in get_shape(id)["rects"]:
		if x >= float(r[0]) - 0.001 and x <= float(r[2]) + 0.001 \
				and z >= float(r[1]) - 0.001 and z <= float(r[3]) + 0.001:
			return true
	return false


## ¿Cabe algo de radio m centrado en (x, z)?
static func fits(id: String, x: float, z: float, m: float) -> bool:
	return in_union(id, x - m, z - m) and in_union(id, x + m, z - m) \
		and in_union(id, x - m, z + m) and in_union(id, x + m, z + m)


## ¿Cabe una caja de medio ancho hx y medio largo hz centrada en (x, z)?
static func fits_box(id: String, x: float, z: float, hx: float, hz: float) -> bool:
	return in_union(id, x - hx, z - hz) and in_union(id, x + hx, z - hz) \
		and in_union(id, x - hx, z + hz) and in_union(id, x + hx, z + hz)


static func door_pos(id: String) -> Vector3:
	var s := get_shape(id)
	var c: Vector2i = s["door_cell"]
	var d: Vector2i = s["door_dir"]
	return Vector3(c.x + 0.5 + d.x * 0.6, 0.0, c.y + 0.5 + d.y * 0.6)


## Giro (en grados) de la puerta: su cara mira hacia dentro de la sala.
static func door_rot(id: String) -> int:
	var d: Vector2i = get_shape(id)["door_dir"]
	var deg := int(round(rad_to_deg(atan2(float(-d.x), float(-d.y)))))
	return (deg + 360) % 360


static func spawn_pos(id: String) -> Vector3:
	return get_shape(id)["spawn"]


static func spawn_yaw(id: String) -> float:
	return float(get_shape(id)["yaw"])


## Dónde empieza la cámara del editor para ver toda la sala.
static func cam_start(id: String) -> Vector3:
	var minx := 1000.0
	var maxx := -1000.0
	var minz := 1000.0
	var maxz := -1000.0
	for r in get_shape(id)["rects"]:
		minx = minf(minx, float(r[0]))
		maxx = maxf(maxx, float(r[2]))
		minz = minf(minz, float(r[1]))
		maxz = maxf(maxz, float(r[3]))
	var ext := maxf(maxx - minx, maxz - minz)
	var h := ext * 0.8 + 2.0
	return Vector3((minx + maxx) / 2.0, h, (minz + maxz) / 2.0 + h)


static func build(id: String, play: bool) -> Node3D:
	var s := get_shape(id)
	var root := Node3D.new()
	root.name = "Sala"
	var cells := _cells(id)
	var dc: Vector2i = s["door_cell"]
	var dd: Vector2i = s["door_dir"]
	var rects: Array = s["rects"]

	# Suelo (y techo al jugar): un bloque por rectángulo, un poco más grande para que no queden rendijas.
	for r in rects:
		var x0 := float(r[0])
		var z0 := float(r[1])
		var x1 := float(r[2])
		var z1 := float(r[3])
		var w := x1 - x0 + 0.2
		var d := z1 - z0 + 0.2
		var cx := (x0 + x1) / 2.0
		var cz := (z0 + z1) / 2.0
		RoomBuilder.box(root, Vector3(w, 0.2, d), Vector3(cx, -0.1, cz), Color(0.62, 0.42, 0.26), 0.6, true, false, "parquet")
		if play:
			RoomBuilder.box(root, Vector3(w, 0.2, d), Vector3(cx, WALL_H + 0.1, cz), Color(0.93, 0.91, 0.87), 0.9, true, false, "pared")

	# Paredes: una pieza de 1 m por cada lado de celda que da al exterior.
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for cell in cells:
		var cv: Vector2i = cell
		for dir in dirs:
			var dv: Vector2i = dir
			if cells.has(cv + dv):
				continue
			var wx := cv.x + 0.5 + dv.x * 0.6
			var wz := cv.y + 0.5 + dv.y * 0.6
			var size := Vector3(1.0, WALL_H, 0.2)
			if dv.x != 0:
				size = Vector3(0.2, WALL_H, 1.0)
			if cv == dc and dv == dd:
				# Hueco de la puerta: solo queda la parte de arriba.
				RoomBuilder.box(root, Vector3(size.x, 0.9, size.z), Vector3(wx, 2.55, wz), WALL_COLOR, 0.9, true, false, "pared")
			else:
				var wb := RoomBuilder.box(root, size, Vector3(wx, WALL_H / 2.0, wz), WALL_COLOR, 0.9, true, false, "pared")
				wb.add_to_group("cuttable") # se le puede abrir un hueco (pasadizo secreto)
				wb.set_meta("cut", {"mesh": wb.get_child(0), "col": wb.get_child(1), "size": size, "shell": true})
				# Zócalo de madera por la cara interior de la pared.
				var bs := Vector3(1.0, 0.14, 0.03)
				if dv.x != 0:
					bs = Vector3(0.03, 0.14, 1.0)
				RoomBuilder.box(root, bs, Vector3(wx - dv.x * 0.115, 0.07, wz - dv.y * 0.115),
					Color(0.55, 0.4, 0.26), 0.6, false, false, "madera")

	# Esquinas salientes: un poste en cada vértice donde solo hay una celda alrededor.
	var seen := {}
	for cell in cells:
		var cv: Vector2i = cell
		for ox in [0, 1]:
			for oz in [0, 1]:
				var p := Vector2i(cv.x + ox, cv.y + oz)
				if seen.has(p):
					continue
				seen[p] = true
				var around := [
					Vector2i(p.x - 1, p.y - 1), Vector2i(p.x, p.y - 1),
					Vector2i(p.x - 1, p.y), Vector2i(p.x, p.y),
				]
				var count := 0
				var idx := -1
				for i in 4:
					if cells.has(around[i]):
						count += 1
						idx = i
				if count != 1:
					continue
				var qx := 1
				if idx % 2 == 0:
					qx = -1
				var qz := 1
				if idx < 2:
					qz = -1
				RoomBuilder.box(root, Vector3(0.2, WALL_H, 0.2),
					Vector3(p.x - qx * 0.1, WALL_H / 2.0, p.y - qz * 0.1), WALL_COLOR, 0.9, true, false, "pared")

	var spawn := spawn_pos(id)
	if play:
		# Luces del techo: una cada ~6 m a lo largo de cada rectángulo.
		var first := true
		for r in rects:
			var x0 := float(r[0])
			var z0 := float(r[1])
			var x1 := float(r[2])
			var z1 := float(r[3])
			var long_x := (x1 - x0) >= (z1 - z0)
			var length := z1 - z0
			if long_x:
				length = x1 - x0
			var n := maxi(1, int(ceil(length / 6.0)))
			for k in n:
				var t := (float(k) + 0.5) / float(n)
				var light := OmniLight3D.new()
				if long_x:
					light.position = Vector3(x0 + (x1 - x0) * t, 2.7, (z0 + z1) / 2.0)
				else:
					light.position = Vector3((x0 + x1) / 2.0, 2.7, z0 + (z1 - z0) * t)
				light.light_color = Color(1.0, 0.95, 0.85)
				light.light_energy = 1.2
				light.omni_range = 9.0
				light.shadow_enabled = first
				first = false
				root.add_child(light)
	else:
		# Marca verde donde empieza el jugador.
		var marker := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(0.9, 0.02, 0.9)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.7, 0.35)
		mm.material = mat
		marker.mesh = mm
		marker.position = Vector3(spawn.x, 0.011, spawn.z)
		root.add_child(marker)
		var l3 := Label3D.new()
		l3.text = "INICIO"
		l3.font_size = 48
		l3.pixel_size = 0.005
		l3.rotation_degrees = Vector3(-90, 0, 0)
		l3.position = Vector3(spawn.x, 0.03, spawn.z)
		root.add_child(l3)

	return root
