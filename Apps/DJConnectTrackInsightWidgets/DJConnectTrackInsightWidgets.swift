import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(DJConnectCore)
import DJConnectCore
#endif

struct DJConnectTrackInsightWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let genre: String
    let mood: String
    let vibe: String
    let bpm: Int
    let key: String
    let energy: Double
    let danceability: Double
    let intensity: Double
    let summary: String
    let hasSnapshot: Bool

    init(
        date: Date,
        title: String,
        artist: String,
        genre: String,
        mood: String,
        vibe: String,
        bpm: Int,
        key: String,
        energy: Double,
        danceability: Double,
        intensity: Double,
        summary: String,
        hasSnapshot: Bool
    ) {
        self.date = date
        self.title = title
        self.artist = artist
        self.genre = genre
        self.mood = mood
        self.vibe = vibe
        self.bpm = bpm
        self.key = key
        self.energy = energy
        self.danceability = danceability
        self.intensity = intensity
        self.summary = summary
        self.hasSnapshot = hasSnapshot
    }

    static let placeholder = DJConnectTrackInsightWidgetEntry(
        date: Date(),
        title: "Innerbloom",
        artist: "RUFUS DU SOL",
        genre: "Deep House",
        mood: "Dreamy",
        vibe: "Cinematic",
        bpm: 122,
        key: "F# minor",
        energy: 0.65,
        danceability: 0.72,
        intensity: 0.58,
        summary: "A slow-building journey with glowing synth textures and a hypnotic groove.",
        hasSnapshot: true
    )

    static let empty = DJConnectTrackInsightWidgetEntry(
        date: Date(),
        title: DJConnectLocalization.localized(english: "No Track Insight yet", dutch: "Nog geen Track Insight"),
        artist: DJConnectLocalization.localized(english: "Open DJConnect", dutch: "Open DJConnect"),
        genre: DJConnectLocalization.localized(english: "Private", dutch: "Privé"),
        mood: DJConnectLocalization.localized(english: "Ready", dutch: "Klaar"),
        vibe: DJConnectLocalization.localized(english: "On device", dutch: "Op apparaat"),
        bpm: 0,
        key: "-",
        energy: 0.5,
        danceability: 0.5,
        intensity: 0.5,
        summary: DJConnectLocalization.localized(
            english: "Run Track Insight in the app to update this widget.",
            dutch: "Open Track Insight in de app om deze widget bij te werken."
        ),
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectTrackInsightWidgetSnapshot) {
        date = snapshot.updatedAt
        title = snapshot.title
        artist = snapshot.artist
        genre = snapshot.genre ?? DJConnectLocalization.localized(english: "Unknown genre", dutch: "Onbekend genre")
        mood = snapshot.mood ?? DJConnectLocalization.localized(english: "Evolving", dutch: "In beweging")
        vibe = snapshot.vibe ?? DJConnectLocalization.localized(english: "Fresh", dutch: "Fris")
        bpm = snapshot.bpm ?? 0
        key = snapshot.key ?? "-"
        energy = snapshot.energy ?? 0.5
        danceability = snapshot.danceability ?? 0.5
        intensity = snapshot.intensity ?? 0.5
        summary = snapshot.summary
        hasSnapshot = true
    }
#endif
}

struct DJConnectTrackInsightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectTrackInsightWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectTrackInsightWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectTrackInsightWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectTrackInsightWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
           let snapshot = DJConnectTrackInsightWidgetSnapshot.load(from: defaults) {
            return DJConnectTrackInsightWidgetEntry(snapshot: snapshot)
        }
#endif
        return .empty
    }
}

