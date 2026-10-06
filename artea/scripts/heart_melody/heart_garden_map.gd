extends Control

var world: Node3D
var expanded := false
const BOUNDS := Rect2(-275,-145,640,290)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if world != null and world.active: queue_redraw()

func _point(at: Vector3) -> Vector2:
	return Vector2(12+(at.x-BOUNDS.position.x)/BOUNDS.size.x*(size.x-24),
		30+(at.z-BOUNDS.position.y)/BOUNDS.size.y*(size.y-44))

func _draw() -> void:
	if world == null: return
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	draw_string(ThemeDB.fallback_font,Vector2(12,20),"FEELING GARDEN",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2e7c9"))
	var scale_value := (size.x-24)/BOUNDS.size.x
	for lobe in [[Vector3(-130,0,0),Vector2(145,125)],[Vector3(150,2,0),Vector2(165,140)]]:
		var centre := _point(lobe[0])
		var radii: Vector2 = lobe[1] * scale_value
		draw_set_transform(centre,0,radii)
		draw_circle(Vector2.ZERO,1.0,Color("668c49"))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	for route in world.route_segments:
		draw_line(_point(route[0]),_point(route[1]),Color("dec79a"),2)
	for id in world.controls:
		var anchor: Marker3D = world.controls[id].anchor
		if str(id).begins_with("planter"):
			draw_circle(_point(anchor.position),3,Color("e7a4b8"))
		elif str(id).begins_with("drum"):
			draw_circle(_point(anchor.position),3,Color("82c8d5"))
		elif str(id).begins_with("encounter"):
			draw_arc(_point(anchor.position),5,0,TAU,12,Color("eac66e"),2)
	if world.player != null:
		var at := _point(world.to_local(world.player.global_position))
		draw_circle(at,4,Color.WHITE)
		draw_arc(at,6,0,TAU,12,Color("233a30"),1)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10,0.18,0.14,0.92)
	style.corner_radius_top_left = 10
	style.corner_radius_bottom_left = 10
	return style
