import AppKit
import ServiceManagement
import WidgetKit
import IOKit.ps

func printSnapshot(_ snapshot: FanSnapshot) {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(snapshot), let text = String(data: data, encoding: .utf8) { print(text) }
}

// No windows or Dock item. The host refreshes the widget when power changes;
// the privileged helper independently enforces every deadline.
final class BackgroundApp: NSObject, NSApplicationDelegate {
    var source: CFRunLoopSource?
    var battery = fl_on_battery() != 0
    func applicationDidFinishLaunching(_ notification: Notification) {
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<BackgroundApp>.fromOpaque(context).takeUnretainedValue().powerChanged()
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
        refresh()
    }
    func powerChanged() {
        let current = fl_on_battery() != 0
        guard current != battery else { return }
        battery = current
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.refresh() }
    }
    func refresh() {
        Task {
            SnapshotStore.save(await FanClient.request())
            WidgetCenter.shared.reloadTimelines(ofKind: FanConstants.widgetKind)
        }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.scheme == "fanlever" && $0.host == "setup" }) {
            let service = SMAppService.daemon(plistName: "space.monroe.FanLever.helper.plist")
            do { try service.register() } catch { NSLog("Fan Lever helper registration: %@", error.localizedDescription) }
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        }
        refresh()
    }
}

let args = CommandLine.arguments
if args.contains("--probe") {
    do { printSnapshot(FanSnapshot(fans: try SMCDevice().readings(), onBattery: fl_on_battery() != 0)); exit(0) }
    catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
} else if args.contains("--enable-helper") || args.contains("--disable-helper") {
    Task { @MainActor in
        let service = SMAppService.daemon(plistName: "space.monroe.FanLever.helper.plist")
        do {
            if args.contains("--disable-helper") {
                let result = await FanClient.request(.auto)
                guard result.connected, result.selected == .auto, result.message == nil else { printSnapshot(result); exit(1) }
                try await service.unregister()
            } else { try service.register() }
            print("Helper registration status: \(service.status.rawValue)")
            exit(service.status == .requiresApproval ? 3 : 0)
        } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
    }
    dispatchMain()
} else if args.contains("--status") || args.contains("--select") {
    var selection: FanSetting?
    if let index = args.firstIndex(of: "--select") {
        guard args.indices.contains(index + 1), let raw = Int(args[index + 1]), let setting = FanSetting(rawValue: raw) else { exit(2) }
        selection = setting
    }
    let requested = selection
    Task {
        let result = await FanClient.request(requested)
        printSnapshot(result)
        exit(result.connected && result.message == nil ? 0 : 1)
    }
    dispatchMain()
} else {
    #if DEBUG
    if args.contains("--preview") { FanLeverApp.main() }
    #endif
    let app = NSApplication.shared
    let delegate = BackgroundApp()
    app.setActivationPolicy(.prohibited)
    app.delegate = delegate
    app.run()
}
