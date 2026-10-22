# Session Find focus

Owner reports: Cmd+F reveals search but typing still goes to the Ask DJ composer; Forecast search also has no focus.

Search rows are mounted lazily. A focus request issued while opening the row can precede the actual native field. The shared search field now requests focus from its mounted task, with a stable request token so repeated Find refocuses the existing field. Session search hands off composer focus and forwards that request to either Flow/archive search or Forecast search. Repeated Find in an archive keeps the search field open.

Native AppKit coverage sends actual Cmd+F key equivalents, then inserts text through the window first responder. It checks that the search query receives input while the unsent composer draft stays intact, twice for both Flow-style and real Forecast search content. Existing offscreen Forecast positioning checks remain in the focused run.

Validation: native Cmd+F dispatch and two focus cases (Flow and Forecast) PASS, including verified composer first-responder state before each Find request. The additional initial-focus assertion first exposed a test setup error: its observer had not mounted before the first request; mounting the harness before requesting composer focus corrected it. Final run: 2 functions/3 cases,0 failures. Forecast content and offscreen-search positioning:2 tests PASS;2 optional screenshot tests skipped. Signed macOS/iOS40439 builds and strict signature verification PASS. Physical user acceptance remains separate.
