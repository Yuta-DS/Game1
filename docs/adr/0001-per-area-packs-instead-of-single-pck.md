# The web build ships per-area Packs instead of one pck

The web export was a single ~750 MB `index.pck` that had to download in full before the game started, taking minutes. We split content into a Core pack plus one Pack per area (Hub, Art Castle, each Kingdom, Crown of Life story, and Shared packs), fetched on demand or prefetched once the Hub is playable. Parts (8 MB slices) remain only for host file-size limits and resumable, bounded-parallel fetching; they are not a unit of content. Rejected: keeping one pck and only parallelising its Parts, which cannot reduce the first load.
