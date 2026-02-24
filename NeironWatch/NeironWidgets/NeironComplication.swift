import WidgetKit
import SwiftUI

// MARK: - Timeline Provider (static, no data needed)

struct NeironTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NeironEntry {
        NeironEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (NeironEntry) -> Void) {
        completion(NeironEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NeironEntry>) -> Void) {
        completion(Timeline(entries: [NeironEntry(date: Date())], policy: .never))
    }
}

struct NeironEntry: TimelineEntry {
    let date: Date
}

// MARK: - Views

struct NeironWidgetEntryView: View {
    var entry: NeironEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("N")
                        .font(.caption2.bold())
                }
            }
            .widgetURL(URL(string: "neiron://record"))
            .applyHandGesture()

        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Neiron")
                    .font(.headline)
            }
            .widgetURL(URL(string: "neiron://record"))
            .applyHandGesture()

        case .accessoryInline:
            Label("Neiron", systemImage: "mic.fill")
                .widgetURL(URL(string: "neiron://record"))
                .applyHandGesture()

        default:
            VStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                Text("Neiron")
                    .font(.caption.bold())
            }
            .widgetURL(URL(string: "neiron://record"))
        }
    }
}

// MARK: - Hand Gesture availability wrapper

extension View {
    @ViewBuilder
    func applyHandGesture() -> some View {
        if #available(iOS 18.0, watchOS 11.0, *) {
            self.handGestureShortcut(.primaryAction)
        } else {
            self
        }
    }
}

// MARK: - Widget

struct NeironWidget: Widget {
    let kind: String = "NeironWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NeironTimelineProvider()) { entry in
            NeironWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Neiron")
        .description("Быстрый доступ к голосовому ассистенту")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
