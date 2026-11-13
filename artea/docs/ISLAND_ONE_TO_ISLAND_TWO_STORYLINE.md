# Mind Spark — Island One to Island Two Storyline

Status: implemented reference for World 1. This preserves the intended story, gameplay meaning, quest order, and visible state changes.

## Story promise

Island One teaches the player to notice a difficult thought and discover the useful question inside it. Its reward is the **Echo Seed**. Island Two continues that lesson: test the thought with evidence, rebuild it as a fair memory, and form a hope that the evidence can honestly support.

The combined learning sentence is:

> I can notice a thought, understand what supports it, and choose one hopeful next step.

## Transition

After the Signal Observatory and Echo Garden are complete, the Thought Spark relay carries the Echo Seed through the golden threshold. The crossing reveals three layers already inside the seed:

1. **Event** — what the practice log actually records.
2. **Prediction** — what fear says the event will always mean.
3. **Choice** — the next response still available to the player.

The receiver on Island Two changes from dormant, to invited, to received. Mother Guardian explains that a feeling is meaningful even when its prediction is not established as fact.

## Island Two — Observatory of Understanding

### Quest A: Read the Broken Pattern

1. **Evidence Laboratory — READ**
   - The scanner reveals three practice-log fragments one at a time.
   - The player classifies each as recorded fact or unsupported prediction.
   - Wrong choices provide a reasoning hint and preserve progress.

2. **Memory Atelier — WEAVE**
   - Reconstruct the response as `NOTICE → NAME → CHOOSE`.
   - Notice: one attempt was difficult.
   - Name: “I am predicting that I will always fail.”
   - Choose: pause, then try one smaller informed step.
   - Undo and reset are safe; verified evidence is never lost.

3. **Archive Engine — VERIFY**
   - The restored Memory Spark powers the engine through the existing Spark Socket.
   - The player inserts both verified event plates.
   - The Evidence Aether Bus fills progressively and the Memory Gate opens only after all inputs are present.

### Quest B: Build the Hope Path

4. **Perspective Laboratory — REFRAME**
   - Close view: a single attempt was difficult.
   - Pattern view: a pause was followed by another attempt.
   - Forward view: the next step can use what the attempts taught.
   - The three views change interpretation without changing the recorded event.

5. **Truth Foundry — BUILD**
   - Fear: “One difficult attempt proves I will always fail.”
   - Empty fantasy: “If I hope enough, every attempt will be easy.”
   - Grounded hope: “One difficult attempt can teach me how to try the next step.”
   - Only grounded hope is supported by the repaired memory. Choosing it materialises the path.

6. **Certainty Guard — CARRY**
   - The Stalker and Sentinel challenge movement, timing, and attention.
   - This tests carrying the new truth under pressure; it never tests the player's worth.
   - The Conservatory Understanding Shrine’s hope crystal awakens and the onward route becomes meaningful.

## Persistent story states

| State | World feedback |
|---|---|
| `dormant` | Receiver and research routes rest. |
| `invited` | Golden receiver halo guides the player from Island One. |
| `received` | The Echo Seed appears; the first archive reading awakens. |
| `evidence_sorted` | Three evidence-bus readings show verified fragments. |
| `memory_woven` | Five readings show the repaired memory carrying power. |
| `archive_open` | All seven archive readings are active and the gate is open. |
| `hope_reframed` | The first three Hope conduit segments illuminate. |
| `truth_materialised` | The full Hope conduit carries grounded hope forward. |
| `guardian_freed` | The Guardian reward crystal appears. |

## Interaction and accessibility rules

- Every required station is locked until the preceding reasoning step is complete.
- No timer is used for evidence, memory, perspective, or truth decisions.
- Wrong interpretations explain the mismatch instead of removing rewards.
- Station panels stop character movement while open and restore it on exit.
- The Focus Bell remains optional help; identity reflection remains private and never gates success.
- Save restoration derives the visible story phase from completed task IDs, preventing visuals and interaction access from drifting apart.
