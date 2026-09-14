extends Node

## Distance-gated visibility for the Art Castle's floating world.
##
## Deliberately has no `class_name`: callers preload it as a const, for the same
## reason scene_loader.gd does. The headless `--script` suites run without the
## editor-generated global class cache, so a `class_name` reference would stop
## the calling scripts compiling there.
##
## Why this exists
## ---------------
## The castle interior (art_gallery_3d_inprogress.tscn) does not stop at the
## gallery walls. art_gallery.gd::_build_galaxy_transit() builds the entire 2 km
## floating world into the same scene, deliberately: walking north out of the
## gallery continues straight into the world with no portal and no scene change.
##
## The cost of that was never paid for. Measured standing on the gallery floor:
##
##     VisualInstance3D visible in tree : 29,176
##     mesh surfaces                    : 29,051
##     triangles                        : 15,951,968
##
## and almost none of it is anywhere near the player:
##
##     MindSparkWorldOne          21,355 nodes   1,205 m away
##     KingdomRegions3000m         1,838 nodes   1,927 m away
##     MindSparkWorldOneCauseway   1,398 nodes   1,377 m away
##     CentralSanctuary              294 nodes     914 m away
##
## The Compatibility renderer is the only one the Web export can use, and it
## culls on the CPU, single-threaded - the Web export ships without WASM thread
## support (see export_presets.cfg and the note in loading_scene.gd). So every
## one of those 29,176 instances is walked on the main thread every frame before
## a single one is drawn, and the ones that survive the frustum each cost a draw
## call. That is the reason the castle sits at 30-45 ms a frame.
##
## What this does
## --------------
## Splits the world into cells and hides the ones that are too far away to read,
## using the only measure that matters for whether something can be seen: how
## big it is against how far away it is. A cell's view distance is proportional
## to its own radius, so the Tree of Life stays visible across the world while a
## 2 m handrail 400 m away does not.
##
## Toggling `visible` on a cell root drops the whole subtree out of the render
## server's list - it is not a per-instance test that still has to be evaluated,
## which is the thing that needs avoiding here.
##
## What it deliberately does not touch
## -----------------------------------
## - Collision. Visibility and physics are independent in Godot; StaticBody3D
##   children of a hidden cell keep their shapes, so nothing can be fallen
##   through while a cell is hidden.
## - Anything already hidden. The world builders hide superseded geometry all
##   over the place (`_hide_generic_passage_visuals`, the legacy tree body, the
##   pre-batch canopy nodes). A cell root that was already invisible when this
##   built its list is never managed and never shown.

## Cells are bundled up to roughly this many visual nodes before the splitter
## stops descending. Large enough that the cell list stays short (a few hundred
## entries, checked in a handful of microseconds), small enough that a distant
## district is not held on screen by one nearby corner of it.
const CELL_TARGET_NODES := 600

## A cell is never built from more roots than this. Without a cap, a node with
## 300 single-mesh children would put 300 roots in one cell and make the
## per-check AABB work proportional to the scene rather than to the cell list.
const CELL_MAX_ROOTS := 32

## How far the splitter will descend before it gives up and takes what it has.
const MAX_SPLIT_DEPTH := 6

## View distance is `object_radius * SIZE_FACTOR`, clamped.
##
## `object_radius` is the size of the individual meshes in the cell, NOT the
## size of the cell itself. That distinction is the whole design. Gating on the
## cell's own bounding radius keeps a district on screen simply because it is
## spread out - measured, that left 11,452 of MindSpark's instances drawing from
## 1.2 km away, because 600 scattered handrails happen to bound a large box.
## What decides whether something can be seen is how big the thing itself is.
##
## Cells are not perfectly homogeneous, so this takes the 75th percentile rather
## than the mean (one large mesh should not hold 600 small ones on screen) or
## the maximum (ditto). A cell that is genuinely made of large geometry - the
## Tree of Life, the island foundations, the skyline - has a large p75 and keeps
## its distance.
const SIZE_FACTOR := 14.0
const OBJECT_RADIUS_PERCENTILE := 0.75

## The floor is the real knob for scattered detail: every small prop in the
## world ends up here, because `radius * 14` for a 2 m railing is far below it.
## 260 m is comfortably past anything the player can make out on the move.
const MIN_VIEW_DISTANCE := 260.0
const MAX_VIEW_DISTANCE := 2600.0

## Shown at `view_distance`, hidden again at `view_distance * HYSTERESIS`. A
## single threshold makes a cell flicker on and off while the player walks along
## it, and each flicker back on is a fresh batch of draw calls.
const HYSTERESIS := 1.18

## Cells are re-tested on this cadence rather than every frame. The test itself
## is cheap, but there is no reason to pay for it 60 times a second when the
## player cannot cross a cell boundary that fast.
const CHECK_INTERVAL_FRAMES := 4

