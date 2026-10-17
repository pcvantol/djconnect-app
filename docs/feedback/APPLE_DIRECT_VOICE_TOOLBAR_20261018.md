# Direct Mac voice control and single picker labels

Owner requests removing duplicate playback/voice preference labels and moving
DJ voice directly into the left Session toolbar group, keeping VibeCast separate.

ProfileDJSettingsEditor retains one visible heading per output/voice picker and
hides its automatic visual label, with explicit localized accessibility labels.
Bindings, allowed choices, validation and existing owner write behavior unchanged.

Mac Session toolbar now combines refresh/search/mood/presence/persona/direct
speaker button in one ToolbarItemGroup. Removed the one-item custom ellipsis menu;
direct speaker toggles the same Profile editor popover with existing Session,
history epoch and scene dismissal fences. VibeCast moved into a separate
ToolbarItem and retains its original action/availability/identifier.

Native signed Mac40309 build/strict signature/ordinary-product/diff checks PASS.
iOS40309 build/strict signature/ordinary-product checks also PASS; iPhone install,
independent40309 readback and normal launch succeeded. No new unit
tests for this layout/accessibility-only change, and no physical Mac viewport
acceptance claimed. Mac product remains uninstalled under the standing
iPhone-only installation scope.

Evidence: `/private/tmp/djc-voice-toolbar-40309-{mac,ios}-build.log`.
