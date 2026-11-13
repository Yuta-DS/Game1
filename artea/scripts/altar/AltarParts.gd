@tool
class_name AltarParts
extends RefCounted

## LEGO-style brick library for the Crystal Altar.
##
## Every function here returns one primitive "brick": a Mesh, a Material, or a
## small MeshInstance3D. Nothing in this file knows what the finished altar
## looks like — assembly happens in CrystalAltar.gd. That separation is what
## makes the parts reusable for other props (pedestals, shrines, beacons).
##
## The bricks are built for close inspection: stone plates carry chamfered
## rims and recessed faces, crystals are properly faceted with a shoulder
## bevel, and rings step rather than sitting flat. A full-detail altar lands
## around 30k triangles, which is what it takes for the silhouette to hold up
## when the camera is right next to it.
##
## Units are metres. The altar is authored around a 2.0 m outer diameter so it
## reads at roughly waist height next to the existing player scenes.

# --- Palette ---------------------------------------------------------------
# Sampled from the reference art. Kept as constants so a future variant can
# recolour the whole prop by overriding these before calling the builders.

## Stone runs cool and mid-dark. Toon diffuse quantises lighting into a couple
## of bands, so a light albedo has nowhere to go and washes out to grey — these
## sit low enough that the lit band still reads as stone rather than as paper.
const STONE_DARK := Color("2b3040")
const STONE_MID := Color("3f4658")
const STONE_LIGHT := Color("6d778c")
const GLOW_CYAN := Color("4fc3f7")
const CRYSTAL_PALE := Color("8fd8f5")
const CRYSTAL_DEEP := Color("2a6fa8")
const ARCANE_PURPLE := Color("9b6cff")
const ARCANE_BRIGHT := Color("e0d4ff")

# --- Materials -------------------------------------------------------------

