extends Node3D

## The Crown Chamber inside the ARTÉA Castle.
##
## This is the room the finale happens in. CastleFinale.gd owns the rules; this
## script owns what the player sees: three treasures drifting together, the
## Light of Identity forming, the Maker stepping forward, and a new star taking
## its place in the castle universe.
##
## The story's line governs the staging as much as the logic — the treasures
## did not make the player valuable — so the room is already warm and lit when
## the player walks in. Nothing here is withheld until they have earned it.

@export var finale_path: NodePath = NodePath("Finale")

## How far the three treasures orbit from the centre before they join.
@export var orbit_radius: float = 3.2

## How fast the treasures drift around the chamber, in radians per second.
@export var orbit_speed: float = 0.6

@onready var _finale: Node = get_node_or_null(finale_path)
@onready var _star: Node3D = get_node_or_null("Treasures/StarOfWisdom")
@onready var _jewel: Node3D = get_node_or_null("Treasures/HarmonyJewel")
@onready var _flame: Node3D = get_node_or_null("Treasures/CreatorsLight")
@onready var _identity_light: Node3D = get_node_or_null("LightOfIdentity")
@onready var _crown: Node3D = get_node_or_null("CrownOfLife")
@onready var _new_star: Node3D = get_node_or_null("CastleUniverse/NewStar")
@onready var _maker: Node3D = get_node_or_null("Maker")
@onready var _entry: Area3D = get_node_or_null("EntryArea")

var _orbit_angle: float = 0.0
var _joining: bool = false
var _join_progress: float = 0.0
var _journey: Node = null


func _ready() -> void:
	_journey = get_node_or_null("/root/JourneyState")

	# The crown and the identity light only appear once they are made.
	_show(_identity_light, false)
	_show(_crown, false)
	_show(_new_star, false)

	_place_treasures_the_player_holds()

	if _finale:
		_finale.treasures_gathered.connect(_on_treasures_gathered)
		_finale.light_of_identity_formed.connect(_on_light_formed)
		_finale.crown_forged.connect(_on_crown_forged)
		_finale.star_named.connect(_on_star_named)

	if _entry:
		_entry.body_entered.connect(_on_player_entered)


func _process(delta: float) -> void:
	_orbit_angle += delta * orbit_speed

	if _joining:
		_join_progress = minf(1.0, _join_progress + delta * 0.25)

	# The treasures circle the chamber, drawing inward once they begin to join.
	var radius: float = lerp(orbit_radius, 0.0, _join_progress)
	_orbit(_star, 0.0, radius)
	_orbit(_jewel, TAU / 3.0, radius)
	_orbit(_flame, TAU * 2.0 / 3.0, radius)

	if _identity_light and _identity_light.visible:
		_identity_light.rotation.y += delta * 0.8


func _orbit(treasure: Node3D, offset: float, radius: float) -> void:
	if treasure == null or not treasure.visible:
		return
	var angle := _orbit_angle + offset
	treasure.position = Vector3(
		cos(angle) * radius,
		1.6 + sin(angle * 1.7) * 0.18,
		sin(angle) * radius
	)


## Only the treasures the player actually found are in the room. A player who
## arrives early sees the room, and the Maker, and whatever they did bring.
func _place_treasures_the_player_holds() -> void:
	if _journey == null:
		return
	_show(_star, _journey.TREASURE_STAR in _journey.treasures)
	_show(_jewel, _journey.TREASURE_JEWEL in _journey.treasures)
	_show(_flame, _journey.TREASURE_LIGHT in _journey.treasures)


func _on_player_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _finale and _finale.can_begin():
		_finale.begin()


func _on_treasures_gathered() -> void:
	_joining = true
	_join_progress = 0.0


func _on_light_formed() -> void:
	# The three become one.
	_show(_star, false)
	_show(_jewel, false)
	_show(_flame, false)
	_show(_identity_light, true)


func _on_crown_forged(_identity_id: String) -> void:
	_show(_crown, true)


func _on_star_named(_player_name: String) -> void:
	_show(_new_star, true)


func _show(node: Node3D, visible_now: bool) -> void:
	if node:
		node.visible = visible_now


## Lets a UI ask what the finale is currently offering.
func offered_identities() -> Array:
	return _finale.offered_identities() if _finale else []


func closing_message() -> String:
	return _finale.closing_message() if _finale else ""
