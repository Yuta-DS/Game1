# Milo Wisdom System

Milo now has a private, Web-compatible foundation for Bible, philosophy, and
science conversations without placing the entire Bible in a prompt.

## What the player experiences

- “John 3:16” returns the exact public-domain WEBP text and reference.
- “What does the Bible say about hope?” selects a verified themed passage.
- A mixed question labels `SCRIPTURE`, `SCIENCE`, `PHILOSOPHY`, and
  `IN DIALOGUE`, so the player can see which kind of claim is being made.
- Milo varies a small set of natural openings but does not become randomly
  inconsistent or repeat the same opener immediately.
- Invalid references are acknowledged rather than invented.
- Ordinary emotional check-ins retain the existing five-part Milo reflection.
- Urgent safety language still bypasses knowledge dialogue and shows real-world
  support.

## Why this is not a gigantic prompt or vector RAG

A huge prompt would waste context, make exact citation difficult, and perform
poorly with the bundled 2B local model. Vector RAG would add an index, chunking,
embedding runtime, retrieval evaluation, and more Web payload before the game
has demonstrated a need for semantic search.

The implemented design uses exact reference retrieval plus a compact topic
seed. It is deterministic, testable, offline, and can later be upgraded behind
the same `MiloWisdomEngine` interface.

## Content and reasoning rules

The selected scripture corpus is the 66-book World English Bible Protestant
edition. The publisher designates the WEB as public domain and provides
developer formats ([official copyright](https://ebible.org/eng-web-c/copyright.htm),
[WEBP developer files](https://ebible.org/find/details.php?all=1&id=engwebp)).

Milo does not claim that all religion, philosophy, and science agree. That
would be misleading. The system follows the more defensible “dialogue with
boundaries” model described by the
[Stanford Encyclopedia of Philosophy](https://plato.stanford.edu/entries/religion-science/)
and distinguishes empirical science from theological interpretation, consistent
with the [National Academies](https://www.nationalacademies.org/publications/11876?sort=asc).

Milo is disclosed as a fictional game character, never impersonates God or a
therapist, does not encourage exclusivity, and keeps typed chat local and
unsaved. These choices align with
[UNICEF’s child-centred AI guidance](https://www.unicef.org/innocenti/reports/policy-guidance-ai-children)
and its [AI companion risk recommendations](https://www.unicef.org/documents/when-ai-becomes-friend-child-rights-risks).

## Runtime flow

```text
player message
  → urgent-safety check
  → exact Bible reference / explicit domain-topic retrieval
  → Web: authored grounded response
  → Desktop: grounded packet → local Gemma → authored fallback on failure
```

All common logic is GDScript and local JSON, matching Godot’s
[Web export constraints](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html).
No remote chat API, database, message log, or API key was added.

## Extending it

Add themes to `data/milo_wisdom_seed.json`. Rebuild the exact corpus with:

```bash
python3 tools/build_milo_scripture_index.py
```

Additional canons or translations must be separate, clearly named corpora with
their own rights and provenance. Do not silently mix wording across editions.

The full research synthesis and claim ledger are in
`artifacts/milo_wisdom_research/report-source.md`.
