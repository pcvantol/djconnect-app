# Queue repeated-item report — HA-dev

Owner reports one queued track but many identical rows in the iPhone Queue view:
Heaven Nor Hell / Volbeat / Beyond Hell / Above Heaven (screenshot21:14).
Owner explicitly confirmed HA-dev. No playback command or queue mutation was
issued during diagnosis.

Apple source readback: queue response decoding selects one envelope alias;
refresh replaces the entire queue array. It does not append old snapshots.
Normalization preserves provider positions and supplies distinct row identities
for repeated tracks. An existing regression explicitly preserves8 same-track
positions. A blanket URI/title dedup would discard legitimate queue positions.

Read-only Core source trace: Spotify backend reads `/me/player/queue` and retains
each valid provider queue position. This is source evidence, not the live
provider response for the reported screenshot. The existing Core writer received
the owner report and request for a read-only HA-dev count/shape/provider check.
The original runtime cause and correction remain open pending that evidence.

New regression checks replacement of12 existing rows with a1-item response,
three repeated applications per envelope shape, and flat/nested/data/result
decoding without concatenating aliases. It checks model and widget counts;
existing legitimate-repeat and empty-queue coverage remain unchanged. Test
results are recorded below after completion. Private receipts:
`/private/tmp/djc-queue-one-item-regression/`.

Core read-only live HA-dev receipt at20:58:51Z returned queue HTTP200 with20
positions/20 unique media IDs, repeat off and zero matching the current track.
It does not reproduce or explain the original Volbeat snapshot. Core retains
producer ownership; no dedup/queue semantics change is justified by this receipt.

Added count-only diagnostic logging on explicit queue responses: decoded count,
normalized/model row count and distinct-track-signature count. Logs include no
track titles, URIs, tokens or response bodies. The queue is not changed by this
instrumentation. It is diagnostic preparation, not a claimed duplicate fix.

Six queue decoder/model/widget regression tests PASS0.138s, including the new
single-item replacement test and existing legitimate repetition coverage. Initial
new-test compile failed because it called a private overload; corrected to the
public model projection, then reran successfully. Both logs remain retained.
Native signed iOS40298 build, strict deep signatures and ordinary-product checks
PASS. iPhone installed/read back40298 and launched; iPad/MacBook not updated.
Installation evidence is recorded in the private receipt directory above.
No new full-suite claim or physical duplicate-reproduction PASS is implied.
