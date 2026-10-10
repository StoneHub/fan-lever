import WidgetKit
import SwiftUI
import AppIntents

struct SetFanIntent: AppIntent {
    static var title: LocalizedStringResource = "Set fan speed"
    static var description = IntentDescription("Select a Fan Lever notch. Manual speeds return to Auto after 5 minutes on battery or 30 minutes on power.")
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
    #if WIDGET_RENDER
    var previewFamily: WidgetFamily = .systemSmall
    private var small: Bool { previewFamily == .systemSmall }
    #else
    private var small: Bool { family == .systemSmall }
    #endif
    private var snapshot: FanSnapshot { entry.snapshot }
    private var selection: FanSetting? { snapshot.connected ? snapshot.selected : nil }
    private func notch(_ setting: FanSetting) -> some View {
        Button(intent: SetFanIntent(setting)) {
            LeverNotch(setting: setting, selected: selection == setting, compact: small)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(setting == .auto ? "Automatic fan control" : "Fan notch \(setting.label), \(setting.description)")
        .accessibilityAddTraits(selection == setting ? .isSelected : [])
    }
    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "fanlever://open"))
    }
    var content: some View {
        VStack(alignment: .leading, spacing: small ? 6 : 8) {
            HStack(spacing: 5) {
                Image(systemName: "fanblades.fill").font(.system(size: 14)).widgetAccentable()
                Text(small ? "Fans" : "Fan Lever").font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 2)
                if small {
                    Button(intent: SetFanIntent(.auto)) {
                        Text("AUTO").font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(.primary.opacity(selection == .auto ? 0.20 : 0.06), in: Capsule())
                            .overlay(Capsule().strokeBorder(.primary.opacity(selection == .auto ? 0.5 : 0.15), lineWidth: 0.7))
                    }.buttonStyle(.plain).accessibilityLabel("Automatic fan control")
                        .accessibilityAddTraits(selection == .auto ? .isSelected : [])
                }
            }
            if small { readings }
            LeverView(selected: selection, settings: small ? Array(FanSetting.allCases.dropFirst()) : FanSetting.allCases, compact: small) { notch($0) }
            if !small { readings }
            if let message = snapshot.message {
                Link(destination: URL(string: "fanlever://setup")!) {
                    Text(message).font(.system(size: 10)).lineLimit(2)
                }
            } else {
                HStack(spacing: 3) {
                    if let expires = snapshot.expires, expires > Date() {
                        Text("Auto in")
                        Text(timerInterval: snapshot.date...max(snapshot.date, expires), countsDown: true).monospacedDigit()
                    } else {
                        Text("Read"); Text(snapshot.date, style: .relative)
                    }
                }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    private var readings: some View {
        HStack(alignment: .firstTextBaseline, spacing: small ? 8 : 20) {
            ForEach(snapshot.fans.prefix(2)) { fan in
                VStack(alignment: .leading, spacing: 1) {
                    Text("F\(fan.id + 1) · RPM").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    Text(Int(fan.actual).formatted(.number.grouping(.never)))
                        .font(.system(size: small ? 19 : 18, weight: .semibold, design: .rounded)).monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if snapshot.fans.isEmpty { Text("— RPM").font(.system(size: 19)).foregroundStyle(.secondary) }
        }.accessibilityLabel("Sampled fan speeds")
    }
}

#if !WIDGET_RENDER
@main struct FanLeverWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: FanConstants.widgetKind, provider: FanProvider()) { FanWidgetView(entry: $0) }
            .configurationDisplayName("Fan Lever")
            .description("A glass fan lever. Click a notch for a boost: 5 minutes on battery, 30 on power, or choose Auto.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#endif
