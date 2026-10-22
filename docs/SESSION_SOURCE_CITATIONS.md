# Session source citations

The timeline previously enumerated both an attribution's canonical URL and its revision_url. For Wikipedia this rendered two identical provider/license lines, adding a localized Source revision suffix to one. Presentation now prefers a supplied valid revision URL over its explicitly related canonical URL, removes exact duplicate URLs across sourceAttribution/sources, and omits the suffix. Provider and license remain visible. Distinct articles, previous sources and other providers remain independently linked. Invalid revisions fall back to the canonical URL; identical canonical/revision URLs still produce one citation. No source payload or backend provenance is mutated.

Regression: historySourceLinksShowOnePreciseWikipediaCitation exercises duplicated canonical/revision records, a separate Wikipedia article, MusicBrainz, invalid revision fallback and identical canonical/revision URLs. Preview40446 delivery and validation are recorded below.
