# Native scroll profiling — 2026-10-18

User requests CPU, memory and GPU profiling because Now Playing also stutters.
This investigation remains OPEN; no root-cause fix or physical smoothness acceptance is claimed.

## Actual target and source

- Physical iPhone 00008150-001409183C07801C was offline in Instruments on both hosts.
- Dedicated simulator DJConnect-Perf-20261018 /034B4C00-4872-4045-8A56-5D9F32387AFB on the MacBook, iPhone17Pro, stable iOS27.0/24A434; Xcode Instruments27.1/27A9275. No existing simulator erased. Host macOS27.0.1/26A434,64GiB RAM. Host memory_pressure reports72% available; no thermal/performance warning recorded.
- Used already-present /private/tmp/djc-choice-style-40312/source, native Debug build-for-testing PASS. The current RootView, NativeSessionMomentsView and SessionTimelineScreen hashes exactly match this measured source (c71a09f7…,98dcd2cd…,fb722707…). No current full-tree identity claim; widget40315 changes are not included.
- No physical installation/update. iPhone40315/Mac40314/iPad40290 remain unchanged.

## Recorded workload and results

1. Existing testSessionTimelineScrollBenchmark: isolated review_demo, ten submitted demo turns; one warm-up and three repeated four-drag scroll sequences. Native XCTest PASS86.413s. This is a short synthetic session with vinyl fallback, not the reported long real session and not a network/artwork-cache workload.
2. Time Profiler attached to simulator app PID28682 during setup and scroll; valid13559 samples,12807ms of weighted samples on main thread (~94.45%). The largest sampled leaf libraries are AttributeGraph2418ms, SwiftUICore1743ms, then Swift runtime1450ms. Other threads individually contribute211ms or less. This trace suggests UI update/layout work deserves investigation; it does not prove a particular root cause. NativeSessionMomentsView/admission/deadline work appears in app stacks; nativeDeadline still constructs ISO formatters. Inclusive timings overlap and are not additive.
3. XCTest scroll averages:10.485s wall clock,2.563s app CPU,65937.245kB physical peak,64462.685kB absolute physical memory. Memory deltas per sequence +98.304/-163.840/+49.152kB. No growth trend in this short run; this is not leak/long-session acceptance. Wall-clock includes synthesized gestures and XCTest idle waits, not frame duration.
4. Independent host top interval samples during session:19 samples, mean24.44%CPU, range19.9–28.1%, memory61–63M. Initial lifetime-CPU sample discarded. These samples overlap setup/scroll; no pure-scroll percentile claim.
5. Now Playing idle launched explicitly with existing --screenshot-screen=now-playing fixture. Screenshot visually confirms the actual screen.25s Metal System Trace contains2415 CPU samples,2207ms (~91.39%) main-thread weighted samples.11 top intervals: mean9.01%CPU, range7.0–11.1%,37M memory. Animated vinyl/TimelineView appears in app stacks. This case has no real cover and no scrolling; it cannot explain downloaded-art scrolling by itself.
6. Metal trace contains64557 GPU interval rows, mainly SimMetalHost (46191+9128) and SimRenderServer1520. No rows attributed directly to the app PID. Host/simulator compositor work cannot be represented as iPhone GPU utilization or app frame times. Real Metal capture exists, but GPU bottleneck/FPS remain unqualified.

## Tool limits and remaining work

- Animation Hitches fails explicitly: Hitches is not supported on this platform. Activity Monitor fails: Activity monitoring service not available on this device. Preserved probe traces; neither is a successful performance qualification.
- Time Profiler and Metal traces complete with a warning about one table without a known input source; actual populated CPU/GPU tables were exported and checked. Some system frames remain raw addresses. Debug/MainThreadChecker/XCTest/simulator overhead limits transfer to physical release performance.
- Added opt-in testNowPlayingScrollProfileWorkload to current local UI tests, gated by DJC_SCROLL_PROFILE=1. Isolated demo,25s attach window,10s idle,three measured six-drag rounds,10s recovery and timestamp markers. At this baseline it had not yet been compiled/executed on the remote host; see the authorized40317 continuation below. This tooling is not an app runtime change.
- Copying the current private source plus this new workload to the MacBook was rejected by automatic approval review because explicit source-transfer consent for that destination was missing. The owner subsequently explicitly approved this exact transfer; the40317 continuation below records the successful copy. Before that consent no retry, indirect source transfer or workaround was performed. Already-present source was used for the baseline work above.
- Next: complete actual-cover and long-session workloads after the fallback/glass40317 comparison below; obtain qualified SwiftUI body/update attribution. Then a bounded large-session fixture/soak, followed by physical GPU/frame/energy capture when the iPhone is available. Do not silently weaken protected SessionMedia no-store contracts or truncate real history.

## Evidence

Remote MacBook /private/tmp:
- djc-perf-session-baseline.xcresult and .log
- djc-perf-session-cpu.trace, .xml, -summary.json and -top.txt
- djc-perf-now-playing-idle-metal.trace and .log
- djc-perf-now-playing-idle-cpu.xml, -summary.json, -gpu.xml, -gpu-summary.json, -top.txt
- djc-perf-top-summary.json; djc-profile-20261018-{probe,render-probe,memory-probe,gpu-probe}.trace
- djc-perf-simulator-build.log and djc-perf-simulator-build/

Local /private/tmp/djc-profile-20261018 contains source-manifest.json/source.tar.gz (not transferred), copied metric summaries/logs and now-playing.png. Full traces remain on the MacBook to avoid filling the Mac mini's6.3GiB free disk. No publication/PR/merge.


