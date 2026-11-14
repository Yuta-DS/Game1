# Milo Wisdom System — canonical research synthesis

Research date: 31 August 2026  
Scope: Bible corpus rights and formats; religion/science/philosophy boundaries;
child-facing conversational safety; Godot Web constraints; repository fit.

## Decision

Do not place “all the Bible” in a gigantic system prompt and do not begin with
vector RAG. Bundle the public-domain 66-book World English Bible Protestant
edition (WEBP) as exact per-book JSON, retrieve references and curated themes
deterministically, and give the optional desktop model only a small grounded
context packet. The Web build uses the same retrieval and authored synthesis
without a native model or network service.

This is a retrieval system in the ordinary software sense, but not embedding
RAG. It is smaller, auditable, deterministic, private, and suitable for the
current bounded 280-character child-facing chat. Add semantic embeddings only
if later evaluation demonstrates that reference and keyword retrieval cannot
meet real player queries.

## Evidence synthesis

### Scripture corpus

The official WEB publisher states that the World English Bible is public
domain and may be copied, published, distributed, quoted, and used freely,
including commercially. It warns that altered text should not continue to be
presented as the World English Bible. The developer page supplies VPL, USFM,
USFX, OSIS, and other formats. The selected `engwebp` edition contains the 66
books of the Old and New Testaments and uses US spelling.

Implementation consequence: preserve exact verse wording, identify it as
WEBP, give book/chapter/verse, record the official archive URL and checksum,
and keep Milo’s commentary visibly separate from the quotation.

Sources:

- [Official WEB FAQ](https://ebible.org/eng-web/webfaq.htm)
- [Official WEB copyright statement](https://ebible.org/eng-web-c/copyright.htm)
- [Official 66-book WEBP edition](https://ebible.org/engwebp/)
- [Official WEBP developer formats](https://ebible.org/find/details.php?all=1&id=engwebp)
- [USFM documentation](https://ubsicap.github.io/usfm/)

### Science, philosophy, and theology

The National Academies describes science and religion as different ways of
understanding and states that acceptance of evolution can be compatible with
religious faith, while also making clear that creationist claims are not a
scientific substitute for evidence-based evolution. The Stanford Encyclopedia
of Philosophy describes conflict, independence, dialogue, and integration as
different relationship models; it cautions that total integration can fail to
do justice to both fields. Philosophy of religion evaluates religious and
secular worldviews through reasoning and evidence but is not identical to
experimental science.

Implementation consequence: Milo may place the domains “in dialogue,” but
must not promise that every biblical interpretation, philosophical position,
and scientific conclusion agrees. Each claim is labelled:

- Scripture/theology: text, tradition, and faith interpretation.
- Science: empirical evidence, testable models, consensus, and uncertainty.
- Philosophy: reasons, concepts, assumptions, objections, and implications.
- Artéa: fictional world material.

Sources:

- [National Academies, *Science, Evolution, and Creationism*](https://www.nationalacademies.org/publications/11876?sort=asc)
- [Stanford Encyclopedia of Philosophy, “Religion and Science”](https://plato.stanford.edu/entries/religion-science/)
- [Stanford Encyclopedia of Philosophy, “Philosophy of Religion”](https://plato.stanford.edu/entries/philosophy-religion/)
- [Smithsonian science-and-religion primer](https://humanorigins.si.edu/about/broader-social-impacts-committee/science-religion-evolution-and-creationism-primer)

### Child-facing safety and transparency

UNICEF’s guidance emphasises safety, privacy, transparency, explainability,
and children’s best interests. Its AI companion guidance identifies heightened
relational risks and recommends clear disclosure, strong privacy defaults,
avoiding dependency or emotional primacy, not presenting a bot as a therapist
or trusted confidant, and maintaining crisis referral protocols.

Implementation consequence: Milo explicitly identifies as fictional; does not
impersonate God, a human, clergy, or a therapist; does not claim exclusive
closeness; keeps messages local and unsaved; and preserves the authored urgent
support route before any knowledge response.

Sources:

- [UNICEF, Guidance on AI and Children 3.0](https://www.unicef.org/innocenti/reports/policy-guidance-ai-children)
- [UNICEF, *When AI Becomes a Friend*](https://www.unicef.org/documents/when-ai-becomes-friend-child-rights-risks)
- [UNICEF business recommendations for AI companions](https://www.unicef.org/media/181136/file/UNICEF-When-AI-becomes-friend-Business-recommendations-2026.pdf)

### Godot Web and privacy architecture

Godot’s official documentation says Web exports run through WebAssembly and
WebGL 2.0, Godot 4 C# projects cannot currently export to Web, and browser HTTP
is constrained by same-origin and browser security. The repository’s
NobodyWho/Gemma extension is native-only and already excluded from Web.

Implementation consequence: use GDScript plus `res://` JSON for the common
runtime. Keep the Web response deterministic and offline. A server-hosted LLM
could broaden arbitrary off-topic answers, but would transmit child chat and
would require a new privacy, consent, moderation, retention, rate-limiting, and
operational-security design. That expansion is not justified for this release.

Source: [Godot Web export documentation](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html)

## Implemented architecture

1. Existing `MiloReflectionEngine` runs first, so urgent language always routes
   to real-world help.
2. `MiloWisdomEngine` parses explicit references and detects explicit
   Bible/science/philosophy questions. Ordinary emotional messages remain in
   the established reflection path.
3. The manifest maps book aliases to 66 lazy-loaded JSON files. At most five
   verses are quoted per response; invalid references are never guessed.
4. `milo_wisdom_seed.json` supplies Milo’s identity, boundaries, topic cues,
   controlled opener variants, and distinct domain lenses.
5. On Web/headless, the grounded authored answer is displayed directly.
6. On supported desktop builds, the same grounded material is wrapped around
   the player message and sent to the included local Gemma model. Empty or
   failed generation falls back to the grounded authored answer.
7. No message persistence, remote request, API key, or embedding database is
   introduced.

## Genuine limitations

- The deterministic Web build answers exact references and the seeded topics;
  it is not a general-purpose internet oracle.
- WEBP is one 66-book Protestant edition. Catholic and Orthodox canons and
  translation-specific perspectives must be added as separately named corpora.
- The thematic bridges are authored summaries, not theological consensus.
- A local 2B model may still produce imperfect prose. Exact scripture lookup,
  domain labels, length bounds, and fallback reduce risk but do not eliminate
  the need for playtesting and content review.

## Claim-to-source ledger

| Claim | Support | Status |
|---|---|---|
| WEB/WEBP can be bundled and used commercially | Official WEB FAQ and copyright page | Verified |
| Exact wording should be preserved when named WEB | Official copyright caveat | Verified |
| `engwebp` is the 66-book Protestant edition | Official edition/developer pages | Verified |
| Science and religion are not reducible to one method | National Academies; SEP | Verified |
| Product should not force universal harmony | SEP relationship models; synthesis | Verified + design inference |
| Child companion needs disclosure, privacy, non-dependency, crisis routing | UNICEF guidance | Verified |
| GDScript/local JSON is the common Web-compatible path | Godot docs + repository inspection | Verified + repository inference |
| Vector RAG is unnecessary at current scope | Corpus size/query scope/architecture comparison | Design inference, testable later |
