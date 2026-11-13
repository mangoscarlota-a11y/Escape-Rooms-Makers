extends RefCounted
## Monedas, compras y premios. Se guarda en user://progreso.cfg (en la web, en el navegador de cada persona).
## Los premios se reclaman una sola vez por clave (por ejemplo "guardar:Mi sala").

const PATH := "user://progreso.cfg"
const START_COINS := 50


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH) # si el archivo todavía no existe, queda vacío
	return cfg


static func coins() -> int:
	return int(_cfg().get_value("jugador", "monedas", START_COINS))


## ¿Es tuyo este objeto o forma? Lo que cuesta 0 monedas es de todos.
static func owns(kind: String, id: String, price := 0) -> bool:
	if price <= 0:
		return true
	return bool(_cfg().get_value("comprado", kind + "_" + id, false))


## Intenta comprar. Devuelve false si no alcanzan las monedas.
static func buy(kind: String, id: String, price: int) -> bool:
	var cfg := _cfg()
	var have := int(cfg.get_value("jugador", "monedas", START_COINS))
	if have < price:
		return false
	cfg.set_value("jugador", "monedas", have - price)
	cfg.set_value("comprado", kind + "_" + id, true)
	cfg.save(PATH)
	return true


## Da un premio una sola vez. Devuelve las monedas ganadas (0 si ya lo habías cobrado).
static func claim(key: String, amount: int) -> int:
	var cfg := _cfg()
	var done: Array = cfg.get_value("premios", "reclamados", [])
	if done.has(key):
		return 0
	done.append(key)
	cfg.set_value("premios", "reclamados", done)
	var have := int(cfg.get_value("jugador", "monedas", START_COINS))
	cfg.set_value("jugador", "monedas", have + amount)
	cfg.save(PATH)
	return amount
