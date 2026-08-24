extends Node3D

# Turns the source painting's background into a living 360-degree environment.
# The image analysis is intentionally local and deterministic so every artwork
# gets a fitting atmosphere immediately, even while semantic vision is offline.

const BACKGROUND_HEIGHT_FRACTION := 0.62

var _profile: Dictionary = {}
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _background: MeshInstance3D
var _base_sky_top := Color.WHITE
var _base_sky_horizon := Color.WHITE
var _elapsed := 0.0


func configure(source: Image, manifest: Dictionary, palette: Array[Color],
		sky_material: ProceduralSkyMaterial, sun: DirectionalLight3D) -> void:
	_sky_material = sky_material
	_sun = sun
	_profile = analyse(source, manifest, palette)
	_build_living_background(source)
	_build_ambient_motion()
	_apply_profile()


func update_manifest(manifest: Dictionary) -> void:
	# Vision may identify rain, water, night, forest, or sky after the local world
	# is already open. Preserve the artwork texture and refresh its motion profile.
	var updated := analyse(null, manifest, _profile.get("palette", []))
	# Keep the immediate pixel analysis and layer later semantic discoveries on
	# top; a manifest refresh must never forget that the painted background was
	# visibly blue, green, warm, or dark.
	for quality in ["sky", "water", "vegetation", "night", "warmth"]:
		updated[quality] = maxf(float(updated.get(quality, 0.0)),
			float(_profile.get(quality, 0.0)))
	updated["motion_mode"] = _dominant_motion(updated)
	_profile = updated
	_apply_profile()
	if _background != null and _background.material_override is ShaderMaterial:
		_set_shader_profile(_background.material_override as ShaderMaterial)


