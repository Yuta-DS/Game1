# Chat session result screenshots

These images collect the results requested throughout this chat. The numbered screenshots include earlier iterations as well as the latest published result. Web screenshots 66–69 were captured after `./web rebuild`, `./web`, and `./web verify` on 18 October 2026, using the source that includes the Island One teleport position fix. Screenshots 61 and 62 show that fix in local and public Web views; screenshot 07 is an earlier scene capture. **Scene capture** images show specific views rendered by Godot for earlier fixes; they are useful visual evidence but are not proof that those exact camera views were reached through browser play.

Screenshots 75–79 were captured from the final local and published Web build on 19 October 2026. They show the start screen, Offline Guest hub, and player movement. The published export is static: account login needs a hosted HTTPS API, while Offline Guest works on the published site. The local Web launcher uses the local Flask API for account login.

## Current Web build

### Start, hub, and movement

The first three pairs are from an earlier native `./setup.sh run` window and the rebuilt Web game. The later native screenshots were saved from a fresh `./setup.sh run` on the latest source; they pair with the final source Web screenshots below. The native run reached the start screen, accepted Offline Guest, and moved the player with W.

![Native start screen](00_native_start.png)
![Web start screen](01_web_start.png)
![Native hub after Offline Guest](00_native_hub.png)
![Web hub after Offline Guest](02_web_hub.png)
![Native hub after moving](00_native_moving.png)
![Web hub after moving](03_web_moving.png)

Final source comparison, after the Island One teleport position fix:

![Latest native start screen](63_native_start_latest_source.jpg)
![Final source Web start screen](66_web_start_final_source.png)
![Latest native hub after Offline Guest](64_native_hub_latest_source.jpg)
![Final source Web hub after Offline Guest](67_web_hub_final_source.png)
![Latest native player moving](65_native_moving_latest_source.jpg)
![Final source Web player moving](68_web_moving_final_source.png)
![Final source Web view after movement](69_web_after_move_final_source.png)

Earlier rebuilt Web run, after the Island One glass-cylinder change:

![Earlier rebuilt Web start screen](47_web_start_after_latest_rebuild.png)
![Earlier rebuilt Web hub after Offline Guest](48_web_hub_after_latest_rebuild.png)
![Earlier rebuilt Web player moving](49_web_moving_after_latest_rebuild.png)
![Earlier rebuilt Web view after movement](50_web_after_move_latest_rebuild.png)

### Creator World: full ground, removed extra objects and bridge

The current browser ground audit walked the complete disk and checked the removed studio fixtures and bridge.

![Creator World in the current browser build](04_creator_web.png)
![Creator studio, aligned floor, and relocated table — scene capture](../session_result_views/09_creator_courtyard_ground_ramps.png)
![Creator studio, table, easels, and full ground — current rebuilt Web game](23_web_creator_studio_table_ground.png)
![Creator studio, table, easels, and full ground — current public Web game](24_public_web_creator_studio_table_ground.png)
![Creator studio and continuous tiled ground — latest rebuilt Web game](51_latest_web_creator_overview.png)
![Creator World after the final source rebuild and ground walk audit](71_web_creator_final_source.png)

### Heart Melody: full ground and removed lookout bridge

The current browser ground audit walked the island and checked that the lookout bridge and its collision are absent.

![Heart Melody in the current browser build](05_heart_web.png)
![Heart Melody in the deployed browser build](08_public_heart_web.png)
![Heart Melody teleport — scene capture](../session_result_views/08_heart_melody_teleport.png)
![Heart Melody ground and portal — latest rebuilt Web game](52_latest_web_heart_overview.png)
![Heart Melody after the final source rebuild and teleport audit](72_web_heart_final_source.png)

### World One: loaded story scene, movement, gates

The current browser story audit completed five quests, ten tasks, a save and reload, and the completion state. The quality audit completed the live object minigames.

