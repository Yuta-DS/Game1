extends Node3D

const SceneLoader := preload("res://scripts/scene_loader.gd")

# Kept so the browser's handle on the callback stays valid while the hub is up.
var _js_enter_castle: JavaScriptObject


# The web smoke test (tools/web-smoke.js) takes the player from the Hub into
# the Art Castle through this, the same route as the button and the castle
# door: SceneLoader, the loading screen, and the Art Castle Pack's download.
func _ready() -> void:
	if OS.has_feature("web"):
		_js_enter_castle = JavaScriptBridge.create_callback(func(_args): _on_button_pressed())
		JavaScriptBridge.get_interface("window").arteaEnterArtCastle = _js_enter_castle


func _on_button_pressed() -> void:
	SceneLoader.change_scene_with_loading(get_tree(), "res://scenes/art_gallery_3d_inprogress.tscn")
