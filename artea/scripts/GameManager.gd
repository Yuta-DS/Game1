extends Node


func _ready():
	pass

func request_pop_thoughts():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/popThoughtsMenu.tscn"
	MusicManager._check_scene()  
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 

func request_paingting():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/paint_tool.tscn"
	MusicManager._check_scene()  
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
	
func request_art_gallery():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/ArtGallery.tscn"
	MusicManager._check_scene()  
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
	
func request_visit_website():
	OS.shell_open("https://www.louisachancreative.com/")
	
func request_goback_HubWorld():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/artea_game.tscn"
	MusicManager._check_scene()  
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 

func request_Art_Therapy():
	var loading_screen = preload("res://scenes/loading_scene.tscn").instantiate()
	loading_screen.next_scene_path = "res://scenes/art_therapist_Scene.tscn"
	MusicManager._check_scene()  
	get_tree().root.add_child(loading_screen)
	get_tree().current_scene.queue_free() 