struct DJConnectTrackInsightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        ZStack {
            DJConnectTrackInsightWidgetBackground(entry: entry)
            content
        }
        .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .systemLarge, .systemExtraLarge:
            large
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            Label(entry.title, systemImage: "waveform.path.ecg")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(compact: true)
            Spacer(minLength: 0)
            DJConnectTrackInsightOrb(entry: entry)
                .frame(width: 58, height: 58)
            Spacer(minLength: 0)
            titleBlock(lineLimit: 1)
            metricRow
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            DJConnectTrackInsightOrb(entry: entry)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                header(compact: false)
                titleBlock(lineLimit: 1)
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
                metricRow
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(compact: false)
            HStack(alignment: .center, spacing: 16) {
                DJConnectTrackInsightOrb(entry: entry)
                    .frame(width: 126, height: 126)
                VStack(alignment: .leading, spacing: 8) {
                    titleBlock(lineLimit: 2)
                    Text(entry.summary)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                }
            }
            DJConnectTrackInsightMeterRow(entry: entry)
            Spacer(minLength: 0)
            Text(DJConnectLocalization.localized(english: "Rendered privately on device", dutch: "Privé gerenderd op apparaat"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(18)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.hasSnapshot ? "\(entry.genre) - \(entry.bpm) BPM" : entry.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
                .font(.caption.weight(.bold))
            Text(entry.hasSnapshot ? (compact ? "Insight" : "Track Insight") : DJConnectLocalization.localized(english: "Ready", dutch: "Klaar"))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.82))
    }

    private func titleBlock(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(lineLimit)
            Text(entry.artist)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
    }

    private var metricRow: some View {
        Text(entry.hasSnapshot ? [entry.genre, bpmLabel, entry.key].filter { !$0.isEmpty }.joined(separator: " - ") : entry.vibe)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.70))
            .lineLimit(1)
    }

    private var bpmLabel: String {
        entry.hasSnapshot && entry.bpm > 0 ? "\(entry.bpm) BPM" : ""
    }

}

private struct DJConnectTrackInsightWidgetBackground: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.11),
                    Color(red: 0.10, green: 0.08, blue: 0.31),
                    Color(red: 0.38, green: 0.12, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            DJConnectTrackInsightWavefield(entry: entry)
                .opacity(0.92)
        }
    }
}

private struct DJConnectTrackInsightWavefield: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let rows = 7
                for row in 0..<rows {
                    var path = Path()
                    let baseY = size.height * (0.28 + CGFloat(row) * 0.085)
                    let amplitude = size.height * (0.025 + CGFloat(entry.intensity) * 0.035)
                    let phase = CGFloat(row) * 0.72
                    let step = max(size.width / 34, 4)
                    var x: CGFloat = -step
                    var first = true
                    while x <= size.width + step {
                        let progress = x / max(size.width, 1)
                        let wave = sin(progress * .pi * 3.2 + phase) * amplitude
                        let point = CGPoint(x: x, y: baseY + wave)
                        if first {
                            path.move(to: point)
                            first = false
                        } else {
                            path.addLine(to: point)
                        }
                        x += step
                    }
                    let color = Color(
                        hue: 0.58 + Double(row) * 0.045,
                        saturation: 0.82,
                        brightness: 1.0
                    )
                    context.stroke(path, with: .color(color.opacity(0.32)), lineWidth: 1.2)
                }

                let barCount = 34
                let width = size.width / CGFloat(barCount)
                for index in 0..<barCount {
                    let seed = Double((index * 37 + entry.bpm) % 100) / 100
                    let height = size.height * (0.05 + (0.18 * seed + 0.16 * entry.energy))
                    let rect = CGRect(
                        x: CGFloat(index) * width,
                        y: size.height - height - 8,
                        width: max(1.5, width * 0.52),
                        height: height
                    )
                    let color = Color(hue: 0.58 + Double(index) / Double(barCount) * 0.28, saturation: 0.88, brightness: 1.0)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(0.58)))
                }
            }
        }
    }
}

