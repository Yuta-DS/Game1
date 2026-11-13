extends Node
func _ready():
	for pair in [["res://scenes/milo_animations.tscn","Milo"],["res://scenes/rogue_animations.tscn","Rogue"]]:
		var n = load(pair[0]).instantiate()
		add_child(n)
		var ap = n.get_node_or_null("AnimationPlayer")
		if ap == null:
			for c in n.get_children():
				if c is AnimationPlayer: ap = c
		print(pair[1], " anims: ", ap.get_animation_list() if ap else "NO ANIMATIONPLAYER")
		n.queue_free()
	get_tree().quit(0)