![World One in the current browser build](06_world_one_web.png)
![World One after the final source rebuild, gate crossings, and Q teleports](70_web_world_one_final_source.png)
![World One on the published site after gate verification](09_public_world_one_web.png)
![World One after movement](07_world_one_moving_web.png)
![Island 2 Evidence Court ground — rebuilt Web game](13_web_island_2_ground.png)
![Island 3 Stormworks ground — rebuilt Web game](14_web_island_3_ground.png)
![Island 3 Stormworks ground — published Web game](15_public_web_island_3_ground.png)
![Island 2 Evidence Court — latest rebuilt Web game](54_latest_web_world_one_island_2.png)
![Island 3 Stormworks — latest rebuilt Web game](55_latest_web_world_one_island_3.png)
![Island One compass court meets ground — scene capture](../session_result_views/03_compass_ground_clear.png)
![Island One main gate and barrier — scene capture](../session_result_views/04_05_06_gate_aligned_and_clear.png)
![Gate moved toward the bridge — scene capture](../gate_bridge_alignment_review/01_bridge_side_portico.png)
![Gate fits its frame — scene capture](../gate_bridge_alignment_review/02_gate_fits_frame.png)
![Gate 2 with its matched frame — current Godot capture](../world_one_gate_frame_match_20261018/gate_2.png)
![Gate 3 on the Island 3 approach — current Godot capture](../world_one_gate_frame_match_20261018/gate_3.png)
![Gate 2 and its frame — rebuilt Web game](10_web_gate_2.png)
![Gate 3 and its frame — rebuilt Web game](11_web_gate_3.png)
![Gate 3 and its frame — published Web game](12_public_web_gate_3.png)
![Gate 3 and its fitted frame — latest published Web game](19_public_web_gate_3_current.png)
![Island 2 gate with a fitted ivory threshold and gold detail on the approach side — latest public Web game](30_public_web_gate_2_frame_matched.png)
![Island 3 gate and its frame with a continuous ivory threshold — latest public Web game](31_public_web_gate_3_frame_matched.png)
![Island 2 gate with its enamel leaves following the full frame — current public Web game](36_public_world_one_island_2_fitted_gate.png)
![Island 3 approach to the same fitted gate family — current public Web game](37_public_world_one_island_3_fitted_gate.png)
![World One gate after the public browser verified both crossings with the production player](38_public_world_one_production_player_gate_check.png)
![Island 2 gate leaves following the narrowed ivory frame — current public Web game](39_public_world_one_island_2_gate_arch_aligned.png)
![Island 3 gate leaves following the narrowed ivory frame — current public Web game](40_public_world_one_island_3_gate_arch_aligned.png)
![Island One ceremonial gate with solid ivory side bays replacing the exposed pink backdrop — current public Web game](41_public_island_1_ivory_gate_no_pink_frame.png)
![Island One gate with a single fitted ivory arch, brass rim, and finished lower doors — latest public Web game](42_public_island_one_single_ivory_arch.png)
![Island One gate with the glass cylinders replaced by recessed teal enamel in solid ivory piers — earlier public Web game](43_public_island_one_recessed_pier.png)
![Island One gate with the recessed piers and wall-mounted lanterns — latest public Web game](44_public_island_one_finished_pier.png)
![Island One gate with full-height ivory pillars connecting the crown to the ground — current public Web game](45_public_island_one_full_height_pillars.png)
![Island One gate with grounded teal glass cylinders beside the full-height ivory pillars — latest public Web game](46_public_island_one_glass_cylinders_ivory_pillars.png)
![Island 2 fitted gate — latest rebuilt Web game](56_latest_web_world_one_gate_2.png)
![Island 3 fitted gate — latest rebuilt Web game](57_latest_web_world_one_gate_3.png)
![Island One portal and bridge approach — earlier scene capture before position fix](../session_result_views/07_island_one_portal_bridge_alignment.png)
![Art Castle entrance to World One — rebuilt Web game](16_web_world_one_entrance_portal.png)
![Island One return portal centered in its arch — rebuilt Web game](17_web_world_one_island_1_return_portal.png)
![Island Three return portal centered in its arch — rebuilt Web game](18_web_world_one_island_3_return_portal.png)
![World One entrance after all three portal destinations were checked — current rebuilt Web game](21_web_world_one_portal_trip_verified.png)
![World One entrance after all three portal destinations were checked — current public Web game](22_public_web_world_one_portal_trip_verified.png)
![Island One portal after three browser keyboard Q trips — rebuilt Web game](34_web_world_one_browser_q_portals.png)
![Island One portal after three browser keyboard Q trips — current public Web game](35_public_web_world_one_browser_q_portals.png)
![Art Castle entrance portal — latest rebuilt Web game](58_latest_web_world_one_source_portal.png)
![Island One return portal — earlier rebuilt Web game](59_latest_web_world_one_island_one_return_portal.png)
![Island Three return portal — latest rebuilt Web game](60_latest_web_world_one_island_three_return_portal.png)
![Island One return portal clear of the foreground pillar — rebuilt Web game after position fix](61_latest_web_world_one_island_one_portal_repositioned.png)
![Island One return portal clear of the foreground pillar — published Web game after position fix](62_public_world_one_island_one_portal_repositioned.png)

