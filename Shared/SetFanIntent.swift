import AppIntents
import WidgetKit

// Included in both targets: macOS may route a widget action to the running host.
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

struct CycleFanTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Change Auto timer"
    static var description = IntentDescription("Shorten the time before Fan Lever returns to Auto: 30, 15, 10, 5, then 1 minute, then back to 30. On battery, 5 and 1.")
    func perform() async throws -> some IntentResult {
        let snapshot = await FanClient.cycleAutoTimer()
        SnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: FanConstants.widgetKind)
        if let message = snapshot.message { throw FanError.message(message) }
        return .result()
    }
}