func environment_profile() -> Dictionary:
	return _profile.duplicate(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _sky_material != null:
		var breath := sin(_elapsed * 0.12) * 0.035
		_sky_material.sky_top_color = _base_sky_top.lightened(maxf(0.0, breath)).darkened(maxf(0.0, -breath))
		_sky_material.sky_horizon_color = _base_sky_horizon.lightened(maxf(0.0, breath * 0.7))
	if _sun != null:
		var base_energy := float(_profile.get("sun_energy", 1.0))
		_sun.light_energy = base_energy + sin(_elapsed * 0.18) * 0.055
		_sun.rotation_degrees.y += delta * (0.28 if float(_profile.get("sky", 0.0)) > 0.35 else 0.10)


static func analyse(source: Image, manifest: Dictionary, palette_value) -> Dictionary:
	var palette: Array[Color] = []
	for value in palette_value:
		if value is Color:
			palette.append(value)
		elif Color.html_is_valid(str(value)):
			palette.append(Color(str(value)))
	if palette.is_empty():
		palette = [Color("86c5da"), Color("ffd166"), Color("8ac926")]

	var profile := {
		"sky": 0.0,
		"water": 0.0,
		"vegetation": 0.0,
		"night": 0.0,
		"warmth": 0.0,
		"palette": palette,
	}
	if source != null and not source.is_empty():
		var upper_count := 0.0
		var lower_count := 0.0
		var upper_sky := 0.0
		var lower_water := 0.0
		var lower_green := 0.0
		var dark := 0.0
		var warm := 0.0
		var total := 0.0
		for gy in 18:
			for gx in 24:
				var colour := source.get_pixel(
					clampi(int((float(gx) + 0.5) / 24.0 * source.get_width()), 0, source.get_width() - 1),
					clampi(int((float(gy) + 0.5) / 18.0 * source.get_height()), 0, source.get_height() - 1))
				var is_blue := colour.b > colour.r * 1.08 and colour.b > colour.g * 0.92
				var is_green := colour.g > colour.r * 1.08 and colour.g > colour.b * 0.92
				var is_warm := colour.r > colour.b * 1.12 and colour.g > colour.b * 0.72
				if gy < 9:
					upper_count += 1.0
					if is_blue or (colour.get_luminance() > 0.68 and colour.s < 0.32):
						upper_sky += 1.0
				else:
					lower_count += 1.0
					if is_blue:
						lower_water += 1.0
					if is_green:
						lower_green += 1.0
				if colour.get_luminance() < 0.27:
					dark += 1.0
				if is_warm:
					warm += 1.0
				total += 1.0
		profile["sky"] = upper_sky / maxf(1.0, upper_count)
		profile["water"] = lower_water / maxf(1.0, lower_count)
		profile["vegetation"] = lower_green / maxf(1.0, lower_count)
		profile["night"] = dark / maxf(1.0, total)
		profile["warmth"] = warm / maxf(1.0, total)

	var semantic_text := str(manifest.get("environment", "")).to_lower()
	for collection_name in ["objects", "characters"]:
		for item in manifest.get(collection_name, []):
			if item is Dictionary:
				semantic_text += " " + str(item.get("type", "")) + " " + str(item.get("description", ""))
	if _contains_any(semantic_text, ["river", "ocean", "sea", "water", "lake", "rain", "pond"]):
		profile["water"] = maxf(float(profile["water"]), 0.82)
	if _contains_any(semantic_text, ["tree", "forest", "garden", "grass", "flower", "jungle", "plant"]):
		profile["vegetation"] = maxf(float(profile["vegetation"]), 0.76)
	if _contains_any(semantic_text, ["night", "moon", "star", "dark sky", "space"]):
		profile["night"] = maxf(float(profile["night"]), 0.86)
	if _contains_any(semantic_text, ["sky", "cloud", "sun", "sunset", "rainbow"]):
		profile["sky"] = maxf(float(profile["sky"]), 0.75)

	profile["motion_mode"] = _dominant_motion(profile)
	profile["sun_energy"] = lerpf(1.16, 0.46, clampf(float(profile["night"]), 0.0, 1.0))
	return profile


static func _dominant_motion(profile: Dictionary) -> String:
	var strongest := "colour_breathe"
	var score := 0.0
	for candidate in ["water", "vegetation", "night", "sky", "warmth"]:
		if float(profile.get(candidate, 0.0)) > score:
			score = float(profile.get(candidate, 0.0))
			strongest = candidate
	return {
		"water": "water_ripples",
		"vegetation": "forest_wind",
		"night": "night_lights",
		"sky": "cloud_drift",
		"warmth": "warm_shimmer",
	}.get(strongest, "colour_breathe")


static func _contains_any(text: String, words: Array[String]) -> bool:
	for word in words:
		if text.contains(word):
			return true
	return false


func _build_living_background(source: Image) -> void:
	if source == null or source.is_empty():
		return
	_background = MeshInstance3D.new()
	_background.name = "LivingArtworkBackground"
	var surround := CylinderMesh.new()
	surround.top_radius = 25.0
	surround.bottom_radius = 25.0
	surround.height = 18.0
	surround.radial_segments = 64
	surround.rings = 8
	surround.cap_top = false
	surround.cap_bottom = false
	_background.mesh = surround
	_background.position.y = 8.0
	_background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D artwork_texture : source_color, filter_linear_mipmap;
uniform float wind_amount = 0.0;
uniform float water_amount = 0.0;
uniform float night_amount = 0.0;
uniform float warmth_amount = 0.0;
void fragment() {
	vec2 uv = UV;
	float wind = sin(TIME * 0.22 + uv.y * 9.0) * 0.004 * wind_amount;
	float ripple = sin(TIME * 0.85 + uv.x * 28.0) * 0.005 * water_amount * smoothstep(0.38, 1.0, uv.y);
	uv += vec2(wind, ripple);
	vec4 painted = texture(artwork_texture, uv);
	float shimmer = sin(TIME * 0.34 + uv.x * 7.0) * 0.025 * warmth_amount;
	ALBEDO = painted.rgb + shimmer;
	EMISSION = painted.rgb * (0.035 + night_amount * 0.16);
}
"""
	material.shader = shader
	material.set_shader_parameter("artwork_texture", _background_texture(source))
	_set_shader_profile(material)
	_background.material_override = material
	_background.set_meta("uses_artwork_background", true)
	_background.set_meta("source_artwork_size", source.get_size())
	add_child(_background)


func _background_texture(source: Image) -> Texture2D:
	var prepared := source.duplicate() as Image
	if prepared.is_compressed() and prepared.decompress() != OK:
		return null
	prepared.convert(Image.FORMAT_RGBA8)
	# The upper portion normally contains the painted distance/sky. Wrapping it
	# around the play space makes it scenery rather than a flat picture frame.
	var crop_height := maxi(1, int(prepared.get_height() * BACKGROUND_HEIGHT_FRACTION))
	var background_crop := prepared.get_region(Rect2i(0, 0, prepared.get_width(), crop_height))
	background_crop.resize(1024, 512, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(background_crop)


func _set_shader_profile(material: ShaderMaterial) -> void:
	material.set_shader_parameter("wind_amount", maxf(float(_profile.get("vegetation", 0.0)), float(_profile.get("sky", 0.0)) * 0.55))
	material.set_shader_parameter("water_amount", float(_profile.get("water", 0.0)))
	material.set_shader_parameter("night_amount", float(_profile.get("night", 0.0)))
	material.set_shader_parameter("warmth_amount", float(_profile.get("warmth", 0.0)))


func _build_ambient_motion() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ArtworkBackgroundMotion"
	particles.amount = 48 if float(_profile.get("night", 0.0)) > 0.45 else 28
	particles.lifetime = 8.0
	particles.randomness = 0.72
	particles.visibility_aabb = AABB(Vector3(-24, -4, -20), Vector3(48, 18, 40))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(20.0, 6.5, 15.0)
	motion.direction = Vector3(1.0, 0.16 if float(_profile.get("water", 0.0)) < 0.45 else 0.04, 0.0)
	motion.spread = 32.0
	motion.initial_velocity_min = 0.18
	motion.initial_velocity_max = 0.65
	motion.gravity = Vector3(0.0, -0.015, 0.0)
	particles.process_material = motion
	var mote := QuadMesh.new()
	mote.size = Vector2(0.10, 0.10)
	var mote_material := StandardMaterial3D.new()
	var night := float(_profile.get("night", 0.0))
	var vegetation := float(_profile.get("vegetation", 0.0))
	var mote_colour := Color("fff1a8") if night > 0.45 else Color("b8e986") if vegetation > 0.35 else Color("d9f4ff")
	mote_material.albedo_color = Color(mote_colour.r, mote_colour.g, mote_colour.b, 0.68)
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if night > 0.45:
		mote_material.emission_enabled = true
		mote_material.emission = mote_colour
		mote_material.emission_energy_multiplier = 2.2
	mote.material = mote_material
	particles.draw_pass_1 = mote
	particles.position.y = 5.5
	add_child(particles)


func _apply_profile() -> void:
	var colours: Array = _profile.get("palette", [])
	var first: Color = colours[0] if not colours.is_empty() else Color("86c5da")
	var second: Color = colours[min(1, colours.size() - 1)] if not colours.is_empty() else Color("ffd166")
	var night := clampf(float(_profile.get("night", 0.0)), 0.0, 1.0)
	_base_sky_top = first.lerp(Color("10162f"), night * 0.78).lerp(Color.WHITE, 0.08)
	_base_sky_horizon = second.lerp(first, 0.35).lerp(Color("262449"), night * 0.68)
	if _sky_material != null:
		_sky_material.sky_top_color = _base_sky_top
		_sky_material.sky_horizon_color = _base_sky_horizon
	if _sun != null:
		_sun.light_energy = float(_profile.get("sun_energy", 1.0))
	set_meta("motion_mode", str(_profile.get("motion_mode", "colour_breathe")))
	set_meta("environment_profile", _profile.duplicate(true))