private struct DJConnectTrackInsightOrb: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .black.opacity(0.10),
                            Color(red: 0.17, green: 0.07, blue: 0.28).opacity(0.96),
                            Color(red: 0.02, green: 0.03, blue: 0.07).opacity(0.98)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 80
                    )
                )
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .trim(from: 0.06 * CGFloat(ring), to: min(0.96, CGFloat(entry.energy + Double(ring) * 0.08)))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 0.31, green: 0.63, blue: 1.0),
                                Color(red: 0.75, green: 0.36, blue: 1.0),
                                Color(red: 1.0, green: 0.35, blue: 0.42),
                                Color(red: 0.31, green: 0.63, blue: 1.0)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: CGFloat(3 - ring) + 1, lineCap: .round)
                    )
                    .rotationEffect(.degrees(Double(ring) * 42))
                    .padding(CGFloat(ring) * 8 + 5)
                    .opacity(0.92 - Double(ring) * 0.16)
            }
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct DJConnectTrackInsightMeterRow: View {
    let entry: DJConnectTrackInsightWidgetEntry

    var body: some View {
        HStack(spacing: 10) {
            meter(title: DJConnectLocalization.localized(english: "Energy", dutch: "Energie"), value: entry.energy)
            meter(title: DJConnectLocalization.localized(english: "Dance", dutch: "Dans"), value: entry.danceability)
            meter(title: DJConnectLocalization.localized(english: "Intensity", dutch: "Intensiteit"), value: entry.intensity)
        }
    }

    private func meter(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.28, green: 0.65, blue: 1.0),
                                    Color(red: 0.82, green: 0.25, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0.06, min(1, value)))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DJConnectTrackInsightWidget: Widget {
    let kind = DJConnectTrackInsightWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectTrackInsightWidgetProvider()) { entry in
            DJConnectTrackInsightWidgetView(entry: entry)
        }
        .configurationDisplayName("Track Insight")
        .description(DJConnectLocalization.localized(english: "DJConnect Track Insight visualization for your current vibe.", dutch: "DJConnect Track Insight visualisatie voor je huidige vibe."))
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ]
        #endif
    }
}

struct DJConnectAskDJWidgetEntry: TimelineEntry {
    let date: Date
    let prompt: String
    let response: String
    let mood: String
    let trackTitle: String
    let artist: String
    let hasSnapshot: Bool

    init(date: Date, prompt: String, response: String, mood: String, trackTitle: String, artist: String, hasSnapshot: Bool) {
        self.date = date
        self.prompt = prompt
        self.response = response
        self.mood = mood
        self.trackTitle = trackTitle
        self.artist = artist
        self.hasSnapshot = hasSnapshot
    }

    static let placeholder = DJConnectAskDJWidgetEntry(
        date: Date(),
        prompt: "Ask DJ",
        response: "Vraag om de vibe, ontdek waarom een track werkt of laat DJConnect een volgende stap voorstellen.",
        mood: "Private - On device - Music DNA",
        trackTitle: "Innerbloom",
        artist: "RUFUS DU SOL",
        hasSnapshot: true
    )

    static let empty = DJConnectAskDJWidgetEntry(
        date: Date(),
        prompt: DJConnectLocalization.localized(english: "Ask DJ", dutch: "Ask DJ"),
        response: DJConnectLocalization.localized(
            english: "Ask DJ in the app to update this widget.",
            dutch: "Gebruik Ask DJ in de app om deze widget bij te werken."
        ),
        mood: DJConnectLocalization.localized(english: "Private - On device", dutch: "Privé - Op apparaat"),
        trackTitle: DJConnectLocalization.localized(english: "No Ask DJ snapshot yet", dutch: "Nog geen Ask DJ snapshot"),
        artist: "DJConnect",
        hasSnapshot: false
    )

#if canImport(DJConnectCore)
    init(snapshot: DJConnectAskDJWidgetSnapshot) {
        date = snapshot.updatedAt
        prompt = snapshot.prompt
        response = snapshot.response
        mood = snapshot.context
        trackTitle = snapshot.trackTitle ?? DJConnectLocalization.localized(english: "Ask DJ", dutch: "Ask DJ")
        artist = snapshot.artist ?? DJConnectLocalization.localized(english: "Ready", dutch: "Klaar")
        hasSnapshot = true
    }
#endif
}

struct DJConnectAskDJWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectAskDJWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectAskDJWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectAskDJWidgetEntry>) -> Void) {
        let entry = Self.currentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func currentEntry() -> DJConnectAskDJWidgetEntry {
#if canImport(DJConnectCore)
        if let defaults = UserDefaults(suiteName: DJConnectTrackInsightWidgetSnapshot.appGroupIdentifier),
           let snapshot = DJConnectAskDJWidgetSnapshot.load(from: defaults) {
            return DJConnectAskDJWidgetEntry(snapshot: snapshot)
        }
#endif
        return .empty
    }
}

