import WidgetKit
import SwiftUI
import AppIntents

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
            .widgetChromeSurface()
            .widgetURL(URL(string: "fanlever://open"))
    }
    var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetChromeHeader(symbol: "fanblades.fill", title: small ? "Fans" : "Fan Lever") {
                if small {
                    Button(intent: SetFanIntent(.auto)) {
                        WidgetChromePill(prominence: selection == .auto ? .selected : .standard) { Text("AUTO") }
                    }.buttonStyle(.plain).accessibilityLabel("Automatic fan control")
                        .accessibilityAddTraits(selection == .auto ? .isSelected : [])
                }
            }
            LeverView(selected: selection, settings: small ? Array(FanSetting.allCases.dropFirst()) : FanSetting.allCases, compact: small) { notch($0) }
            readings
            if let message = snapshot.message {
                Link(destination: URL(string: "fanlever://setup")!) {
                    Text(message).font(.system(size: 10)).lineLimit(2)
                }
            } else if let expires = snapshot.expires, expires > Date() {
                let countdown = HStack(spacing: 3) {
                    if snapshot.canCycleTimer == true { Image(systemName: "timer") }
                    Text("Auto in")
                    Text(timerInterval: snapshot.date...max(snapshot.date, expires), countsDown: true).monospacedDigit()
                }.widgetChromeFootnote()
                // A helper older than the timer step call reports nil; leave the countdown as plain text then.
                if snapshot.canCycleTimer == true {
                    Button(intent: CycleFanTimerIntent()) { countdown }.buttonStyle(.plain)
                        .accessibilityHint(snapshot.onBattery ? "Steps between 5 and 1 minute" : "Steps down through 30, 15, 10, 5 and 1 minute, then wraps")
                } else { countdown }
            } else {
                HStack(spacing: 3) { Text("Read"); Text(snapshot.date, style: .relative) }.widgetChromeFootnote()
            }
        }
    }
    // Sampled speeds stay secondary to the lever: one compact line under it.
    private var readings: some View {
        HStack(alignment: .firstTextBaseline, spacing: small ? 8 : 16) {
            ForEach(snapshot.fans.prefix(2)) { fan in
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("F\(fan.id + 1)").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    Text(Int(fan.actual).formatted(.number.grouping(.never)))
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                }
            }
            Text(snapshot.fans.isEmpty ? "— RPM" : "RPM").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        }.lineLimit(1).accessibilityLabel("Sampled fan speeds")
    }
}

#if !WIDGET_RENDER
@main struct FanLeverWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: FanConstants.widgetKind, provider: FanProvider()) { FanWidgetView(entry: $0) }
            .configurationDisplayName("Fan Lever")
            .description("A glass fan lever. Click a notch for a boost: 5 minutes on battery, 30 on power, or choose Auto. Click the countdown to shorten it.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#endif
