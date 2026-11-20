import SwiftUI
import DJConnectCore
#if os(macOS)
import AppKit
#endif

struct AskDJMomentsCardContent: View {
    @ObservedObject var controller: AskDJMomentsController
    let language: String
    let result: () -> AnyView
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var reading = false
    @State private var scrollVisible = false
    #if os(macOS)
    @State private var windowVisible = false
    #else
    @State private var windowVisible = true
    #endif
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.ask_moments." + key, language: language) }
    var body: some View {
        let generation = controller.generation
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(text("title")).font(.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button(text("close")) { controller.close() }.frame(minHeight: 44)
            }
            switch controller.presentation.phase {
            case .choosing:
                if controller.loading { ProgressView(text("loading_inventory")) }
                if let inventory = controller.inventory {
                    AskDJMomentsCatalogue(inventory: inventory, language: language, unavailableLabel: text("unavailable"), select: controller.select)
                }
            case .pending:
                if !controller.outcomeUnknown {
                    ProgressView().accessibilityHidden(true)
                    Text(controller.pendingText ?? text("loading_inventory")).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ask-moments-pending")
                }
                HStack {
                    Button(text("cancel")) { controller.cancel() }.disabled(controller.operationID == nil || controller.checkingCancellation)
                    if controller.noticeText != nil { Button(text("check_status")) { controller.checkStatus() } }
                }.frame(minHeight: 44)
            case .presenting:
                result()
                    .id("requested-rich-result-" + generation.uuidString)
                    .onScrollVisibilityChange(threshold: 0.01) { visible in
                        guard controller.generation == generation else { return }
                        scrollVisible = visible
                        controller.visibility(visible && windowVisible && scenePhase == .active, generation: generation)
                    }
                    .onDisappear { controller.visibility(false, generation: generation) }
                if let accepted = controller.currentResult {
                    Text(text(accepted.retention == "retained" ? "already_saved" : "not_retained"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle(text(reading ? "release_reading" : "keep_reading"), isOn: $reading)
                    .onChange(of: reading) { _, active in controller.hold(.reading, active, generation: generation) }
                    .frame(minHeight: 44)
            case .notice:
                if controller.operationID != nil { Button(text("check_status")) { controller.checkStatus() }.frame(minHeight: 44) }
            case .idle: EmptyView()
            }
            if let notice = controller.noticeText { Text(notice).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ask-moments-current-card")
        .onChange(of: scenePhase) { _, phase in
            controller.visibility(scrollVisible && windowVisible && phase == .active, generation: generation)
        }
        .onChange(of: voiceOver, initial: true) { _, enabled in controller.hold(.accessibility, enabled, generation: generation) }
        .onChange(of: controller.presentation.momentID) { _, id in
            if id == nil { scrollVisible = false }
            controller.hold(.accessibility, voiceOver, generation: generation)
        }
        .onAppear { reading = controller.presentation.holds.contains(.reading) }
        .onDisappear { controller.visibility(false, generation: generation) }
        .background {
            #if os(macOS)
            AskDJMomentsWindowVisibility { visible in
                guard windowVisible != visible else { return }
                windowVisible = visible
                controller.visibility(scrollVisible && visible && scenePhase == .active, generation: generation)
            }.frame(width: 0, height: 0)
            #endif
        }
        .task {
            while !Task.isCancelled {
                controller.tick()
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
        }
    }
}

struct AskDJMomentsCatalogue: View {
    let inventory: DJConnectAskDJMoments.Inventory
    let language: String
    let unavailableLabel: String
    let select: (DJConnectAskDJMoments.Item) -> Void
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach(inventory.orderedTypes) { item in
                    Button { select(item) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title(language: language)).font(.headline)
                            Text(item.subject.title).font(.body)
                            if !item.subject.subtitle.isEmpty { Text(item.subject.subtitle).font(.caption) }
                            if !item.available { Text(item.unavailableReason(language: language) ?? unavailableLabel).font(.caption).foregroundStyle(.white.opacity(0.8)) }
                        }.lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).padding(10)
                    }
                    .buttonStyle(AskDJMomentsRowStyle(available: item.available)).disabled(!item.available)
                    .accessibilityIdentifier("ask-moments-type-" + item.typeID)
                }
            }
        }.frame(maxHeight: 480)
    }
}

/// Disabled choices remain readable/discoverable; native disabled semantics and
/// the Core explanation carry availability instead of compounded opacity.
private struct AskDJMomentsRowStyle: ButtonStyle {
    let available: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(available ? 1 : 0.85))
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(configuration.isPressed ? 0.22 : available ? 0.14 : 0.07)))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

#if os(macOS)
/// A mounted/offscreen SwiftUI node is not proof that its Mac window is visible.
private struct AskDJMomentsWindowVisibility: NSViewRepresentable {
    var changed: (Bool) -> Void
    func makeNSView(context: Context) -> Probe { Probe(changed: changed) }
    func updateNSView(_ view: Probe, context: Context) { view.changed = changed; view.report() }
    final class Probe: NSView {
        var changed: (Bool) -> Void
        private var observers: [NSObjectProtocol] = []
        init(changed: @escaping (Bool) -> Void) { self.changed = changed; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver); observers = []
            for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                })
            }
            report()
        }
        func report() {
            let visible = window.map { $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) } ?? false
            let changed = changed
            DispatchQueue.main.async { changed(visible) }
        }
        isolated deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
#endif
