extends Control

var world: Node3D
var expanded := false
const BOUNDS := Rect2(-94,-64,226,128)

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
	for lobe in [[Vector3(-36,0,0),52.0],[Vector3(42,0,0),60.0]]:
		draw_circle(_point(lobe[0]),float(lobe[1])*scale_value,Color("668c49"))
	for route in world.route_segments:
		draw_line(_point(route[0]),_point(route[1]),Color("dec79a"),2)
	for id in world.controls:
		var anchor: Marker3D = world.controls[id].anchor
		if str(id).begins_with("planter"):
			draw_circle(_point(anchor.position),3,Color("e7a4b8"))
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
