# Presence and persona on the Session start card

Owner requests both settings on the existing welcome/mood/start card.
Added Presence and Persona rows using the existing native equal-width selector,
localized titles/options and the confirmed selected-value label. Rows observe the
stable Profile settings editor projection, ignoring unrelated clock refreshes.
Choices are filtered by backend allowed_values and selected from Profile defaults.
Writes use the existing changeProfileDJSettings path, with its readback, revision,
owner, conflict and uncertain-outcome fences. No durable local settings introduced.

No optimistic selection and no editable unnegotiated/demo defaults. Server-required
full review opens the existing six-field editor rather than submitting a partial
migration. Loading/saving/conflict/uncertain/unavailable copy uses existing five-
language resources. Start is disabled during saving/uncertain outcomes, avoiding
starting against the previously confirmed selection.

Native signed iOS40307 build, strict deep signature, ordinary-product and diff
checks PASS. Three targeted Profile contract regressions PASS0.006s: explicit
patch/full review, no-Session atomic write/readback and migration partial-patch
rejection. Installation, independent iPhone40307 readback and normal launch
succeeded. No physical iPad/Mac/phone layout acceptance or
new full-suite PASS is claimed. Current installation scope remains iPhone only.

Evidence: `/private/tmp/djc-welcome-settings-40307-ios-build-final.log` and
`/private/tmp/djc-welcome-settings-40307/`.