## Everything within this radius of the player is shown regardless of size, so
## small detail underfoot is never culled by the size rule.
const ALWAYS_VISIBLE_RADIUS := 140.0


class Cell:
	var roots: Array[Node3D] = []
	## Each root's own AABB in that root's local space, so a cell that moves
	## (the Crown Line train) is still tested where it actually is.
	var local_aabbs: Array[AABB] = []
	var cached_world_aabb := AABB()
	## Static cells reuse `cached_world_aabb`; only cells that can move are
	## recomputed on every check.
	var dynamic := false
	var view_distance := 0.0
	var shown := true
	## Cells that are only text - the world's signposts. They are one draw call
	## each and are meant to be legible from across the world, so they are never
	## culled by distance.
	var pinned := false


var world_root: Node3D
var player: Node3D

var _cells: Array[Cell] = []
var _frames_until_check := 0
var _built := false


func _ready() -> void:
	# The world is still assembling itself when this is added: the floating
	# world builds in its own _ready(), and MindSparkWorldOne and the railway
	# build in theirs, which run after. Taking the cell list now would miss
	# most of the scene, so wait for the tree to settle first.
	set_process(true)


func _process(_delta: float) -> void:
	if not _built:
		# Two idle frames is enough for every child _ready() to have run and
		# for the deferred batching pass in mind_spark_world_one.gd to have
		# collapsed what it can - building before that would put the nodes it
		# is about to free into the cell list.
		_frames_until_check += 1
		if _frames_until_check < 3:
			return
		_build_cells()
		_built = true
		_frames_until_check = 0
		_apply(true)
		return
	_frames_until_check -= 1
	if _frames_until_check > 0:
		return
	_frames_until_check = CHECK_INTERVAL_FRAMES
	_apply(false)


## Re-derive the cell list. Call after adding or removing a large part of the
## world at runtime; the per-frame path never does this.
func rebuild() -> void:
	_cells.clear()
	_build_cells()
	_apply(true)


func get_cell_count() -> int:
	return _cells.size()


func get_visible_cell_count() -> int:
	var total := 0
	for cell in _cells:
		if cell.shown:
			total += 1
	return total


## Show every cell this is managing, for comparing against the uncelled world.
## Only touches cell roots, so geometry the world builders hid stays hidden.
func show_all_managed_cells() -> void:
	for cell in _cells:
		_set_cell_visible(cell, true)


# --- cell construction -------------------------------------------------------


func _build_cells() -> void:
	if world_root == null or not is_instance_valid(world_root):
		return
	for child in world_root.get_children():
		if child is Node3D and child != self:
			_split(child as Node3D, 0)


func _split(node: Node3D, depth: int) -> void:
	# A node the world builder deliberately hid stays hidden: this manages
	# visibility, it does not overrule decisions already made about it.
	if not node.visible:
		return
	var count := _visual_count(node)
	if count == 0:
		return
	if count <= CELL_TARGET_NODES or depth >= MAX_SPLIT_DEPTH:
		_add_cell([node])
		return

	# Too big to be one cell. Descend, bundling the small children together so
	# a node with hundreds of single-mesh children yields a handful of cells
	# rather than hundreds of them.
	var bundle: Array[Node3D] = []
	var bundle_count := 0
	for child in node.get_children():
		if not (child is Node3D) or child == self:
			continue
		var child_node := child as Node3D
		if not child_node.visible:
			continue
		var child_count := _visual_count(child_node)
		if child_count == 0:
			continue
		if child_count > CELL_TARGET_NODES:
			_split(child_node, depth + 1)
			continue
		bundle.append(child_node)
		bundle_count += child_count
		if bundle_count >= CELL_TARGET_NODES or bundle.size() >= CELL_MAX_ROOTS:
			_add_cell(bundle)
			bundle = []
			bundle_count = 0
	if not bundle.is_empty():
		_add_cell(bundle)


func _add_cell(roots: Array) -> void:
	var cell := Cell.new()
	var world_aabb := AABB()
	var first := true
	var all_labels := true
	var object_radii: Array[float] = []
	for root_node in roots:
		var root := root_node as Node3D
		if root == null:
			continue
		var local := _local_aabb(root)
		if local.size == Vector3.ZERO:
			continue
		cell.roots.append(root)
		cell.local_aabbs.append(local)
		if not cell.dynamic and _can_move(root):
			cell.dynamic = true
		if all_labels and not _only_labels(root):
			all_labels = false
		_collect_object_radii(root, object_radii)
		var in_world: AABB = root.global_transform * local
		if first:
			world_aabb = in_world
			first = false
		else:
			world_aabb = world_aabb.merge(in_world)
	if cell.roots.is_empty():
		return
	cell.cached_world_aabb = world_aabb
	cell.pinned = all_labels
	cell.view_distance = clampf(_percentile(object_radii, OBJECT_RADIUS_PERCENTILE) * SIZE_FACTOR,
		MIN_VIEW_DISTANCE, MAX_VIEW_DISTANCE)
	_cells.append(cell)


