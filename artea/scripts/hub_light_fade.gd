extends Node

# Shared distance-fade tuning for hub-world lights.
#
# Under the non-clustered Compatibility renderer, overlapping OmniLight3D
# ranges stack in one fragment's lighting loop and tank performance. Every
# runtime-built hub light disables shadows and fades out with distance for
# this reason; the defaults below (45.0 / 15.0) are what nearly all of them
# use, with the tuning point provided so far-viewed lights (e.g. sky isles)
# can extend the range.


static func apply(light: Light3D, begin: float = 45.0, length: float = 15.0) -> void:
	light.distance_fade_enabled = true
	light.distance_fade_begin = begin
	light.distance_fade_length = length
