extends RefCounted
## Texturas del juego, sin derechos de autor.
## 1) Si existe res://assets/textures/<nombre>.png|jpg|webp, se usa esa (por ejemplo un pack CC0
##    de Poly Haven, ambientCG o Kenney). Opcional: <nombre>_normal.png como mapa de normales.
## 2) Si no, se genera una textura por código (tileable, ~0.3 s la primera vez, luego en caché).

const DIR := "res://assets/textures/"
const EXTS := ["png", "jpg", "jpeg", "webp"]

# tile: metros que cubre una repetición de la textura. world: coordenadas de mundo (paredes/suelo continuos).
const INFO := {
	"madera": {"tile": 0.5, "size": 256, "world": false},
	"parquet": {"tile": 2.0, "size": 256, "world": true},
	"pared": {"tile": 2.0, "size": 256, "world": true},
	"tela": {"tile": 0.4, "size": 128, "world": false},
	"alfombra": {"tile": 0.5, "size": 128, "world": false},
	"metal": {"tile": 0.5, "size": 128, "world": false},
}

static var _cache := {}


## Aplica la textura `tex` al material (el color del material la tiñe). Si `tex` no existe, no hace nada.
static func apply(mat: StandardMaterial3D, tex: String) -> void:
	if tex == "" or not INFO.has(tex):
		return
	var info: Dictionary = INFO[tex]
	var t := _load_tex(tex)
	if t == null:
		return
	mat.albedo_texture = t
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = bool(info["world"])
	var k := 1.0 / float(info["tile"])
	mat.uv1_scale = Vector3(k, k, k)
	var nm := _find_external(tex + "_normal")
	if nm != null:
		mat.normal_enabled = true
		mat.normal_texture = nm


static func _load_tex(tex: String) -> Texture2D:
	if _cache.has(tex):
		return _cache[tex]
	var t: Texture2D = _find_external(tex)
	if t == null:
		t = _generate(tex)
	_cache[tex] = t
	return t


static func _find_external(base: String) -> Texture2D:
	for e in EXTS:
		var p: String = DIR + base + "." + e
		if ResourceLoader.exists(p):
			var r = load(p)
			if r is Texture2D:
				return r
	return null


# ------------------------------------------------------------------ generación

static func _noise(seed_v: int, freq: float, size: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_v
	n.frequency = freq
	return n.get_seamless_image(size, size)


static func _hash(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 1000) / 1000.0


static func _generate(tex: String) -> Texture2D:
	var size: int = int(INFO[tex]["size"])
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var low := _noise(11, 0.01, size)
	var high := _noise(23, 0.12, size)
	for y in size:
		for x in size:
			var nl := low.get_pixel(x, y).r
			var nh := high.get_pixel(x, y).r
			var v := 0.8
			match tex:
				"madera":
					var grain := 0.5 + 0.5 * sin((float(y) / size * 10.0 + nl * 3.0) * TAU)
					v = 0.66 + 0.2 * grain + 0.1 * (nh - 0.5)
					if _hash(x / 64, 0) > 0.93: # algún nudo/veta clara
						v += 0.03
				"parquet":
					var row := y / 64
					var xs := (x + (row % 2) * 64) % 256
					var board := xs / 128
					var tone := 0.72 + 0.2 * _hash(board, row)
					var grain2 := 0.5 + 0.5 * sin((float(y) / size * 40.0 + nl * 4.0) * TAU)
					v = tone + 0.06 * grain2 + 0.08 * (nh - 0.5)
					if y % 64 < 2 or xs % 128 < 2:
						v = 0.28 # junta entre tablas
				"pared":
					v = 0.93 + 0.07 * (nl - 0.5) * 2.0 + 0.04 * (nh - 0.5)
				"tela":
					var weave := sin(float(x) * TAU / 4.0) * sin(float(y) * TAU / 4.0)
					v = 0.8 + 0.1 * weave + 0.1 * (nh - 0.5)
				"alfombra":
					v = 0.72 + 0.28 * nh + 0.08 * (nl - 0.5)
					var stripe := (x / 16 + y / 16) % 2 # damero muy suave
					v += 0.04 * float(stripe)
				"metal":
					var streak := _noise_stream(nh, y)
					v = 0.82 + 0.14 * streak + 0.06 * (nl - 0.5)
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Rayado horizontal tipo metal cepillado (depende de la fila).
static func _noise_stream(nh: float, y: int) -> float:
	return (_hash(y, 7) - 0.5) * 1.0 + (nh - 0.5) * 0.3
