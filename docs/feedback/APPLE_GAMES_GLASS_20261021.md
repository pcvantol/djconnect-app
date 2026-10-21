# Games glass presentation — 21 October 2026

All four games share the updated card and selector. Both now use the existing `djSessionFrostedSurface()` treatment. The selected game uses the same interactive glass button implementation as the other selection controls. Removed the opaque purple card gradients and the two black layers behind the game canvas so the glass remains visible through the playfield. Geometry, scores, input and gameplay are unchanged.

The shared surface continues to respect the local Glass effects preference and Reduce Transparency fallback.

Validation: incremental Mac `DJConnectUI` build PASS (22.46 seconds), `git diff --check` PASS. Existing unrelated compiler/package/deprecation warnings are preserved in the private build log, hashed in the adjacent JSON. No new physical visual acceptance, device installation or gameplay test is claimed.
