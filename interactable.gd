extends StaticBody3D
## Cualquier objeto con este script puede ser usado por el jugador con la tecla E.

signal interacted(by)
signal unlocked(by) # lo usan las puertas que llevan a otra sala

@export var prompt_text: String = "Interactuar"


func interact(by: Node) -> void:
	interacted.emit(by)