## Toon base shared by every solid surface on the altar.
##
## The project's existing 3D assets (see scenes/fox.tscn, New_Hub_World.tscn)
## are authored as stylised toon rather than PBR: `diffuse_mode = TOON`,
## `specular_mode = TOON`, roughness near 1 and no metallic. Matching that here
## is what makes the altar sit in the same world as the rest of the art instead
## of looking like a photoreal prop dropped into a stylised scene.
static func toon_base(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 1.0
	mat.metallic = 0.0
	# Vertex colours carry the baked edge-wear highlights the brick builders
	# write, so close-up surfaces don't read as flat untextured polygons.
	mat.vertex_color_use_as_albedo = true
	return mat


## Rough carved stone. Used by every ring tier and the spire collars.
static func stone_material(tint: Color = STONE_MID) -> StandardMaterial3D:
	var mat := toon_base(tint)
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## Brick-like metal for bezels, collars, sockets and the medallion band.
##
## Not polished chrome: a hard toon highlight with a bright rim, which is how
## metal reads in a flat-shaded game. `metallic` stays low because a high value
## under toon diffuse just crushes the surface to black wherever the key light
## doesn't hit it.
static func metal_material(tint: Color = STONE_MID) -> StandardMaterial3D:
	var mat := toon_base(tint)
	mat.roughness = 0.55
	mat.metallic = 0.25
	mat.metallic_specular = 0.7
	# The rim is what sells "metal" in toon shading — it draws the bright edge
	# highlight along every silhouette that a specular lobe would give in PBR.
	mat.rim_enabled = true
	mat.rim = 0.65
	mat.rim_tint = 0.25
	return mat


## Flat emissive fill for seams, light bars and the core well.
## `energy` is what the altar's charge level animates.
static func glow_material(tint: Color = GLOW_CYAN, energy: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = energy
	# Unshaded keeps the glow readable under GL Compatibility, which has no
	# volumetric or SDFGI bounce to sell the light on its own.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## Translucent crystal for the spires and the floating focus gem.
static func crystal_material(tint: Color = CRYSTAL_PALE, energy: float = 1.4) -> StandardMaterial3D:
	# The albedo is darkened well below the emission tint. Toon shading has no
	# midtones to fall back on, so a bright albedo plus emission saturates every
	# facet to the same white and the cut geometry stops reading entirely.
	var mat := toon_base(Color(tint.r * 0.45, tint.g * 0.5, tint.b * 0.62, 0.88))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = tint * 0.55
	mat.emission_energy_multiplier = energy * 0.5
	mat.roughness = 0.25
	# A hard rim is what reads as "glassy" under toon shading, where a low
	# roughness alone produces no visible highlight.
	mat.rim_enabled = true
	mat.rim = 0.9
	mat.rim_tint = 0.6
	return mat


## Additive material for beams, bursts and sparkles.
##
## Depth write is off and culling is disabled so overlapping cards never punch
## holes in each other or vanish when seen from behind — an additive surface
## has no "back", and writing depth would let the nearest one occlude the rest.
static func additive_material(tint: Color, alpha: float = 0.35) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_receive_shadows = true
	mat.disable_ambient_light = true
	return mat


# --- Brick 01: chamfered stone plate ---------------------------------------

## A single masonry block — the atom the whole altar body is built from.
##
## Cut like real dressed stone rather than extruded like a box:
##
##   * the outer face **bulges** outward and is broken into flat facets, so the
##     block catches the key light as a run of distinct planes instead of one
##     smooth curve;
##   * a chamfer runs right around the top — outer edge, both ends and the
##     inner edge — so every silhouette carries a bright cut line;
##   * the top face is recessed inside that chamfer, dropping a shadow into the
##     middle of the block;
##   * the ends are **undercut**, pulling the block's sides in slightly toward
##     the bottom so the mortar groove between neighbours reads as a deep V
##     rather than a hairline gap.
##
## Those four things together are what make a wall of these read as masonry at
## close range. `arc_segments` controls how many facets the bulged outer face is
## split into.
static func build_plate(
	inner_radius: float,
	outer_radius: float,
	height: float,
	angle_start: float,
	angle_end: float,
	chamfer: float = 0.018,
	recess_depth: float = 0.012,
	arc_segments: int = 3,
	bulge: float = 0.022,
	undercut: float = 0.16
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top := height
	var rim := height - chamfer  # where the top chamfer starts
	var face := height - recess_depth  # the sunken top face
	var ri := inner_radius
	var ro := outer_radius
	var ri_c := inner_radius + chamfer
	var ro_c := outer_radius - chamfer

	# The block's ends pull inward toward the base, widening the groove between
	# neighbouring blocks as it goes down.
	var span := angle_end - angle_start
	var taper := span * undercut * 0.5
	var a_lo0 := angle_start + taper
	var a_lo1 := angle_end - taper

	# Edge wear baked into vertex colour: cut edges catch light, recesses and
	# undersides fall into shadow. Costs nothing and needs no texture.
	var c_rim := Color(1.0, 1.0, 1.02)
	var c_face := Color(0.66, 0.68, 0.75)
	var c_wall_hi := Color(0.88, 0.89, 0.93)
	var c_wall_lo := Color(0.70, 0.71, 0.76)
	var c_end := Color(0.56, 0.58, 0.64)
	var c_under := Color(0.44, 0.46, 0.52)

	var steps: int = max(1, arc_segments)

	for s in steps:
		var f0 := float(s) / float(steps)
		var f1 := float(s + 1) / float(steps)
		var a0 := lerpf(angle_start, angle_end, f0)
		var a1 := lerpf(angle_start, angle_end, f1)
		var b0 := lerpf(a_lo0, a_lo1, f0)
		var b1 := lerpf(a_lo0, a_lo1, f1)

		# Outward swell, strongest at the middle of the block and zero at its
		# ends, so the facets fan out from the centre of each stone.
		var r0 := ro + sin(f0 * PI) * outer_radius * bulge
		var r1 := ro + sin(f1 * PI) * outer_radius * bulge
		var rc0 := (ro_c) + sin(f0 * PI) * outer_radius * bulge
		var rc1 := (ro_c) + sin(f1 * PI) * outer_radius * bulge

		# Facets on the upper half catch more light than those below.
		var mid := height * 0.45
		_quad_c(
			st,
			_pol(r1, b1, 0.0), _pol(r0, b0, 0.0),
			_pol(r0, a0, mid), _pol(r1, a1, mid),
			c_wall_lo
		)
		_quad_c(
			st,
			_pol(r1, a1, mid), _pol(r0, a0, mid),
			_pol(r0, a0, rim), _pol(r1, a1, rim),
			c_wall_hi
		)
		# Outer chamfer — the bright bevel along the top edge.
		_quad_c(
			st,
			_pol(r1, a1, rim), _pol(r0, a0, rim),
			_pol(rc0, a0, top), _pol(rc1, a1, top),
			c_rim
		)
		# Top rim band, from the chamfer in to the recess.
		_quad_c(
			st,
			_pol(rc1, a1, top), _pol(rc0, a0, top),
			_pol(ri_c, a0, top), _pol(ri_c, a1, top),
			c_rim
		)
		# Recess wall and sunken face.
		_quad_c(
			st,
			_pol(ri_c, a1, top), _pol(ri_c, a0, top),
			_pol(ri_c, a0, face), _pol(ri_c, a1, face),
			c_face
		)
		_quad_c(
			st,
			_pol(ri_c, a1, face), _pol(ri_c, a0, face),
			_pol(ri, a0, face), _pol(ri, a1, face),
			c_face
		)
		# Inner wall and underside.
		_quad_c(
			st,
			_pol(ri, a1, face), _pol(ri, a0, face),
			_pol(ri, a0, 0.0), _pol(ri, a1, 0.0),
			c_face
		)
		_quad_c(
			st,
			_pol(ri, a1, 0.0), _pol(ri, a0, 0.0),
			_pol(r0, b0, 0.0), _pol(r1, b1, 0.0),
			c_under
		)

	# The undercut ends, drawn as their own quads so the groove has real depth.
	_plate_end(st, ri, ro, ri_c, ro_c, top, rim, face, angle_start, a_lo0, bulge, true, c_end)
	_plate_end(st, ri, ro, ri_c, ro_c, top, rim, face, angle_end, a_lo1, bulge, false, c_end)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Closes one angular end of a block.
##
## `angle_top` is the end's angle at the top of the block and `angle_bottom` the
## angle it has pulled in to at the base — the difference is the undercut that
## turns the joint between two blocks into a visible V-groove.
static func _plate_end(
	st: SurfaceTool,
	ri: float, ro: float, ri_c: float, ro_c: float,
	top: float, rim: float, face: float,
	angle_top: float, angle_bottom: float,
	_bulge: float, flip: bool, tint: Color
) -> void:
	# Profile walked as a closed loop in the radial plane. The lower two corners
	# use the pulled-in angle, the upper ones the block's true edge.
	var pts: Array[Vector3] = [
		_pol(ri, angle_bottom, 0.0),
		_pol(ro, angle_bottom, 0.0),
		_pol(ro, angle_top, rim),
		_pol(ro_c, angle_top, top),
		_pol(ri_c, angle_top, top),
		_pol(ri_c, angle_top, face),
		_pol(ri, angle_top, face),
	]

	var centre := Vector3.ZERO
	for v in pts:
		centre += v
	centre /= float(pts.size())

	for k in pts.size():
		var v0: Vector3 = pts[k]
		var v1: Vector3 = pts[(k + 1) % pts.size()]
		if flip:
			_tri_c(st, centre, v1, v0, tint)
		else:
			_tri_c(st, centre, v0, v1, tint)


# --- Brick 02: faceted crystal ---------------------------------------------

## A cut gemstone: tapered pavilion, a girdle at the widest point, a slabbed
## crown and a flat table on top.
##
## This is the four-part silhouette real gems have, and it is why the result
## reads as crystal rather than as a cone — the girdle gives a hard highlight
## line, and the crown facets catch the light at a different angle from the
## pavilion. Facet normals are left hard (no smoothing) on purpose.
static func build_crystal(
	radius: float,
	height: float,
	waist: float = 0.62,
	sides: int = 12
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: int = max(3, sides)
	var step := TAU / float(n)
	var half := step * 0.5

	var y_base := 0.0
	var y_girdle := height * waist
	var y_crown := height * (waist + (1.0 - waist) * 0.45)
	var y_tip := height

	var r_base := radius * 0.55
	var r_girdle := radius
	var r_crown := radius * 0.72
	var r_table := radius * 0.30

	var c_bright := Color(1.0, 1.02, 1.06)
	var c_mid := Color(0.85, 0.86, 0.9)
	var c_deep := Color(0.66, 0.72, 0.85)

	for i in n:
		var a0 := step * i
		var a1 := step * (i + 1)
		var am := a0 + half  # facet apex, offset so facets interlock

		# Pavilion: alternating triangles from the base ring up to the girdle,
		# which is what gives the shaft its zig-zag cut instead of flat panels.
		_tri_c(st, _pol(r_base, a0, y_base), _pol(r_base, a1, y_base), _pol(r_girdle, am, y_girdle), c_deep)
		_tri_c(st, _pol(r_base, a1, y_base), _pol(r_girdle, a1 + half, y_girdle), _pol(r_girdle, am, y_girdle), c_mid)

		# Girdle band — the hard bright line around the widest point.
		_quad_c(
			st,
			_pol(r_girdle, am, y_girdle), _pol(r_girdle, a1 + half, y_girdle),
			_pol(r_crown, a1 + half, y_crown), _pol(r_crown, am, y_crown),
			c_bright
		)

		# Crown facets stepping in toward the table.
		_quad_c(
			st,
			_pol(r_crown, am, y_crown), _pol(r_crown, a1 + half, y_crown),
			_pol(r_table, a1 + half, y_tip), _pol(r_table, am, y_tip),
			c_mid
		)

		# Table and base fans.
		_tri_c(st, _pol(r_table, am, y_tip), _pol(r_table, a1 + half, y_tip), Vector3(0.0, y_tip, 0.0), c_bright)
		_tri_c(st, _pol(r_base, a1, y_base), _pol(r_base, a0, y_base), Vector3(0.0, y_base * 0.5, 0.0), c_deep)

	# Hard facet normals: smoothing here would melt the cut into a blob.
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Brick 03: stepped ring ------------------------------------------------

## A flat annulus built as `steps` concentric terraces, each dropping by
## `step_drop`. Used for the core well, where a single flat disc read as a
## sticker — the terraces give the recess real depth.
static func build_stepped_ring(
	inner_radius: float,
	outer_radius: float,
	steps: int = 4,
	step_drop: float = 0.012,
	segments: int = 48
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: int = max(3, segments)
	var d := TAU / float(n)
	var band := (outer_radius - inner_radius) / float(max(1, steps))

	for s in steps:
		var r_out := outer_radius - band * s
		var r_in := r_out - band
		var y := -step_drop * s
		var shade := 1.0 - 0.13 * s
		var tint := Color(shade, shade, shade * 1.03)

		for i in n:
			var a0 := d * i
			var a1 := d * (i + 1)
			# Terrace tread.
			_quad_c(
				st,
				_pol(r_in, a0, y), _pol(r_out, a0, y),
				_pol(r_out, a1, y), _pol(r_in, a1, y),
				tint
			)
			# Riser dropping to the next terrace in.
			_quad_c(
				st,
				_pol(r_in, a1, y), _pol(r_in, a0, y),
				_pol(r_in, a0, y - step_drop), _pol(r_in, a1, y - step_drop),
				tint.darkened(0.25)
			)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Brick 04: flat annulus ------------------------------------------------

## A plain disc with a hole, laid in the XZ plane. The cheap version of
## build_stepped_ring, for glow bands where depth would be wasted.
static func build_annulus(
	inner_radius: float,
	outer_radius: float,
	segments: int = 48
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: int = max(3, segments)
	var step := TAU / float(n)
	for i in n:
		var a0 := step * i
		var a1 := step * (i + 1)
		_quad(
			st,
			_pol(inner_radius, a0, 0.0),
			_pol(outer_radius, a0, 0.0),
			_pol(outer_radius, a1, 0.0),
			_pol(inner_radius, a1, 0.0)
		)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Brick 05: bevelled torus ----------------------------------------------

## A torus with a flattened, faceted cross-section — reads as machined metal
## rather than a rubber doughnut. `facets` controls the cross-section, so 6
## gives a hex-stock ring and 16 gives an almost-round one.
static func build_torus(
	major_radius: float,
	minor_radius: float,
	major_segments: int = 48,
	facets: int = 10,
	flatten: float = 0.72
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var maj: int = max(3, major_segments)
	var min_n: int = max(3, facets)
	var maj_step := TAU / float(maj)
	var min_step := TAU / float(min_n)

	for i in maj:
		for j in min_n:
			var p00 := _torus_pt(major_radius, minor_radius, maj_step * i, min_step * j, flatten)
			var p10 := _torus_pt(major_radius, minor_radius, maj_step * (i + 1), min_step * j, flatten)
			var p11 := _torus_pt(major_radius, minor_radius, maj_step * (i + 1), min_step * (j + 1), flatten)
			var p01 := _torus_pt(major_radius, minor_radius, maj_step * i, min_step * (j + 1), flatten)
			# Outer half of the ring catches more light than the inner half.
			var lit := 0.84 + 0.16 * cos(min_step * j)
			_quad_c(st, p00, p10, p11, p01, Color(lit, lit, lit))

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Brick 06: claw prong --------------------------------------------------

## One tapered bracket finger. Several of these arranged in a circle make the
## claw setting that grips a spire or gem, replacing the plain collar ring.
static func build_prong(
	width: float,
	thickness: float,
	height: float,
	lean: float = 0.22
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw := width * 0.5
	var ht := thickness * 0.5
	# The tip is narrower and pulled inward, so the prong curls over whatever
	# it is holding.
	var tw := hw * 0.45
	var tt := ht * 0.5
	var tz := -lean * height

	var b0 := Vector3(-hw, 0.0, -ht)
	var b1 := Vector3(hw, 0.0, -ht)
	var b2 := Vector3(hw, 0.0, ht)
	var b3 := Vector3(-hw, 0.0, ht)
	var t0 := Vector3(-tw, height, tz - tt)
	var t1 := Vector3(tw, height, tz - tt)
	var t2 := Vector3(tw, height, tz + tt)
	var t3 := Vector3(-tw, height, tz + tt)

	var c_lit := Color(1.0, 1.0, 1.03)
	var c_dim := Color(0.8, 0.82, 0.88)

	_quad_c(st, b0, b1, t1, t0, c_dim)
	_quad_c(st, b1, b2, t2, t1, c_lit)
	_quad_c(st, b2, b3, t3, t2, c_lit)
	_quad_c(st, b3, b0, t0, t3, c_dim)
	_quad_c(st, t0, t1, t2, t3, c_lit)
	_quad_c(st, b3, b2, b1, b0, c_dim)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Brick 07: N-point star ------------------------------------------------

## Flat star emblem — the small inlay on the medallion face.
##
## Kept flat on purpose: it is set *into* a metal disc, so it reads as an
## engraved inlay. The dimensional star used for the charged burst is
## build_star_gem below.
static func build_star(
	points: int,
	outer_radius: float,
	inner_radius: float,
	relief: float = 0.0
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: int = max(2, points)
	var step := TAU / float(n * 2)
	var centre := Vector3(0.0, 0.0, relief)
	for i in n * 2:
		var r0 := outer_radius if i % 2 == 0 else inner_radius
		var r1 := inner_radius if i % 2 == 0 else outer_radius
		var p0 := Vector3(cos(step * i) * r0, sin(step * i) * r0, 0.0)
		var p1 := Vector3(cos(step * (i + 1)) * r1, sin(step * (i + 1)) * r1, 0.0)
		var lit := 1.0 if i % 2 == 0 else 0.78
		_tri_c(st, centre, p0, p1, Color(lit, lit, lit))

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A dimensional, faceted star — the four-point burst that crowns the charged
## altar.
##
## A flat star silhouette looks like a sticker from any angle but dead-on, which
## is why the earlier version read so poorly. This one is built the way a cut
## gemstone is: every arm is a four-sided spike running from a raised centre
## ridge out to its tip, so each arm always shows one lit facet and one shaded
## facet. That two-tone split down the length of every point is what makes it
## read as a solid object rotating in space.
##
## `arms` long points alternate with `arms` shorter diagonal points, matching
## the reference's eight-rayed burst.
static func build_star_gem(
	arms: int,
	outer_radius: float,
	minor_ratio: float = 0.42,
	waist_radius: float = 0.16,
	thickness: float = 0.11
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: int = max(2, arms)
	# Long and short points alternate, so the loop walks 2n rays.
	var rays := n * 2
	var step := TAU / float(rays)
	var wr := outer_radius * waist_radius
	var half_t := outer_radius * thickness

	var front := Vector3(0.0, 0.0, half_t)
	var back := Vector3(0.0, 0.0, -half_t)

	var c_lit := Color(1.0, 1.0, 1.02)
	var c_shade := Color(0.62, 0.66, 0.82)
	var c_edge := Color(0.86, 0.88, 0.98)

	for i in rays:
		var long_ray := i % 2 == 0
		var tip_r := outer_radius if long_ray else outer_radius * minor_ratio
		var a := step * i
		var tip := Vector3(cos(a) * tip_r, sin(a) * tip_r, 0.0)

		# The two waist corners this ray springs from, half a step either side.
		var a_prev := a - step * 0.5
		var a_next := a + step * 0.5
		var w_prev := Vector3(cos(a_prev) * wr, sin(a_prev) * wr, 0.0)
		var w_next := Vector3(cos(a_next) * wr, sin(a_next) * wr, 0.0)

		# Four facets per ray: two on the front face, two on the back. Splitting
		# each side down the ray's centre line is what gives every arm its own
		# lit/shaded pair rather than one flat plane.
		_tri_c(st, front, w_prev, tip, c_lit)
		_tri_c(st, front, tip, w_next, c_shade)
		_tri_c(st, back, tip, w_prev, c_shade)
		_tri_c(st, back, w_next, tip, c_edge)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A short crystal segment with a girdle at each end — the building block for a
## banded spire.
##
## Stacking several of these with slight scale and twist differences gives a
## crystal visible internal cleave lines, the way a real quartz point is made of
## stacked growth zones rather than one smooth cone.
static func build_crystal_segment(
	bottom_radius: float,
	top_radius: float,
	height: float,
	sides: int = 8,
	bulge: float = 1.08
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: int = max(3, sides)
	var step := TAU / float(n)
	var half := step * 0.5
	# The segment swells slightly at mid-height, so the stack has a visible
	# ridge at every joint instead of reading as one straight taper.
	var mid_r := (bottom_radius + top_radius) * 0.5 * bulge
	var y_mid := height * 0.5

	for i in n:
		var a0 := step * i
		var a1 := step * (i + 1)
		# Offsetting the mid ring by half a facet interlocks the two bands, so
		# the joint line zig-zags the way a natural cleave does.
		var am := a0 + half

		var b0 := _pol(bottom_radius, a0, 0.0)
		var b1 := _pol(bottom_radius, a1, 0.0)
		var m0 := _pol(mid_r, am, y_mid)
		var m1 := _pol(mid_r, am + step, y_mid)
		var t0 := _pol(top_radius, a0, height)
		var t1 := _pol(top_radius, a1, height)

		var lit := 0.82 + 0.18 * cos(a0)
		var c_low := Color(lit * 0.9, lit * 0.92, lit)
		var c_high := Color(lit, lit, lit * 1.02)

		# Lower band: base edge up to the interlocking mid ring.
		_tri_c(st, b0, b1, m0, c_low)
		_tri_c(st, b1, m1, m0, c_low)
		# Upper band: mid ring up to the top edge.
		_tri_c(st, m0, m1, t1, c_high)
		_tri_c(st, m0, t1, t0, c_high)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Brick 08: bevelled box ------------------------------------------------

## A box with cut corners — for light bars and rune tiles, where a raw BoxMesh
## reads as a programmer placeholder next to the chamfered stone.
static func build_bevel_box(size: Vector3, bevel: float = 0.006) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h := size * 0.5
	var b: float = min(bevel, min(h.x, min(h.y, h.z)) * 0.9)
	var c_top := Color(1.0, 1.0, 1.03)
	var c_side := Color(0.8, 0.81, 0.84)

	# Top face, inset by the bevel on all sides.
	_quad_c(
		st,
		Vector3(-h.x + b, h.y, -h.z + b), Vector3(h.x - b, h.y, -h.z + b),
		Vector3(h.x - b, h.y, h.z - b), Vector3(-h.x + b, h.y, h.z - b),
		c_top
	)
	# Four bevel ramps from the inset top edge out to the full-width sides.
	_quad_c(st, Vector3(-h.x + b, h.y, -h.z + b), Vector3(-h.x, h.y - b, -h.z), Vector3(h.x, h.y - b, -h.z), Vector3(h.x - b, h.y, -h.z + b), c_top)
	_quad_c(st, Vector3(h.x - b, h.y, h.z - b), Vector3(h.x, h.y - b, h.z), Vector3(-h.x, h.y - b, h.z), Vector3(-h.x + b, h.y, h.z - b), c_top)
	_quad_c(st, Vector3(h.x - b, h.y, -h.z + b), Vector3(h.x, h.y - b, -h.z), Vector3(h.x, h.y - b, h.z), Vector3(h.x - b, h.y, h.z - b), c_top)
	_quad_c(st, Vector3(-h.x + b, h.y, h.z - b), Vector3(-h.x, h.y - b, h.z), Vector3(-h.x, h.y - b, -h.z), Vector3(-h.x + b, h.y, -h.z + b), c_top)
	# Straight sides down to the base.
	_quad_c(st, Vector3(-h.x, h.y - b, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y - b, -h.z), c_side)
	_quad_c(st, Vector3(h.x, h.y - b, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y - b, h.z), c_side)
	_quad_c(st, Vector3(h.x, h.y - b, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y - b, h.z), c_side)
	_quad_c(st, Vector3(-h.x, h.y - b, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y - b, -h.z), c_side)
	# Base.
	_quad_c(st, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), c_side * 0.6)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Brick 09: tapered cylinder --------------------------------------------

## A faceted drum — spire sockets, medallion bosses, beam cores.
static func build_drum(
	bottom_radius: float,
	top_radius: float,
	height: float,
	sides: int = 16,
	capped: bool = true
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: int = max(3, sides)
	var step := TAU / float(n)
	for i in n:
		var a0 := step * i
		var a1 := step * (i + 1)
		var lit := 0.86 + 0.14 * cos(a0)
		_quad_c(
			st,
			_pol(bottom_radius, a0, 0.0), _pol(bottom_radius, a1, 0.0),
			_pol(top_radius, a1, height), _pol(top_radius, a0, height),
			Color(lit, lit, lit)
		)
		if capped:
			_tri_c(st, _pol(top_radius, a0, height), _pol(top_radius, a1, height), Vector3(0.0, height, 0.0), Color(1.0, 1.0, 1.03))
			_tri_c(st, _pol(bottom_radius, a1, 0.0), _pol(bottom_radius, a0, 0.0), Vector3.ZERO, Color(0.6, 0.62, 0.68))

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Helpers ---------------------------------------------------------------

static func _pol(radius: float, angle: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


## Torus surface point, with the cross-section squashed vertically by
## `flatten` so the ring reads as milled bar stock rather than round wire.
static func _torus_pt(major: float, minor: float, u: float, v: float, flatten: float) -> Vector3:
	var ring := major + cos(v) * minor
	return Vector3(cos(u) * ring, sin(v) * minor * flatten, sin(u) * ring)


## Emits a triangle with planar UVs and a flat vertex colour.
##
## Every brick is flat-shaded stone or crystal with no texture atlas, so the
## UVs only need to exist and be non-degenerate — SurfaceTool refuses to
## generate tangents without them. The colour is the baked edge-wear tint.
static func _tri_c(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	tint: Color = Color.WHITE,
	uv_a := Vector2(0.0, 0.0),
	uv_b := Vector2(1.0, 0.0),
	uv_c := Vector2(1.0, 1.0)
) -> void:
	st.set_color(tint)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_color(tint)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_color(tint)
	st.set_uv(uv_c)
	st.add_vertex(c)


static func _quad_c(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	tint: Color = Color.WHITE
) -> void:
	_tri_c(st, a, b, c, tint, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0))
	_tri_c(st, a, c, d, tint, Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	_tri_c(st, a, b, c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_quad_c(st, a, b, c, d)