struct DJConnectAskDJWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectAskDJWidgetEntry

    var body: some View {
        ZStack {
            DJConnectAskDJWidgetBackground()
            content
        }
        .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .systemLarge, .systemExtraLarge:
            large
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            Label("Ask DJ", systemImage: "sparkles")
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(compact: true)
            Spacer(minLength: 0)
            DJConnectAskDJOrb()
                .frame(width: 62, height: 62)
            Spacer(minLength: 0)
            Text("Ask DJ")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(entry.prompt)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(1)
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            DJConnectAskDJOrb()
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                header(compact: false)
                Text(entry.response)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text(entry.mood)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(compact: false)
            HStack(alignment: .center, spacing: 16) {
                DJConnectAskDJOrb()
                    .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: 7) {
                    Text(entry.prompt)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(entry.response)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(4)
                }
            }
            DJConnectAskDJPromptRow(entry: entry)
            Spacer(minLength: 0)
            Text(entry.mood)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.60))
                .lineLimit(1)
        }
        .padding(18)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Ask DJ")
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.prompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
            Text(compact ? "Ask DJ" : "DJConnect Ask DJ")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.84))
    }
}

private struct DJConnectAskDJWidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.10),
                    Color(red: 0.09, green: 0.08, blue: 0.29),
                    Color(red: 0.24, green: 0.08, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                for index in 0..<42 {
                    let x = size.width * CGFloat((index * 19) % 43) / 42
                    let y = size.height * CGFloat((index * 31) % 47) / 46
                    let radius = CGFloat((index % 4) + 1)
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    let color = Color(hue: 0.58 + Double(index % 12) * 0.025, saturation: 0.82, brightness: 1)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.44)))
                }

                var path = Path()
                let baseY = size.height * 0.68
                let step = max(size.width / 28, 4)
                var x: CGFloat = -step
                var first = true
                while x <= size.width + step {
                    let progress = x / max(size.width, 1)
                    let point = CGPoint(
                        x: x,
                        y: baseY + sin(progress * .pi * 4.2) * size.height * 0.045
                    )
                    if first {
                        path.move(to: point)
                        first = false
                    } else {
                        path.addLine(to: point)
                    }
                    x += step
                }
                context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1.4)
            }
        }
    }
}

private struct DJConnectAskDJOrb: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.29, green: 0.62, blue: 1.0),
                            Color(red: 0.49, green: 0.34, blue: 1.0),
                            Color(red: 0.82, green: 0.28, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct DJConnectAskDJPromptRow: View {
    let entry: DJConnectAskDJWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            prompt("Analyze this track", systemImage: "waveform.path.ecg")
            prompt("Why does this vibe work?", systemImage: "bubble.left.and.bubble.right.fill")
            prompt("What should play next?", systemImage: "music.note.list")
        }
    }

    private func prompt(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .frame(width: 18)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.78))
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DJConnectAskDJWidget: Widget {
    let kind = "DJConnectAskDJWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectAskDJWidgetProvider()) { entry in
            DJConnectAskDJWidgetView(entry: entry)
        }
        .configurationDisplayName("Ask DJ")
        .description(DJConnectLocalization.localized(english: "DJConnect Ask DJ widget for quick music questions and vibe context.", dutch: "DJConnect Ask DJ widget voor snelle muziekvragen en vibe-context."))
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ]
        #endif
    }
}

