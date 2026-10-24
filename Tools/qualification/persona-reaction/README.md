# Native avatar input qualification

This disposable iPhone/iPad host renders the actual `PersonaReactionAvatarInteraction`
with local counters. It constructs no AppModel, paired identity, HTTP connection,
reaction request, audio output or private Profile storage. Counters confer no
server authority and are never shipping product behavior.

Generate a new output directory with the existing, clean shipping JOSESwift pin:

```sh
python3 Tools/qualification/persona-reaction/prepare_native_persona_tests.py "/absolute/shared-temp/new-project" --jose-checkout "/absolute/path/to/JOSESwift" --platform iOS
```

Run the generated `NativePersonaReaction` scheme with an owned iPhone or iPad
simulator destination, a separate result bundle and `-collect-test-diagnostics never`.
Store all generated output outside the repository. The helper refuses a reused
project directory and an incorrect or dirty dependency checkout.

Three tests exercise six successive single/double/triple tap selections during
ordinary parent updates, busy/withdrawn presentation, and the existing native
context-menu alternative. The busy/withdrawal counter guard is synthetic; actual
owner/Session/settings/observation/busy admission remains in AppModel and the
existing controller tests. Keyboard and VoiceOver callbacks are retained, but
these UI tests do not qualify keyboard or actual VoiceOver operation.

The UIKit context-menu runtime warning about `_UIGravityWellEffectAnchorView` and
its animation-quiescence delay were observed in the original diagnostics. Keep
those logs and any original failures. A passed test is no claim that the runtime
warning or physical/native context-menu qualification is resolved. macOS input
requires its own interactive test; an unsigned build only proves compilation.
