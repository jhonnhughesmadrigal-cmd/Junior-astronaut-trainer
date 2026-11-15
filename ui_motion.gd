extends Node
# v28 — Microinteracciones discretas para toda la interfaz (sin cambiar la logica):
#  - Botones: al pasar el raton se aclaran un poco; al pulsar, un "pulso" corto de escala.
#  - Paneles a pantalla completa (pausa, mochila, mapa, diario, opciones...): aparecen con un
#    fundido corto de opacidad. No se mueve nada de sitio ni se retrasa la entrada de teclado.
# Duraciones del sistema de diseno: T_FAST 0,12 s y T_BASE 0,2 s.

const DS = preload("res://design_system.gd")

var game: Node = null
var skip: Array = []          # nodos que tienen su propia animacion o no deben tocarse


func setup(g: Node, skip_nodes: Array) -> void:
	game = g
	skip = skip_nodes
	get_tree().node_added.connect(_on_node_added)
	_walk(game)


func _walk(n: Node) -> void:
	_attach(n)
	for c in n.get_children():
		_walk(c)


func _on_node_added(n: Node) -> void:
	_attach(n)


func _attach(n: Node) -> void:
	if n is BaseButton and not n.has_meta("ds_motion"):
		n.set_meta("ds_motion", true)
		var b: BaseButton = n
		b.mouse_entered.connect(_hover.bind(b, true))
		b.mouse_exited.connect(_hover.bind(b, false))
		b.button_down.connect(_press.bind(b))
	elif n is Control and n.get_parent() == game and not n.has_meta("ds_motion"):
		var c: Control = n
		if c in skip or c is ColorRect or c is MarginContainer:
			return
		c.set_meta("ds_motion", true)
		c.visibility_changed.connect(_on_vis.bind(c))


func _hover(b: BaseButton, on: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or b.disabled:
		return
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "self_modulate", Color(1.1, 1.1, 1.1) if on else Color.WHITE, DS.T_FAST)


func _press(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.pivot_offset = b.size / 2.0
	var tw: Tween = b.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2(0.97, 0.97), DS.T_FAST * 0.5)
	tw.tween_property(b, "scale", Vector2.ONE, DS.T_FAST)


func _on_vis(c: Control) -> void:
	if not is_instance_valid(c) or not c.visible or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, DS.T_FAST + 0.03)
