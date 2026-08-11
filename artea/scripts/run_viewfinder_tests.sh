#!/bin/bash
# Runs every Lens of Seeing / world-cutting self-check, headless.
#
#   bash artea/scripts/run_viewfinder_tests.sh
#
# See docs/VIEWFINDER_WORLD_CUTTING.md §6. Exits non-zero if any test fails.
GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"

TESTS=(
  test_mesh_cutter
  test_cutter_cap_loops
  test_frustum_cutter
  test_lens_collision
  test_viewfinder_lens
  test_lens_safety
  test_lens_photo_card
  test_lens_controller
  test_lens_journey
  test_lens_persistence
  test_hub_lens
)

failures=0
for test in "${TESTS[@]}"; do
  echo "=== $test ==="
	log_file="$PROJECT/.godot/${test}.log"
	stdout_file="$PROJECT/.godot/${test}.stdout.log"
	if [ "$test" = "test_hub_lens" ]; then
		# Loading the complete hub also loads native Terrain3D/Firebase add-ons.
		# On macOS those add-ons can keep the process alive after SceneTree.quit()
		# even though the test has completed. Watch for the test's terminal marker,
		# then stop only the Godot process started here. This keeps CI bounded while
		# still failing on assertion/script errors or an early process exit.
		"$GODOT" --headless --log-file "$log_file" --path "$PROJECT" \
			--script "res://scripts/$test.gd" --quit-after 1800 \
			>"$stdout_file" 2>&1 &
		test_pid=$!
		status=124
		for _ in $(seq 1 120); do
			if grep -q 'hub lens: all checks passed' "$stdout_file"; then
				status=0
				break
			fi
			if ! kill -0 "$test_pid" 2>/dev/null; then
				wait "$test_pid"
				status=$?
				break
			fi
			sleep 1
		done
		if kill -0 "$test_pid" 2>/dev/null; then
			kill "$test_pid" 2>/dev/null || true
			wait "$test_pid" 2>/dev/null || true
		fi
	else
		"$GODOT" --headless --log-file "$log_file" --path "$PROJECT" \
			--script "res://scripts/$test.gd" --quit-after 1800 \
			>"$stdout_file" 2>&1
		status=$?
	fi
	cat "$stdout_file"
	if [ "$status" -ne 0 ] || grep -Eq \
		'SCRIPT ERROR:|Parse Error:|Failed to load script' "$stdout_file"; then
    echo "!!! FAILED: $test"
    failures=$((failures + 1))
  fi
done

echo
if [ "$failures" -eq 0 ]; then
  echo "all viewfinder tests passed"
else
  echo "$failures test script(s) failed"
fi
exit "$failures"