### Other removal requests

![Hub view after the specified gray object removal — scene capture](../session_result_views/01_hub_rock_removed.png)
![Former gray rock location beside the castle stair — current rebuilt Web game](32_web_hub_gray_object_removed.png)
![Former gray rock location beside the castle stair — current public Web game](33_public_web_hub_gray_object_removed.png)
![Hub rock removal area after the final source rebuild](74_web_hub_rock_removed_final_source.png)
![Gallery entrance after hanging light removal — scene capture](../session_result_views/02_gallery_no_hanging_lights.png)
![Gallery after entering an artwork and returning — rebuilt Web game](20_web_gallery_after_artwork_return.png)
![Gallery entrance with the hanging chandeliers removed — rebuilt Web game](25_web_gallery_entrance_no_chandeliers.png)
![Gallery entrance with the hanging chandeliers removed — current public Web game](27_public_web_gallery_entrance_clean.png)
![Gallery artwork area after entering and returning — latest rebuilt Web game](53_latest_web_gallery_artwork.png)
![Gallery after the final source rebuild, artwork entry and return](73_web_gallery_final_source.png)

## What the checks show

- The [final source `./web rebuild` log](web_rebuild_final_source.log) exported the source containing the Island One teleport position fix. [`./web` after that rebuild](web_run_final_source.log) confirmed its prerequisites, backend, and local server. The [final source browser verification](web_verify_final_source.log) reached Offline Guest and movement with no failed requests or fatal resource errors.
- [`./setup.sh run`](native_setup_run_startup.log) launched the Mono desktop game; it was run again against the final checked-out source and reached the start screen, Offline Guest hub, and movement. Native screenshots 63–65 are from that fresh run.
- The [Web export completeness check](web_export_completeness_final_source.log) found the startup, gallery, Galaxy, and Creator scenes, plus required data and resources. The [Web feature parity configuration check](web_feature_parity_final_source.log) passed for 32 required resources. The [exported pack smoke check](web_pack_smoke_final_source_absolute.log) opened the gallery at World One with six islands and 15 quests, proving those runtime resources load from the final PCK.
- Final source browser audits passed for [World One](world_one_final_source_browser_audit.log), [Creator](creator_final_source_browser_audit.log), [Heart Melody](heart_final_source_browser_audit.log), [Gallery](gallery_final_source_browser_audit.log), and the [hub rock removal](hub_rock_final_source_browser_audit.log). The [World One report](world_one_final_source_browser_console.log) records three Q-teleport trips, two production-player gate crossings, and 216 ground collision samples. The [Creator report](creator_final_source_browser_console.log) records a player walk and 96 supported ground points. The [Heart report](heart_final_source_browser_console.log) records a player walk and successful teleport. The [Gallery report](gallery_final_source_browser_console.log) records 12 artwork frames, artwork entry and return, and zero chandeliers. The [hub report](hub_rock_final_source_browser_console.log) records no remaining gray rock items at the requested location. Each browser run reached `PLAYABLE` with zero failed requests and zero fatal resource errors.
- After the earlier glass-cylinder rebuild, browser audits rendered [Creator](latest_creator_web_console.log), [Heart Melody](latest_heart_web_console.log), [Gallery](latest_gallery_web_console.log), [Island 2](latest_world_one_island_2_web_console.log), [Island 3](latest_world_one_island_3_web_console.log), [Gate 2](latest_world_one_gate_2_web_console.log), [Gate 3](latest_world_one_gate_3_web_console.log), and the [source](latest_world_one_source_portal_web_console.log), [Island One return](latest_world_one_island_one_return_portal_web_console.log), and [Island Three return](latest_world_one_island_three_return_portal_web_console.log) portals. The successful runs reported playable scenes, no failed requests, and no fatal resource errors. The Gallery audit entered an artwork and returned; the Heart audit reported a successful teleport; the World One quality reports verified two gate crossings and three portal trips. A first Gate 3 attempt had three failed portal Q assertions; its [console log](latest_world_one_gate_3_first_attempt_console.log) is retained. The immediate retry passed, so this sequence does not establish that the Q path is consistently reliable.
- The rebuilt Web game passed the [gallery artwork interaction audit](gallery_artwork_web_audit.log): all 12 artwork frames appeared, Space entered an artwork world, its Gallery exit was visible, and the player returned to the gallery. The [console report](gallery_artwork_web_console.log) recorded `ok: true`.
- The [current public gallery audit](gallery_entrance_clean_public_audit.log) rendered the entrance without chandeliers, entered and exited an artwork, and reported zero failed requests. Its [console report](gallery_entrance_clean_public_console.log) recorded `chandeliers: 0` and `ok: true`. The public artwork world now selects its existing on-device reconstruction when the configured localhost AI backend cannot be reached from the visitor's browser; [native creation-world](creation_world_backend_native_test.log) and [guest Frame 09](guest_frame09_backend_native_test.log) checks passed.
- Browser smoke checks passed for the current [hub](local_web_verify.log), [Creator ground](creator_web_audit.log), [Heart ground and teleport](heart_web_audit.log), [World One quality](world_one_quality_audit.log), and [World One story](world_one_story_audit.log). Each reported no fatal resource errors and no failed requests. The Heart check reported `teleported: true`; the World One quality check reported `gates_verified: 2` after inspecting both frames and cycling their gate leaves.
- Focused native checks passed for [Creator walking](creator_walk_test.log), [Heart walking](heart_walk_test.log), [Heart teleport](heart_teleport_test.log), [World One compass collision and lighting](world_one_compass_lighting_test.log), gate alignment, and Island 3 traversal.
- Native checks also passed for [Island One teleport alignment](world_one_arrival_angle_test.log), [World One Galaxy integration](galaxy_teleport_test.log), and [World One ground contact](world_one_ground_contact_test.log).
- The [full native World One walk](world_one_all_quest_native_walk.log) passed after following the actual clear aisles around the Island One instruments, Island Three planted bed, and inactive wisp. It drove the production player capsule from spawn through all 15 quest operators and both bridges, then returned across both bridges to spawn. The current Web quality checks sample the same ground and gate collisions but do not yet replay that whole route in the browser.
- The [live World One portal test](world_one_live_portals_native_test.log) passed native source, Island One, and Island Three return checks. The [rebuilt browser game](world_one_source_portal_web_audit.log) rendered the three active portals with the shared design; [Island One](world_one_entry_portal_web_audit.log) and [Island Three](world_one_return_portal_web_audit.log) portal views loaded with no failed requests or fatal resource errors.
- The earlier [local browser check](world_one_portal_trips_local_audit.log) and [public browser check](world_one_portal_trips_public_audit.log) reported [three successful direct portal calls](world_one_portal_trips_public_console.log). The new [native key test](world_one_browser_q_native_test.log), [local browser check](world_one_browser_q_local_audit.log), and [public browser check](world_one_browser_q_public_audit.log) drove the production player into each portal trigger and pressed Q through the browser. The [public console report](world_one_browser_q_public_console.log) confirms all three correct landings and `ok: true`. The audit positioned the player inside each trigger; walking the approach to each portal with normal controls remains unverified.
- The [angled Creator view](creator_studio_view_public_audit.log) passed in the public browser, showing the relocated table, six easels, and common ground finish. Its [audit report](creator_studio_view_public_console.log) confirms 96 supported rim points, a player walk, the table on the studio east edge, and all four legs level with the studio floor. The [native bridge-to-studio walk](creator_studio_walk_native.log) also passed.
- Gate 2 and Gate 3 were [captured in the rebuilt Web game](gate_2_web_audit.log) from their approaches; the [Gate 3 Web capture](gate_3_web_audit.log) shows its floor and fitted arch. A [physics floor probe](gate_floor_probe.log) found walkable collision at and around both gate thresholds. The [native gate traversal check](gate_traversal_native.log) confirms that both closed gates stop a character body and both open gates let it cross.
- The latest [native gate family check](gate_family_final_native_test.log) passed with both leaves fitted to their sills, rear gold filigree, and threshold collision. The [public Island 2](gate_2_public_final_audit.log) and [public Island 3](gate_3_public_final_audit.log) browser checks loaded the new gate views; the World One quality report recorded `gates_verified: 2`, `gates_traversed: 2`, and `ok: true` with no failed requests or fatal resource errors.
- The [updated native gate family check](gate_family_fitted_native_test.log) passed with a full-width arched enamel backing and finished threshold on both faces. The current [public Island 2](world_one_island_2_fitted_gate_public.log) and [public Island 3](world_one_island_3_fitted_gate_public.log) browser runs both reported `PLAYABLE`, no failed requests, and no fatal resource errors.
- The [production-player gate check](world_one_production_player_gate_native_test.log) passed natively. The [rebuilt local browser](world_one_production_player_gate_local_audit.log) and [current public browser](world_one_production_player_gate_public_audit.log) both reported `gate_traveler: production_player`, `gates_traversed: 2`, and `ok: true`; the [public console](world_one_production_player_gate_public_console.log) also records all three browser Q portal trips.
- The [local](hub_rock_local_audit.log) and [public](hub_rock_public_audit.log) hub checks captured the former gray rock area. The [public console report](hub_rock_public_console.log) recorded both removed rock scatter items absent; the [native hub entrance check](hub_rock_native_test.log) passed.
- The Island One gate with restored glass cylinders and full-height ivory pillars was deployed as `dpl_HmUew9DngawWNjE1gud6zY6xLhGo`; its [deployment log](island_one_glass_cylinders_deploy.log) confirms that the public pack manifest matches the local export. The public browser audit reported `PLAYABLE`, zero failed requests, and zero fatal resource errors. The [console report](island_one_glass_cylinders_public_console.log) confirmed two production-player gate crossings, three teleport trips, and `ok: true`. The focused native gate family and Island One hinge checks also passed. Earlier public hub, gallery, Creator, and Heart checks covered the other screenshots and interactions.
- The Island One return portal and its threshold architecture were moved together six metres toward the paved approach. The current production deployment is `dpl_BY46zvEsrYDdSMxWkL9jZ8rNCqeJ`; the [deployment log](island_one_portal_repositioned_deploy.log) confirms the public pack manifest matches the local export. The [production browser report](island_one_portal_repositioned_public_console.log) records two gate crossings, three portal trips, `ok: true`, and no fatal resource errors. The latest native arrival, camera, gate blueprint, and Q-interaction checks passed.

Screenshots show appearance. The linked browser and native test logs cover collision, walking, teleport behavior, and save behavior. Gate physics traversal now uses the production player; walking through each gate with normal keyboard controls has not been directly captured. This collection does not establish complete feature parity between native `./setup.sh run` and Web: native C# and local model features have different Web implementations and were outside these visual checks. The public artwork world uses an on-device reconstruction because the configured AI backend is local to the development machine.

See the [request-by-request evidence audit](REQUEST_COVERAGE.md) for what these captures prove and what still needs a direct native/Web comparison.
