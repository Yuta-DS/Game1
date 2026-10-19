# Mind Spark Island One — Quest Implementation Plan

## Scope and stop condition

This slice covers only Island One of the three-island Mind Spark world:

1. Quest 1 — The Signal Observatory
2. Quest 2 — The Echo Garden (catalog id remains `quest.echo_forest`)

The slice is complete when both quests can be discovered, solved in order,
restored from save data, and visibly power the existing golden heavenly gate.
Island Two and Island Three content are explicitly out of scope.

## Shared foundation checklist

- [x] One camera-relative player controller remains the movement authority.
- [x] Mandatory stations sit on broad, walkable Island One surfaces.
- [x] One contextual interaction input operates nearby physical controls.
- [x] Every control exposes an authored purpose and interaction id.
- [x] Wrong attempts give immediate, non-punitive information.
- [x] Quest state persists through the existing object-state store.
- [x] Quest 2 cannot be operated before Quest 1 awards the Signal Prism.
- [x] The inter-island gate cannot open before both Island One quests finish.
- [x] Completion emits reusable quest ids and physical reward ids.
- [x] Existing recovery volumes and accessible routes remain unchanged.

## Quest 1 — Signal Observatory

### Player promise

The player learns to notice an authored difficult thought, examine its signal,
and choose a grounded direction without treating the thought as identity.

### Required environment

- [x] Monumental three-ring observatory and readable target instrument.
- [x] Three detailed light-prism stations with live physical beam feedback.
- [x] Evidence-analysis console that compares without auto-solving.
- [x] Twin pressure regulators for noticing and making space.
- [x] Coupled constellation selectors that require planning.
- [x] Visible authored thought; no private free-text collection.
- [x] Signal Prism reward chamber integrated into the observatory heart.

### Required gameplay sequence

1. Route Thought, Feeling, and Choice through three different instruments.
2. Analyze the resulting composition.
3. Balance the two signal pressures.
4. Solve the coupled Notice, Understand, Choose rings.
5. Verify the route and receive the Signal Prism.

### Acceptance checks

- [x] At least three valid creative harmony profiles are accepted.
- [x] Repeated seeds produce explanatory evidence, not failure damage.
- [x] Ring inputs visibly move two related rings.
- [x] Quest completion persists independently from Quest 2.
- [x] Completion unlocks the Echo Garden but not the inter-island gate.

## Quest 2 — Echo Garden

### Player promise

The player learns that an alarm can contain a protective question while still
exaggerating certainty. Uncertainty is treated as a valid category.

### Required environment

- [x] Existing Wisdom Tree and phyllotaxis garden remain the visual anchor.
- [x] Signal Prism socket physically connects Quest 1 to Quest 2.
- [x] Three signal-orb listening branches.
- [x] Three detailed classification instruments: Fact, Possibility, Unsure.
- [x] Protective-question selector at the mechanical root chamber.
- [x] Caution Beacon and Echo Seed reward vessel.
- [x] Roots, light conduits, and canopy feedback show cause and effect.

### Required gameplay sequence

1. Install the Signal Prism and collect three slow signal echoes.
2. Classify each authored echo as Fact, Possibility, or Unsure.
3. Translate the catastrophic warning into a useful protective question.
4. Test the complete interpretation at the Caution Beacon.
5. Receive the Echo Seed and power the golden heavenly gate.

### Acceptance checks

- [x] Echo controls reject use until the Signal Prism exists.
- [x] Collection is untimed and cannot be lost.
- [x] Every classification remains visible while reasoning.
- [x] An incomplete or incorrect interpretation reports how many relations fit.
- [x] Completion persists and restores the powered tree, reward, and gate.

## Verification checklist

- [x] Focused Quest 1 state and persistence test passes.
- [x] Focused Quest 2 dependency, reasoning, and persistence test passes.
- [x] Existing Island One visual-quality tests pass.
- [x] Existing three-island layout and route-clearance tests pass.
- [x] Non-Mono Web export succeeds.
- [x] Local WebGL2 build reaches the start screen and Offline Guest world.
- [ ] Production deployment reaches READY.
- [ ] Public WebGL2 build reaches the start screen and Island One flow.

## Detailed implementation pass

### Objective-state foundation

- [x] Expose one canonical current quest id, task id, and player objective.
- [x] Derive task state from saved puzzle facts instead of maintaining a second counter.
- [x] Show the same objective in the world HUD and nearby physical instrument.
- [x] Keep completed observatory controls readable while directing the player forward.

### Movement and wayfinding

- [x] Add a continuous, low-profile floor-light route from observatory to garden.
- [x] Reveal only the route segment relevant to the current reasoning step.
- [x] Keep guidance lights below character and camera height.
- [x] Preserve a broad no-jump route between all mandatory controls.
- [x] Make the support marker target the next physical station.

### Physical feedback

- [x] Display each authored echo beside its classification instrument.
- [x] Display the currently selected Fact, Possibility, or Unsure category in-world.
- [x] Display the currently selected protective question at the root dial.
- [x] Move visible energy packets through root conduits as the garden awakens.
- [x] Change tree, beacon, prism socket, and reward states at meaningful milestones.
- [x] Give the final Echo Seed a visible emergence ceremony.

### Detailed acceptance

- [x] Quest 1 objective advances through route, analyze, balance, align, and form.
- [x] Quest 2 objective advances through collect, classify, question, and verify.
- [x] Save/reload restores the exact derived objective and environmental state.
- [x] Incorrect verification preserves every player choice and points to revision.
- [x] Focused objective/feedback test passes before the wider regression suite.
