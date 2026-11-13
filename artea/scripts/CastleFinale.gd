extends Node3D

## The ARTÉA Castle finale.
##
## The player brings the Star of Wisdom, the Harmony Jewel and the Creator's
## Light to the Maker. The three treasures join into the Light of Identity, the
## game offers a few identities that fit the journey, and the Maker shapes the
## Crown of Life.
##
## The story's rule governs everything here: the treasures did not make the
## player valuable, and the crown celebrates a light that was already theirs.
## So nothing in this script judges, scores, or withholds.

signal treasures_gathered()
signal light_of_identity_formed()
signal identities_offered(options: Array)
signal identity_confirmed(identity_id: String)
signal crown_forged(identity_id: String)
signal star_named(player_name: String)

const Identities := preload("res://scripts/GameIdentities.gd")

## How long the three treasures take to drift together, in seconds.
@export var gathering_time: float = 4.0

## How many identities to offer. The story says two or three.
@export_range(2, 4, 1) var identities_to_offer: int = 3

var _journey: Node = null
var _offered: Array = []
var _gathering := false
var _gather_elapsed := 0.0


func _ready() -> void:
	_journey = get_node_or_null("/root/JourneyState")
	if _journey == null:
		push_error("CastleFinale: JourneyState singleton not found.")
		return
	set_process(false)


## True when the player is carrying everything the finale needs.
func can_begin() -> bool:
	return _journey != null and _journey.has_all_treasures()


## Starts the finale. Does nothing if a treasure is still out in the world —
## the castle waits rather than turning the player away.
func begin() -> bool:
	if not can_begin() or _gathering:
		return false
	_gathering = true
	_gather_elapsed = 0.0
	set_process(true)
	treasures_gathered.emit()
	return true


func _process(delta: float) -> void:
	if not _gathering:
		return
	_gather_elapsed += delta
	if _gather_elapsed >= gathering_time:
		_gathering = false
		set_process(false)
		_form_light_of_identity()


## The Star brings wisdom, the Jewel brings feeling, the Flame brings
## creativity. Together they become the Light of Identity.
func _form_light_of_identity() -> void:
	light_of_identity_formed.emit()
	offer_identities()


## Reads how the player actually played and offers a few identities that fit.
func offer_identities() -> Array:
	if _journey == null:
		return []
	_offered = Identities.suggest(_journey.choice_log, identities_to_offer)
	identities_offered.emit(_offered)
	return _offered


func offered_identities() -> Array:
	return _offered


## The player picks. Any of the 16 is allowed, not only the ones offered — the
## story says they may choose a different one if it feels more like them.
func choose_identity(identity_id: String) -> bool:
	if not identity_id in Identities.all_ids():
		return false
	_journey.choose_identity(identity_id)
	identity_confirmed.emit(identity_id)
	return true


## "I am still discovering" is a real answer, and it does not block the crown.
func stay_undecided() -> void:
	_journey.choose_identity("")
	identity_confirmed.emit("")


## The Maker shapes the treasures and the player's light into the Crown of Life.
## The crown is granted whether or not an identity was chosen.
func forge_crown() -> bool:
	if not can_begin():
		return false
	_journey.complete_journey()
	crown_forged.emit(_journey.identity)
	return true


## A new star appears in the castle universe with the player's chosen name.
func name_a_star(player_name: String) -> void:
	var chosen := player_name.strip_edges()
	if chosen == "":
		chosen = "a new light"
	_journey.record_choice("castle", "star_named", chosen)
	star_named.emit(chosen)


## Celebration Mode: the story sends the train around the whole Crown Line so
## the player can see every world shining together.
func celebration_route() -> Array[String]:
	if _journey == null or not _journey.has_all_treasures():
		return []
	var route: Array[String] = [_journey.STATION_GALLERY]
	for world in _journey.CROWN_LINE:
		route.append(world["station"])
	route.append(_journey.STATION_CASTLE)
	return route


## The closing words, with the player's identity woven in when they chose one.
func closing_message() -> String:
	var base := "Your story matters. You are uniquely created. Your light has a place in this universe."
	if _journey == null or _journey.identity == "":
		return base
	var identity_name: String = Identities.display_name(_journey.identity)
	if identity_name == "":
		return base
	return "%s\n\nYou are %s." % [base, identity_name]