## Owner-authorized continuation — verified Now Playing scroll /40317

Owner explicitly answered yes to copying the current private app source including
the new Now Playing workload to the existing MacBook. Transfer succeeded into
/private/tmp/djc-profile-40317/source. All273 selected input hashes were verified
on the destination, including the three new device-TTS production files and current
UI tests; recovery duplicate files, Git/private credentials and live user data are
excluded. Existing branch/writer and remote working checkouts remain unchanged.
The initial source.tar.gz remains immutable recovery. Only the UI workload was
then improved; source-manifest-verified.json describes that exact final273-file
snapshot and all hashes were independently rechecked on the MacBook afterwards.
Native build-for-testing40317 PASS before and after that test improvement.

The first central-drag workload did not prove page movement and started near the
seek slider/artwork interaction surface. Those first runs remain evidence of
interaction only and are **excluded from the final scroll comparison**. The final
test uses the empty ScrollView gutter, asserts track-title movement before the
measured interval, retains a moved-page screenshot and offers an explicit test-only
DJC_SCROLL_PROFILE_GLASS switch. Both qualified runs moved the title from572.0pt
to197.333pt (~374.67pt). Screenshot inspection also confirmed the actual Now Playing
screen after navigation; an earlier transition screenshot showed DJ Session and
was not used as screen acceptance.

| Glass | Idle CPU mean | Scroll CPU mean / peak | Recovery CPU mean | XCTest peak physical footprint mean |
|---|---:|---:|---:|---:|
| On |12.17%|23.29% /27.60%|11.09%|60,585.115kB|
| Off |9.55%|21.38% /25.73%|9.87%|57,887.216kB|

CPU phase values derive from cumulative app process CPU-time differences over
monotonic ~1second intervals, on a one-core100% scale. Actual idle windows span
9.12/9.11seconds, scroll windows30.40/29.37seconds and recovery9.11/8.11seconds.
XCTest separately measured three six-drag rounds: mean1.8000/1.5180seconds appCPU
and7.7459/7.0252seconds wall clock (glass on/off). Gesture synthesis, idle waits,
XCTest and Debug/Instruments overhead remain included; these are not frame times.
A single sequential case pair cannot establish statistical performance acceptance.

Both native tests and both dedicated Time Profiler captures completed successfully.
Glass-on trace:15,073 valid samples,13,542ms main-thread weight (~89.84%). Glass-off:
10,968 samples,10,070ms main-thread weight (~91.81%). UI/SwiftUI/AttributeGraph and
runtime work dominate; some frames remain unresolved. TimelineView and background
Session rendering also appear in inclusive app stacks; that observation is not a
proven causal bottleneck. Inclusive stack weights overlap and must not be added.
The reported95% CPU condition is not reproduced in this bounded workload.

Process RSS stayed around411.69–411.77MiB during glass-on scroll and408.70–408.91MiB
with glass off. RSS includes resident/shared mappings and differs from the XCTest
physical-footprint counter above. Neither shows sustained growth in this short run;
this does not qualify a leak-free heap or a long-session soak.

SwiftUI template capture failed explicitly because its Hitches component is not
supported on the simulator (exit2). A separate Time Profiler+SwiftUI capture ended
successfully for CPU but warned “Trace file had no SwiftUI data”: no qualified
view-body/layout cost result is claimed. No Instruments privacy prompt was bypassed.
Physical iPhone/Watch/iPad still report offline in Instruments. Prior simulator
Metal/compositor evidence remains separate from physical GPU/FPS/hitch acceptance.

Current demo playback has no artwork URL. Consequently these runs exercise vinyl
fallback, not image download/decoding/cache reuse; they cannot answer real-artwork
or protected SessionMedia cache hit behavior. Real covers, larger history, physical
GPU/frame pacing, heap/energy and independently attributable SwiftUI updates remain
open. No app-runtime optimization or root-cause fix is claimed by this increment.

Full .trace/.xcresult/XML/process logs remain on the MacBook in
/private/tmp/djc-profile-40317. Compact qualified summaries, raw XCTest metrics and
logs were read back locally in the same temporary path. Sanitized final metrics,
source/test hashes and limits: [40317 qualification JSON](APPLE_NOW_PLAYING_SCROLL_40317_20261018.json).
All owned benchmark/profiler processes finished. Simulator install only; no physical
app update, release, PR, merge or publication.


## Physical iPhone unlock follow-up — preflight, still no recording

Owner reported the iPhone unlocked. Fresh CoreDevice read confirms
passcodeRequired=false, unlockedSinceBoot=true, paired/available, developer mode
enabled and DDI services available. Ordinary dev.djconnect.ios40315 remains
installed and its existing process is running; no app replacement or launch was
performed. Transport is localNetwork. Fresh Instruments enumeration on both Mac
mini and MacBook still lists the phone offline. One direct10second Time Profiler
attach attempt rejected the known live PID (“Cannot find process for provided
pid”); a new CoreDevice process read confirmed the same app PID afterwards. This
is a developer-tool transport block, not measured CPU/GPU evidence and not a claim
that the phone remained locked. No pairing, trust, privacy, signing or system
settings were changed. Owner USB-connect question is pending, preferably MacBook;
physical captures wait for that connection. Available Time Profiler, Activity
Monitor, Allocations and Metal instruments were read-only checked in preparation.
Sanitized preflight: [physical readiness JSON](APPLE_PHYSICAL_PROFILE_PREFLIGHT_20261018.json).
Raw private device readback/logs remain at /private/tmp/djc-physical-profile-20261018.
