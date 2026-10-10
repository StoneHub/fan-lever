import WidgetKit
import SwiftUI
import AppIntents

struct SetFanIntent: AppIntent {
    static var title: LocalizedStringResource = "Set fan speed"
    static var description = IntentDescription("Select a Fan Lever notch. Manual speeds return to Auto after 30 minutes.")
    @Parameter(title: "Notch") var notch: Int
    init() {}
    init(_ setting: FanSetting) { notch = setting.rawValue }
    func perform() async throws -> some IntentResult {
        guard let setting = FanSetting(rawValue: notch) else { throw FanError.message("Unknown fan notch.") }
        let snapshot = await FanClient.request(setting)
        SnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: FanConstants.widgetKind)
        if let message = snapshot.message { throw FanError.message(message) }
        return .result()
    }
}

struct FanEntry: TimelineEntry { let date: Date; let snapshot: FanSnapshot }
struct FanProvider: TimelineProvider {
    func placeholder(in context: Context) -> FanEntry { FanEntry(date: Date(), snapshot: .preview) }
    func getSnapshot(in context: Context, completion: @escaping (FanEntry) -> Void) {
        completion(FanEntry(date: Date(), snapshot: context.isPreview ? .preview : SnapshotStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FanEntry>) -> Void) {
        Task {
            let snapshot = await FanClient.request()
            SnapshotStore.save(snapshot)
            let next = min(Date().addingTimeInterval(300), snapshot.expires ?? .distantFuture)
            completion(Timeline(entries: [FanEntry(date: Date(), snapshot: snapshot)], policy: .after(max(next, Date().addingTimeInterval(10)))))
        }
    }
}

struct FanWidgetView: View {
    let entry: FanEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        let snapshot = entry.snapshot
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 8) {
            HStack {
                Image(systemName: "fanblades.fill").font(.system(size: 16)).widgetAccentable()
                Text("Fan Lever").font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                if family != .systemSmall {
                    Text(snapshot.selected?.label ?? "—").font(.system(size: 11, weight: .medium, design: .rounded))
                }
            }
            LeverView(selected: snapshot.connected ? snapshot.selected : nil) { setting in
                Button(intent: SetFanIntent(setting)) {
                    LeverNotch(setting: setting, selected: snapshot.connected && snapshot.selected == setting)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(setting == .auto ? "Automatic fan control" : "Fan notch \(setting.label), \(setting.description)")
                .accessibilityAddTraits(snapshot.selected == setting ? .isSelected : [])
            }
            if let message = snapshot.message {
                Link(destination: URL(string: "fanlever://setup")!) {
                    Text(message).font(.system(size: 10)).lineLimit(2)
                }
            } else {
                FanRPMView(snapshot: snapshot)
                HStack(spacing: 3) {
                    if let expires = snapshot.expires, expires > Date() {
                        Text("Auto in"); Text(expires, style: .timer)
                    } else {
                        Text("Read"); Text(snapshot.date, style: .relative); Text("ago")
                    }
                }.font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "fanlever://open"))
    }
}

@main struct FanLeverWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: FanConstants.widgetKind, provider: FanProvider()) { FanWidgetView(entry: $0) }
            .configurationDisplayName("Fan Lever")
            .description("A glass fan lever. Click a notch for a 30-minute boost, or choose Auto.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
