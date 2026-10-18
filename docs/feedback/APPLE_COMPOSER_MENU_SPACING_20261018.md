# iPhone composer closer to bottom menu

Owner requests the Ask DJ input bar closer to the bottom menu, matching iPad.
SessionTimelineScreen and standalone AskDJView now use8pt bottom composer padding
on iPhone with keyboard hidden, matching iPad instead of21pt. Keyboard-visible
iPhone padding remains6pt. The measured content reservation uses the same value,
so submitted-question positioning follows the adjusted bar without an independent
offset. No input/send/scroll identity or backend behavior changes.

Validation: diff/native signed iOS40305 build/strict deep signature/ordinary-app
checks PASS. Installation succeeded; independent iPhone apps readback confirms
40305 and app launch succeeded. No new tests for this two-value spacing change;
physical viewport acceptance remains separate. iPad/Mac unchanged.

Evidence: `/private/tmp/djc-composer-spacing-40305-ios-build.log` and
`/private/tmp/djc-composer-spacing-40305/{install,apps,launch}.json`.
