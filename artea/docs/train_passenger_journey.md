# Passenger station journeys

Press **T** near the train to sit on the closest of the six seats in the two
passenger coaches. The fox uses the existing seated passenger pose and stays
attached to its cushion while the train automatically follows the Crown Line.
Manual driving on **R** remains separate.

At the next station, the train stops and waits indefinitely for a choice:

- **Get off here** places the player on the raised boarding lane beside their
  coach, on the side connected to the world's entrance. Walking, standing and
  normal camera input return.
- **Next station** keeps the same seat and starts the next journey. Every stop
  asks again, including the Creator's Light → Gallery loop.

The journey indicator names the next stop while moving. The arrival card names
the current station and next destination. Mouse clicks and Tab/Enter work;
camera looking/view shortcuts are suspended while the card is open. The previous
cursor-release preference is restored afterward. There is no departure timer.

Story gates remain enforced. A locked destination disables the next-stop button
and explains the required treasure, while Get off here remains available. Q/R
cannot eject or switch a passenger while moving. Repeated continue requests
cannot create duplicate journey tweens. Removing the railway releases the player
and any active station prompt.

Implementation: `scripts/art_castle_story_railway.gd` owns journey state, tween
travel and platform exit coordinates; `scripts/train_passenger_journey_ui.gd`
owns the indicator/card; `scripts/CameraFollow.gd` owns temporary input release.
No train geometry, driver controls, passenger seat positions, story progression,
network protocol or production settings were changed.

Focused regression: `scripts/test_train_passenger_journey.gd` loads the real
gallery/fox and delivers viewport input. It covers both coaches, all four stops,
repeat trips, mouse/keyboard choices, story locks, platform collision and player
recovery. Run with native Godot and `-- --capture` to also save
`artifacts/train_passenger_arrival.png`.