#if canImport(ActivityKit) && os(iOS)
@available(iOS 16.1, *)
struct DJConnectTrackInsightLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackInsightLiveActivityAttributes.self) { context in
            DJConnectTrackInsightLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.03, green: 0.04, blue: 0.10))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DJConnectTrackInsightLiveActivityOrb(state: context.state)
                        .frame(width: 54, height: 54)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DJConnectTrackInsightLiveActivityMetricStack(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DJConnectTrackInsightLiveActivityExpandedBottom(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.purple)
            } compactTrailing: {
                Text(context.state.compactMetric)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.purple)
            }
            .keylineTint(.purple)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectTrackInsightLiveActivityLockScreenView: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            DJConnectTrackInsightLiveActivityOrb(state: state)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 6) {
                Label("Track Insight", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)
                Text(state.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.artist)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                DJConnectTrackInsightLiveActivityDescriptorRow(state: state)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background {
            DJConnectTrackInsightLiveActivityBackground(state: state)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectTrackInsightLiveActivityExpandedBottom: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(state.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Text(state.artist)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            DJConnectTrackInsightLiveActivityDescriptorRow(state: state)
            DJConnectTrackInsightLiveActivityWaveform(state: state)
                .frame(height: 26)
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectTrackInsightLiveActivityDescriptorRow: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            if let genre = state.genre {
                Text(genre)
            }
            if let bpm = state.bpm {
                Text("\(bpm) BPM")
            }
            if let key = state.key {
                Text(key)
            }
            if let vibe = state.vibe ?? state.mood {
                Text(vibe)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
        .lineLimit(1)
    }
}

@available(iOS 16.1, *)
private struct DJConnectTrackInsightLiveActivityMetricStack: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let energy = state.energy {
                Text(energy.formatted(.number.precision(.fractionLength(2))))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(DJConnectLocalization.localized(english: "Energy", dutch: "Energie"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectTrackInsightLiveActivityOrb: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.2)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.18, green: 0.09, blue: 0.32),
                                Color(red: 0.02, green: 0.03, blue: 0.08)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 54
                        )
                    )
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .trim(from: 0.08, to: 0.74 + CGFloat(ring) * 0.06)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.63, blue: 1.0),
                                    Color(red: 0.78, green: 0.34, blue: 1.0),
                                    Color(red: 1.0, green: 0.34, blue: 0.44),
                                    Color(red: 0.30, green: 0.63, blue: 1.0)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: CGFloat(4 - ring), lineCap: .round)
                        )
                        .rotationEffect(.degrees(phase * (18 + Double(ring) * 7) + Double(state.animationSeed % 120)))
                        .padding(CGFloat(ring) * 7 + 5)
                        .opacity(0.92 - Double(ring) * 0.18)
                }
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectTrackInsightLiveActivityWaveform: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let bars = 26
                let barWidth = size.width / CGFloat(bars)
                let energy = state.energy ?? 0.62
                for index in 0..<bars {
                    let seed = Double((index * 29 + state.animationSeed) % 97) / 97
                    let pulse = (sin(phase * 1.7 + Double(index) * 0.45) + 1) / 2
                    let height = size.height * (0.18 + 0.52 * seed * energy + 0.22 * pulse)
                    let rect = CGRect(
                        x: CGFloat(index) * barWidth,
                        y: size.height - height,
                        width: max(2, barWidth * 0.48),
                        height: height
                    )
                    let color = Color(hue: 0.58 + Double(index) / Double(bars) * 0.24, saturation: 0.86, brightness: 1)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(0.78)))
                }
            }
        }
    }
}

@available(iOS 16.1, *)
private struct DJConnectTrackInsightLiveActivityBackground: View {
    let state: TrackInsightLiveActivityAttributes.ContentState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.10),
                    Color(red: 0.10, green: 0.08, blue: 0.30),
                    Color(red: 0.36, green: 0.10, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            DJConnectTrackInsightLiveActivityWaveform(state: state)
                .opacity(0.26)
                .padding(.top, 48)
        }
    }
}

@available(iOS 16.1, *)
private extension TrackInsightLiveActivityAttributes.ContentState {
    var compactMetric: String {
        if let bpm {
            return "\(bpm)"
        }
        return "Vibe"
    }
}
#endif

@main
struct DJConnectTrackInsightWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DJConnectTrackInsightWidget()
        DJConnectAskDJWidget()
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.1, *) {
            DJConnectTrackInsightLiveActivityWidget()
        }
        #endif
    }
}