## The world-space radius of every individual visible mesh under `root`. A
## MultiMesh contributes its element's radius, not the radius of the whole
## batch, for the same reason the cell's own extent is not used: a batch of
## 4,000 leaves scattered over a district is still 4,000 small things.
func _collect_object_radii(root: Node3D, into: Array[float]) -> void:
	var stack: Array = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is VisualInstance3D) or node is Light3D:
			continue
		var visual := node as VisualInstance3D
		if not visual.visible:
			continue
		var local_aabb := visual.get_aabb()
		if node is MultiMeshInstance3D:
			var multi := (node as MultiMeshInstance3D).multimesh
			if multi != null and multi.mesh != null:
				local_aabb = multi.mesh.get_aabb()
		var scale := visual.global_transform.basis.get_scale()
		var sized := Vector3(
			local_aabb.size.x * scale.x,
			local_aabb.size.y * scale.y,
			local_aabb.size.z * scale.z)
		into.append(sized.length() * 0.5)


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	var index := int(floorf(float(values.size() - 1) * fraction))
	return values[clampi(index, 0, values.size() - 1)]


## The union of every visible mesh in `root`'s subtree, expressed in `root`'s
## own local space so it survives the node being moved or rotated later.
func _local_aabb(root: Node3D) -> AABB:
	var to_local := root.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	var stack: Array = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is VisualInstance3D) or node is Light3D:
			continue
		var visual := node as VisualInstance3D
		if not visual.visible:
			continue
		var in_root: AABB = to_local * (visual.global_transform * visual.get_aabb())
		if first:
			result = in_root
			first = false
		else:
			result = result.merge(in_root)
	return result


func _visual_count(root: Node) -> int:
	var total := 0
	var stack: Array = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is VisualInstance3D and not (node is Light3D):
			total += 1
	return total


## A cell is treated as movable if anything in it carries a script, since that
## script may be driving a transform. Static cells reuse the AABB computed once
## here, which is what keeps the per-check cost proportional to the cell list
## rather than to the scene.
func _can_move(root: Node3D) -> bool:
	var stack: Array = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node.get_script() != null:
			return true
		if node is AnimationPlayer or node is AnimationTree:
			return true
		for child in node.get_children():
			stack.append(child)
	return false


func _only_labels(root: Node3D) -> bool:
	var stack: Array = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is VisualInstance3D and not (node is Light3D) and not (node is Label3D):
			return false
	return true


# --- per-check visibility ----------------------------------------------------


## The node distances are measured from. Normally the player, but the owner
## cannot always hand one over: embedded in ArtGallery.tscn the world is built
## inside a SubViewport whose parent has no Player3D under it. Falling back to
## the "Player" group and then to the active camera means the world is gated
## against whatever is actually looking at it rather than silently staying at
## full cost.
func _resolve_eye() -> Node3D:
	if player != null and is_instance_valid(player):
		return player
	if not is_inside_tree():
		return null
	var tagged := get_tree().get_first_node_in_group("Player")
	if tagged is Node3D:
		player = tagged as Node3D
		return player
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_3d()
		if camera != null:
			return camera
	return null


func _apply(force: bool) -> void:
	var eye_node := _resolve_eye()
	if eye_node == null:
		return
	var eye := eye_node.global_position
	for cell in _cells:
		if cell.pinned:
			if not cell.shown:
				_set_cell_visible(cell, true)
			continue
		var box := cell.cached_world_aabb
		if cell.dynamic:
			box = _world_aabb(cell)
		var distance := _distance_to(box, eye)
		var threshold := cell.view_distance
		if cell.shown:
			# Widened once shown, so a cell sitting exactly on its own
			# threshold does not toggle every check.
			threshold *= HYSTERESIS
		var want := distance <= maxf(threshold, ALWAYS_VISIBLE_RADIUS)
		if force or want != cell.shown:
			_set_cell_visible(cell, want)


func _set_cell_visible(cell: Cell, value: bool) -> void:
	cell.shown = value
	for index in cell.roots.size():
		var root := cell.roots[index]
		if is_instance_valid(root):
			root.visible = value


func _world_aabb(cell: Cell) -> AABB:
	var result := AABB()
	var first := true
	for index in cell.roots.size():
		var root := cell.roots[index]
		if not is_instance_valid(root):
			continue
		var in_world: AABB = root.global_transform * cell.local_aabbs[index]
		if first:
			result = in_world
			first = false
		else:
			result = result.merge(in_world)
	return result


## Distance from `point` to the nearest face of `box`, zero when inside it.
func _distance_to(box: AABB, point: Vector3) -> float:
	var closest := Vector3(
		clampf(point.x, box.position.x, box.end.x),
		clampf(point.y, box.position.y, box.end.y),
		clampf(point.z, box.position.z, box.end.z))
	return point.distance_to(closest)
