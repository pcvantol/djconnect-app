import SwiftUI
import WidgetKit

struct DJConnectComplicationEntry: TimelineEntry {
    let date: Date
}

struct DJConnectComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> DJConnectComplicationEntry {
        DJConnectComplicationEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DJConnectComplicationEntry) -> Void) {
        completion(DJConnectComplicationEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DJConnectComplicationEntry>) -> Void) {
        let entry = DJConnectComplicationEntry(date: Date())
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct DJConnectComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DJConnectComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        case .accessoryCorner:
            corner
        default:
            circular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
        }
    }

    private var rectangular: some View {
        HStack(spacing: 7) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text("DJConnect")
                    .font(.headline)
                Text("Open muziekbediening")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inline: some View {
        Label("DJConnect", systemImage: "music.note.house.fill")
    }

    private var corner: some View {
        Image(systemName: "music.note.house.fill")
            .widgetLabel {
                Text("DJConnect")
            }
    }
}

struct DJConnectComplicationWidget: Widget {
    let kind = "DJConnectComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DJConnectComplicationProvider()) { entry in
            DJConnectComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("DJConnect")
        .description("Open DJConnect vanaf je wijzerplaat.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

@main
struct DJConnectWatchComplicationsBundle: WidgetBundle {
    var body: some Widget {
        DJConnectComplicationWidget()
    }
}
